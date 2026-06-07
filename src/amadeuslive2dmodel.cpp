#include "amadeuslive2dmodel.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QCoreApplication>
#include <QRandomGenerator>
#include <QVector>
#include <QHash>
#include <QStringList>

#include <cstdlib>
#include <cstring>
#include <cmath>

#include <QMutex>
#include <QMutexLocker>
#include <QMap>
#include <QSet>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QtConcurrent>

#include <GL/glew.h>

#include <CubismFramework.hpp>
#include <CubismModelSettingJson.hpp>
#include <Id/CubismIdManager.hpp>
#include <Model/CubismUserModel.hpp>
#include <Motion/CubismExpressionMotion.hpp>
#include <Rendering/OpenGL/CubismRenderer_OpenGLES2.hpp>
#include <Type/csmMap.hpp>
#include <Type/csmString.hpp>

using namespace Live2D::Cubism::Framework;

namespace {

class SimpleAllocator : public ICubismAllocator {
public:
    void* Allocate(const csmSizeType size) override {
        return std::malloc(size);
    }

    void Deallocate(void* memory) override {
        std::free(memory);
    }

    void* AllocateAligned(const csmSizeType size, const csmUint32 alignment) override {
        const size_t safeAlignment = alignment < sizeof(void*) ? sizeof(void*) : static_cast<size_t>(alignment);
        const size_t offset = safeAlignment - 1 + sizeof(void*);
        void* allocation = Allocate(size + static_cast<csmUint32>(offset));
        if (allocation == nullptr) {
            return nullptr;
        }

        size_t alignedAddress = reinterpret_cast<size_t>(allocation) + sizeof(void*);
        const size_t shift = alignedAddress % safeAlignment;
        if (shift != 0) {
            alignedAddress += (safeAlignment - shift);
        }

        void** preamble = reinterpret_cast<void**>(alignedAddress);
        preamble[-1] = allocation;
        return reinterpret_cast<void*>(alignedAddress);
    }

    void DeallocateAligned(void* alignedMemory) override {
        if (alignedMemory == nullptr) {
            return;
        }

        void** preamble = static_cast<void**>(alignedMemory);
        Deallocate(preamble[-1]);
    }
};

struct ModelDataCache {
    QString modelDirectory;
    QByteArray model3Bytes;
    QByteArray mocBytes;
    QByteArray physicsBytes;
    QByteArray poseBytes;
    QMap<QString, QByteArray> expressionBytes;
    QVector<QImage> textures;
    bool loaded = false;
};

static QMutex s_cacheMutex;
static QMap<QString, ModelDataCache> s_modelCache;
static QSet<QString> s_loadingDirs;

static SimpleAllocator s_allocator;
static CubismFramework::Option s_cubismOption;
static bool s_cubismInitialized = false;
static bool s_glewInitialized = false;

static QByteArray ReadAllBytes(const QString& filePath) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }
    return file.readAll();
}

static QString ResolveFrameworkShaderPath(const QString& relativePath) {
    if (relativePath.isEmpty()) {
        return QString();
    }

    QFileInfo rawPathInfo(relativePath);
    if (rawPathInfo.exists()) {
        return rawPathInfo.absoluteFilePath();
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString projectRoot = QStringLiteral(REALAMADEUS_PROJECT_ROOT);
    const QString fileName = QFileInfo(relativePath).fileName();

    const QStringList candidates = {
        QDir::cleanPath(appDir + "/" + relativePath),
        QDir::cleanPath(appDir + "/FrameworkShaders/" + fileName),
        QDir::cleanPath(projectRoot + "/third_party/CubismSdkForNative-5-r.4.1/Framework/src/Rendering/OpenGL/Shaders/Standard/" + fileName),
        QDir::cleanPath(projectRoot + "/third_party/CubismSdkForNative-5-r.4.1/Framework/src/Rendering/OpenGL/Shaders/StandardES/" + fileName)
    };

    for (const QString& candidate : candidates) {
        if (QFileInfo::exists(candidate)) {
            return candidate;
        }
    }

    return QString();
}

static csmByte* LoadCubismFileAsBytes(const std::string filePath, csmSizeInt* outSize) {
    if (outSize == nullptr) {
        return nullptr;
    }

    *outSize = 0;

    const QString resolvedPath = ResolveFrameworkShaderPath(QString::fromUtf8(filePath.c_str()));
    if (resolvedPath.isEmpty()) {
        return nullptr;
    }

    const QByteArray bytes = ReadAllBytes(resolvedPath);
    if (bytes.isEmpty()) {
        return nullptr;
    }

    csmByte* buffer = new csmByte[bytes.size()];
    std::memcpy(buffer, bytes.constData(), static_cast<size_t>(bytes.size()));
    *outSize = static_cast<csmSizeInt>(bytes.size());
    return buffer;
}

static void ReleaseCubismBytes(csmByte* byteData) {
    delete[] byteData;
}

static void EnsureCubismInitialized() {
    if (s_cubismInitialized) {
        return;
    }

    s_cubismOption.LogFunction = nullptr;
    s_cubismOption.LoggingLevel = CubismFramework::Option::LogLevel_Error;
    s_cubismOption.LoadFileFunction = LoadCubismFileAsBytes;
    s_cubismOption.ReleaseBytesFunction = ReleaseCubismBytes;

    CubismFramework::StartUp(&s_allocator, &s_cubismOption);
    CubismFramework::Initialize();
    s_cubismInitialized = true;
}

} // namespace

class AmadeusLive2DModel::InnerModel : public CubismUserModel {
public:
    struct EmotionTarget {
        float browY = 0.0f;
        float browForm = 0.0f;
        float browAngle = 0.0f;
        float eyeOpen = 1.0f;
        float eyeSmile = 0.0f;
        float mouthForm = 0.0f;
        float bodyAngleX = 0.0f;
        float bodyAngleY = 0.0f;
        float bodyAngleZ = 0.0f;
        float headAngleX = 0.0f;
        float headAngleY = 0.0f;
        float headAngleZ = 0.0f;
        float cheek = 0.0f;
        bool isWink = false;
    };

    struct MotionBurst {
        float bodyX = 0.0f;
        float bodyY = 0.0f;
        float bodyZ = 0.0f;
        float headX = 0.0f;
        float headY = 0.0f;
        float headZ = 0.0f;
        float duration = 0.6f;
        float intensity = 1.0f;
    };

    enum class BlinkState {
        Open,
        Closing,
        Opening
    };

    InnerModel()
        : _initialized(false),
          _lipSyncValue(0.0f),
          _userTimeSeconds(0.0f),
          _setting(nullptr) {
        _targetEmotion = GetEmotionTarget("NORMAL");
        _currentEmotion = _targetEmotion;
        _currentEmotionTag = QStringLiteral("NORMAL");
    }

    ~InnerModel() override {
        for (const auto texId : _textureIds) {
            glDeleteTextures(1, &texId);
        }

        for (csmMap<csmString, ACubismMotion*>::const_iterator it = _expressions.Begin(); it != _expressions.End(); ++it) {
            ACubismMotion::Delete(it->Second);
        }
        _expressions.Clear();

        delete _setting;
        _setting = nullptr;
    }

    bool EnsureLoaded(const QString& modelDirectory) {
        if (_initialized && _modelDirectory == modelDirectory) {
            return true;
        }

        if (modelDirectory.isEmpty()) {
            static int warnCount = 0;
            if (++warnCount <= 5)
                qInfo() << "[Live2D] EnsureLoaded: empty model directory";
            return false;
        }

        ModelDataCache cachedData;
        bool hasCache = false;
        {
            QMutexLocker locker(&s_cacheMutex);
            if (s_modelCache.contains(modelDirectory) && s_modelCache[modelDirectory].loaded) {
                cachedData = s_modelCache[modelDirectory];
                hasCache = true;
            }
        }

        if (!hasCache) {
            AmadeusLive2DModel::Preload(modelDirectory);
            return false;
        }

        const QByteArray model3Bytes = cachedData.model3Bytes;
        if (model3Bytes.isEmpty()) {
            static int warnCount = 0;
            if (++warnCount <= 5)
                qInfo() << "[Live2D] EnsureLoaded: empty cached model3 file";
            return false;
        }

        delete _setting;
        _setting = new CubismModelSettingJson(reinterpret_cast<const csmByte*>(model3Bytes.constData()), static_cast<csmSizeInt>(model3Bytes.size()));
        if (_setting == nullptr || _setting->GetModelFileName() == nullptr) {
            return false;
        }

        const QByteArray mocBytes = cachedData.mocBytes;
        if (mocBytes.isEmpty()) {
            return false;
        }

        if (!CubismMoc::HasMocConsistencyFromUnrevivedMoc(reinterpret_cast<const csmByte*>(mocBytes.constData()), static_cast<csmSizeInt>(mocBytes.size()))) {
            return false;
        }

        LoadModel(reinterpret_cast<const csmByte*>(mocBytes.constData()), static_cast<csmSizeInt>(mocBytes.size()), true);
        if (_model == nullptr) {
            return false;
        }

        if (_setting != nullptr && _modelMatrix != nullptr) {
            csmMap<csmString, csmFloat32> layout;
            if (_setting->GetLayoutMap(layout) && layout.GetSize() > 0) {
                _modelMatrix->SetupFromLayout(layout);
            }
        }

        if (!s_glewInitialized) {
            glewExperimental = GL_TRUE;
            const GLenum glewResult = glewInit();
            if (glewResult != GLEW_OK) {
                qWarning() << "[Live2D] glewInit failed:" << reinterpret_cast<const char*>(glewGetErrorString(glewResult));
                return false;
            }
            glGetError();
            s_glewInitialized = true;
        }

        if (_setting->GetPhysicsFileName() != nullptr) {
            const QByteArray physicsBytes = cachedData.physicsBytes;
            if (!physicsBytes.isEmpty()) {
                LoadPhysics(reinterpret_cast<const csmByte*>(physicsBytes.constData()), static_cast<csmSizeInt>(physicsBytes.size()));
            }
        }

        if (_setting->GetPoseFileName() != nullptr) {
            const QByteArray poseBytes = cachedData.poseBytes;
            if (!poseBytes.isEmpty()) {
                LoadPose(reinterpret_cast<const csmByte*>(poseBytes.constData()), static_cast<csmSizeInt>(poseBytes.size()));
            }
        }

        _lipSyncIds.Clear();
        for (csmInt32 i = 0; i < _setting->GetLipSyncParameterCount(); ++i) {
            _lipSyncIds.PushBack(_setting->GetLipSyncParameterId(i));
        }

        for (csmMap<csmString, ACubismMotion*>::const_iterator it = _expressions.Begin(); it != _expressions.End(); ++it) {
            ACubismMotion::Delete(it->Second);
        }
        _expressions.Clear();

        for (csmInt32 i = 0; i < _setting->GetExpressionCount(); ++i) {
            const csmChar* expName = _setting->GetExpressionName(i);
            const QByteArray expBytes = cachedData.expressionBytes.value(QString::fromUtf8(expName));
            if (expBytes.isEmpty()) {
                continue;
            }

            ACubismMotion* motion = LoadExpression(reinterpret_cast<const csmByte*>(expBytes.constData()), static_cast<csmSizeInt>(expBytes.size()), expName);
            if (motion != nullptr) {
                _expressions[csmString(expName)] = motion;
            }
        }

        CreateRenderer();
        auto* renderer = GetRenderer<Rendering::CubismRenderer_OpenGLES2>();
        if (renderer == nullptr) {
            return false;
        }
        renderer->IsPremultipliedAlpha(false);

        for (const auto texId : _textureIds) {
            glDeleteTextures(1, &texId);
        }
        _textureIds.clear();

        const csmInt32 textureCount = _setting->GetTextureCount();
        _textureIds.reserve(textureCount);

        GLint maxTextureSize = 0;
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
        if (maxTextureSize <= 0) {
            maxTextureSize = 4096;
        }

        QDir dir(modelDirectory);
        for (csmInt32 i = 0; i < textureCount; ++i) {
            QImage img;
            if (i < cachedData.textures.size()) {
                img = cachedData.textures[i];
            }
            if (img.isNull()) {
                const QString texPath = dir.filePath(QString::fromUtf8(_setting->GetTextureFileName(i)));
                img = QImage(texPath);
                if (img.isNull()) {
                    continue;
                }
                img = img.convertToFormat(QImage::Format_RGBA8888);
            }

            if (img.width() > maxTextureSize || img.height() > maxTextureSize) {
                img = img.scaled(maxTextureSize, maxTextureSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }

            GLuint texId = 0;
            glGenTextures(1, &texId);
            glBindTexture(GL_TEXTURE_2D, texId);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, img.width(), img.height(), 0, GL_RGBA, GL_UNSIGNED_BYTE, img.bits());
            glBindTexture(GL_TEXTURE_2D, 0);

            renderer->BindTexture(i, texId);
            _textureIds.push_back(texId);
        }

        CacheParamIds();
        _modelDirectory = modelDirectory;
        _initialized = true;
        return true;
    }

    ACubismMotion* FindExpression(const QString& tag) const {
        if (_expressions.GetSize() == 0) return nullptr;
        const QString needle = tag.toLower();
        QStringList preferredKeys;
        if (needle == QStringLiteral("sad")) preferredKeys = {QStringLiteral("sad")};
        else if (needle == QStringLiteral("smile")) preferredKeys = {QStringLiteral("smile")};
        else if (needle == QStringLiteral("angry")) preferredKeys = {QStringLiteral("angry")};
        else if (needle == QStringLiteral("disgust")) preferredKeys = {QStringLiteral("disgust")};
        else if (needle == QStringLiteral("normal")) preferredKeys = {QStringLiteral("normal")};
        else if (needle == QStringLiteral("surprised")) preferredKeys = {QStringLiteral("surprised")};
        else if (needle == QStringLiteral("blush")) preferredKeys = {QStringLiteral("blushing"), QStringLiteral("blush")};
        else if (needle == QStringLiteral("wink")) preferredKeys = {QStringLiteral("f02"), QStringLiteral("wink")};
        else if (needle == QStringLiteral("smug")) preferredKeys = {QStringLiteral("smile")};
        else if (needle == QStringLiteral("thinking")) preferredKeys = {QStringLiteral("normal")};
        else if (needle == QStringLiteral("panic")) preferredKeys = {QStringLiteral("surprised")};
        else preferredKeys = {needle};

        ACubismMotion* selected = nullptr;
        for (const QString& key : preferredKeys) {
            for (csmMap<csmString, ACubismMotion*>::const_iterator it = _expressions.Begin(); it != _expressions.End(); ++it) {
                const QString name = QString::fromUtf8(it->First.GetRawString()).toLower();
                if (name.contains(key)) {
                    selected = it->Second;
                    break;
                }
            }
            if (selected != nullptr) break;
        }

        if (selected == nullptr) {
            for (csmMap<csmString, ACubismMotion*>::const_iterator it = _expressions.Begin(); it != _expressions.End(); ++it) {
                const QString name = QString::fromUtf8(it->First.GetRawString()).toLower();
                if (name.contains(needle)) {
                    selected = it->Second;
                    break;
                }
            }
        }

        if (selected == nullptr) {
            selected = _expressions.Begin()->Second;
        }
        return selected;
    }

    void SetEmotionTag(const QString& emotionTag) {
        if (emotionTag.isEmpty()) {
            return;
        }
        const QString normalizedTag = emotionTag.trimmed().toUpper();
        if (normalizedTag == _emotionTag) {
            return;
        }
        
        bool isWakingUp = (_emotionTag == QStringLiteral("SLEEPING") && normalizedTag != QStringLiteral("SLEEPING"));
        _emotionTag = normalizedTag;

        if (isWakingUp) {
            _wakeUpTimer = 1.2f; // startled wake-up duration (1.2 seconds)
            
            // Start the SURPRISED expression & target & burst
            if (_expressionManager != nullptr && _expressions.GetSize() > 0) {
                ACubismMotion* surprisedExp = FindExpression(QStringLiteral("surprised"));
                if (surprisedExp) {
                    _expressionManager->StartMotionPriority(surprisedExp, false, 3);
                }
            }
            
            _targetEmotion = GetEmotionTarget(QStringLiteral("SURPRISED"));
            _activeBurst = GetMotionBurst(QStringLiteral("SURPRISED"));
            _burstTimer = 0.0f;
            _burstProgress = 0.0f;
            _idlePhase = 0.0f;
            _currentEmotionTag = QStringLiteral("SURPRISED");
        } else {
            // Cancel any active wakeUpTimer
            _wakeUpTimer = 0.0f;
            
            if (_expressionManager != nullptr && _expressions.GetSize() > 0) {
                ACubismMotion* selected = FindExpression(_emotionTag);
                if (selected) {
                    _expressionManager->StartMotionPriority(selected, false, 3);
                }
            }

            _targetEmotion = GetEmotionTarget(_emotionTag);
            if (_emotionTag != _currentEmotionTag) {
                _activeBurst = GetMotionBurst(_emotionTag);
                _burstTimer = 0.0f;
                _burstProgress = 0.0f;
                _idlePhase = 0.0f;
                _currentEmotionTag = _emotionTag;
            }
        }
    }

    void SetLipSyncValue(float value) {
        _lipSyncValue = qBound(0.0f, value, 1.0f);
    }

    void SetEyeTracking(float eyeX, float eyeY) {
        _eyeTrackingX = eyeX;
        _eyeTrackingY = eyeY;
    }

    void SetLightweightMode(bool enabled) {
        _lightweightMode = enabled;
    }

    void SetSpokenChar(const QString& spokenChar) {
        _spokenChar = spokenChar;
    }

    static float GetVowelMouthOpening(const QString &chr) {
        if (chr.isEmpty()) return 0.0f;
        const QChar c = chr.at(0);

        if (c == 'a' || c == 'A') return 0.9f;
        if (c == 'o' || c == 'O') return 0.7f;
        if (c == 'e' || c == 'E') return 0.6f;
        if (c == 'u' || c == 'U') return 0.4f;
        if (c == 'i' || c == 'I') return 0.2f;

        static const QString aVowels = QString::fromUtf8("あかさたなはまやらわがざだばぱぁゃァカサタナハマヤラワガザダバパァャ");
        if (aVowels.contains(c)) return 0.9f;

        static const QString oVowels = QString::fromUtf8("おこそとのほもよろをごぞどぼぽぉょォコソトノホモヨロヲゴゾドボポォョ");
        if (oVowels.contains(c)) return 0.7f;

        static const QString eVowels = QString::fromUtf8("えけせてねへめれげぜでべぺぇェケセテネヘメレゲゼデベペェ");
        if (eVowels.contains(c)) return 0.6f;

        static const QString uVowels = QString::fromUtf8("うくすつぬふむゆるぐずづぶぷぅゅゥクスツヌフムユルグズヅブプゥュ");
        if (uVowels.contains(c)) return 0.4f;

        static const QString iVowels = QString::fromUtf8("いきしちにひみりぎじぢびぴぃィキシチニヒミリギジヂビピィ");
        if (iVowels.contains(c)) return 0.2f;

        static const QString closedChars = QString::fromUtf8("んン。、？！.,?! 　\n\r\t-_");
        if (closedChars.contains(c)) return 0.0f;

        return 0.5f;
    }

    void Update(float deltaSeconds) {
        if (!_initialized || _model == nullptr) {
            return;
        }

        // Lightweight mode: skip every other frame
        if (_lightweightMode) {
            _lightweightFrameSkip = (_lightweightFrameSkip + 1) % 2;
            if (_lightweightFrameSkip != 0) {
                return;
            }
        }

        _userTimeSeconds += deltaSeconds;
        _idlePhase += deltaSeconds;

        _model->LoadParameters();

        if (_motionManager != nullptr) {
            _motionManager->UpdateMotion(_model, deltaSeconds);
        }
        if (_expressionManager != nullptr) {
            _expressionManager->UpdateMotion(_model, deltaSeconds);
        }
        if (_physics != nullptr) {
            _physics->Evaluate(_model, deltaSeconds);
        }

        // Handle startled wake-up transition blend
        if (_wakeUpTimer > 0.0f) {
            _wakeUpTimer -= deltaSeconds;
            if (_wakeUpTimer <= 0.0f) {
                _wakeUpTimer = 0.0f;
                if (_expressionManager != nullptr && _expressions.GetSize() > 0) {
                    ACubismMotion* selected = FindExpression(_emotionTag);
                    if (selected) {
                        _expressionManager->StartMotionPriority(selected, false, 3);
                    }
                }
                _targetEmotion = GetEmotionTarget(_emotionTag);
                _currentEmotionTag = _emotionTag;
            } else {
                EmotionTarget targetBase = GetEmotionTarget(_emotionTag);
                EmotionTarget targetSurprised = GetEmotionTarget(QStringLiteral("SURPRISED"));
                float blend = qBound(0.0f, _wakeUpTimer / 1.2f, 1.0f);
                
                _targetEmotion.browY = Lerp(targetBase.browY, targetSurprised.browY, blend);
                _targetEmotion.browForm = Lerp(targetBase.browForm, targetSurprised.browForm, blend);
                _targetEmotion.browAngle = Lerp(targetBase.browAngle, targetSurprised.browAngle, blend);
                _targetEmotion.eyeOpen = Lerp(targetBase.eyeOpen, targetSurprised.eyeOpen, blend);
                _targetEmotion.eyeSmile = Lerp(targetBase.eyeSmile, targetSurprised.eyeSmile, blend);
                _targetEmotion.mouthForm = Lerp(targetBase.mouthForm, targetSurprised.mouthForm, blend);
                _targetEmotion.cheek = Lerp(targetBase.cheek, targetSurprised.cheek, blend);
                _targetEmotion.headAngleX = Lerp(targetBase.headAngleX, targetSurprised.headAngleX, blend);
                _targetEmotion.headAngleY = Lerp(targetBase.headAngleY, targetSurprised.headAngleY, blend);
                _targetEmotion.headAngleZ = Lerp(targetBase.headAngleZ, targetSurprised.headAngleZ, blend);
                _targetEmotion.bodyAngleX = Lerp(targetBase.bodyAngleX, targetSurprised.bodyAngleX, blend);
                _targetEmotion.bodyAngleY = Lerp(targetBase.bodyAngleY, targetSurprised.bodyAngleY, blend);
                _targetEmotion.bodyAngleZ = Lerp(targetBase.bodyAngleZ, targetSurprised.bodyAngleZ, blend);
            }
        }

        // Unity parity: smooth emotion blend.
        const float t = qBound(0.0f, deltaSeconds * _emotionLerpSpeed, 1.0f);
        _currentEmotion.browY = Lerp(_currentEmotion.browY, _targetEmotion.browY, t);
        _currentEmotion.browForm = Lerp(_currentEmotion.browForm, _targetEmotion.browForm, t);
        _currentEmotion.browAngle = Lerp(_currentEmotion.browAngle, _targetEmotion.browAngle, t);
        _currentEmotion.eyeOpen = Lerp(_currentEmotion.eyeOpen, _targetEmotion.eyeOpen, t);
        _currentEmotion.eyeSmile = Lerp(_currentEmotion.eyeSmile, _targetEmotion.eyeSmile, t);
        _currentEmotion.mouthForm = Lerp(_currentEmotion.mouthForm, _targetEmotion.mouthForm, t);
        _currentEmotion.bodyAngleX = Lerp(_currentEmotion.bodyAngleX, _targetEmotion.bodyAngleX, t);
        _currentEmotion.bodyAngleY = Lerp(_currentEmotion.bodyAngleY, _targetEmotion.bodyAngleY, t);
        _currentEmotion.bodyAngleZ = Lerp(_currentEmotion.bodyAngleZ, _targetEmotion.bodyAngleZ, t);
        _currentEmotion.headAngleX = Lerp(_currentEmotion.headAngleX, _targetEmotion.headAngleX, t);
        _currentEmotion.headAngleY = Lerp(_currentEmotion.headAngleY, _targetEmotion.headAngleY, t);
        _currentEmotion.headAngleZ = Lerp(_currentEmotion.headAngleZ, _targetEmotion.headAngleZ, t);
        _currentEmotion.cheek = Lerp(_currentEmotion.cheek, _targetEmotion.cheek, t);

        float burstBodyX = 0.0f;
        float burstBodyY = 0.0f;
        float burstBodyZ = 0.0f;
        float burstHeadX = 0.0f;
        float burstHeadY = 0.0f;
        float burstHeadZ = 0.0f;
        if (_burstProgress < 1.0f) {
            _burstTimer += deltaSeconds;
            _burstProgress = qBound(0.0f, _burstTimer / qMax(0.001f, _activeBurst.duration), 1.0f);
            const float t01 = _burstProgress;
            
            if (_emotionTag == QStringLiteral("SLEEPING")) {
                // Custom "nod, nod" (コク、コク) head pitch curve
                // We want two downward dips in headY (ParamAngleY)
                // Nod 1: peak at t01 = 0.25 (value = -10.0f)
                // Nod 2: peak at t01 = 0.75 (value = -15.0f)
                float nodCurve = 0.0f;
                if (t01 < 0.5f) {
                    nodCurve = std::sin(t01 * 2.0f * 3.14159265f) * -10.0f;
                    if (nodCurve > 0.0f) nodCurve = 0.0f;
                } else {
                    float localT = (t01 - 0.5f) * 2.0f;
                    nodCurve = std::sin(localT * 3.14159265f) * -15.0f;
                    if (nodCurve > 0.0f) nodCurve = 0.0f;
                }
                burstHeadY = nodCurve;
                burstBodyY = t01 * -2.0f; // body drops down slightly
            } else {
                const float spring = std::sin(t01 * 3.14159265f * 2.5f) * (1.0f - t01) * (1.0f - t01);
                const float intensity = _activeBurst.intensity * spring;
                burstBodyX = _activeBurst.bodyX * intensity;
                burstBodyY = _activeBurst.bodyY * intensity;
                burstBodyZ = _activeBurst.bodyZ * intensity;
                burstHeadX = _activeBurst.headX * intensity;
                burstHeadY = _activeBurst.headY * intensity;
                burstHeadZ = _activeBurst.headZ * intensity;
            }
        }

        float idleBodyX = 0.0f;
        float idleBodyY = 0.0f;
        float idleBodyZ = 0.0f;
        float idleHeadX = 0.0f;
        float idleHeadY = 0.0f;
        float idleHeadZ = 0.0f;
        GetEmotionIdleMotion(_currentEmotionTag, _idlePhase,
                             idleBodyX, idleBodyY, idleBodyZ,
                             idleHeadX, idleHeadY, idleHeadZ);

        const float motionSmoothT = qBound(0.0f, deltaSeconds * 6.0f, 1.0f);
        _smoothedBodyX = Lerp(_smoothedBodyX, burstBodyX + idleBodyX, motionSmoothT);
        _smoothedBodyY = Lerp(_smoothedBodyY, burstBodyY + idleBodyY, motionSmoothT);
        _smoothedBodyZ = Lerp(_smoothedBodyZ, burstBodyZ + idleBodyZ, motionSmoothT);
        _smoothedHeadX = Lerp(_smoothedHeadX, burstHeadX + idleHeadX, motionSmoothT);
        _smoothedHeadY = Lerp(_smoothedHeadY, burstHeadY + idleHeadY, motionSmoothT);
        _smoothedHeadZ = Lerp(_smoothedHeadZ, burstHeadZ + idleHeadZ, motionSmoothT);

        UpdateBlink(deltaSeconds);
        float eyeOpenValue = _currentEmotion.eyeOpen * _blinkValue;
        eyeOpenValue = qMax(0.0f, eyeOpenValue);

        SetParam(_idBrowLY, _currentEmotion.browY);
        SetParam(_idBrowRY, _currentEmotion.browY);
        SetParam(_idBrowLForm, _currentEmotion.browForm);
        SetParam(_idBrowRForm, _currentEmotion.browForm);
        SetParam(_idBrowLAngle, _currentEmotion.browAngle);
        SetParam(_idBrowRAngle, _currentEmotion.browAngle);
        SetParam(_idEyeLSmile, _currentEmotion.eyeSmile);
        SetParam(_idEyeRSmile, _currentEmotion.eyeSmile);
        SetParam(_idMouthForm, _currentEmotion.mouthForm);
        SetParam(_idCheek, _currentEmotion.cheek);

        if (_currentEmotion.isWink) {
            SetParam(_idEyeLOpen, eyeOpenValue);
            SetParam(_idEyeROpen, 0.0f);
        } else {
            SetParam(_idEyeLOpen, eyeOpenValue);
            SetParam(_idEyeROpen, eyeOpenValue);
        }

        SetParam(_idBodyAngleX, _currentEmotion.bodyAngleX + _smoothedBodyX + (_smoothedGazeX * 5.0f));
        SetParam(_idBodyAngleY, _currentEmotion.bodyAngleY + _smoothedBodyY + (_smoothedGazeY * 5.0f));
        SetParam(_idBodyAngleZ, _currentEmotion.bodyAngleZ + _smoothedBodyZ);
        SetParam(_idAngleX, _currentEmotion.headAngleX + _smoothedHeadX + (_smoothedGazeX * 25.0f));
        SetParam(_idAngleY, _currentEmotion.headAngleY + _smoothedHeadY + (_smoothedGazeY * 25.0f));
        SetParam(_idAngleZ, _currentEmotion.headAngleZ + _smoothedHeadZ);

        const bool isActivelyTyping = _lipSyncValue > 0.01f;
        if (isActivelyTyping) {
            float targetMouth = 0.5f;
            if (!_spokenChar.isEmpty()) {
                targetMouth = GetVowelMouthOpening(_spokenChar);
            } else {
                // Fallback to Unity-parity time-based noise/wave
                const float syllable = std::fabs(std::sin(_userTimeSeconds * 12.0f));
                const float subBeat = std::fabs(std::sin(_userTimeSeconds * 7.3f));
                const float flutter = Noise01(_userTimeSeconds * 8.0f, 5.0f);
                targetMouth = syllable * 0.5f + subBeat * 0.3f + flutter * 0.2f;
            }
            const float finalMouth = qBound(0.0f, targetMouth * qBound(0.0f, _lipSyncValue, 1.0f), 1.0f);
            _mouthOpen = Lerp(_mouthOpen, finalMouth, qBound(0.0f, deltaSeconds * 14.0f, 1.0f));
        } else {
            _mouthOpen = Lerp(_mouthOpen, 0.0f, qBound(0.0f, deltaSeconds * 10.0f, 1.0f));
        }
        SetParam(_idMouthOpenY, _mouthOpen);

        SetParam(_idBreath, (std::sin(_userTimeSeconds * 1.2f) + 1.0f) * 0.5f);

        // Eye tracking (Unity parity: smooth + body/head influence)
        const float gazeSmoothT = qBound(0.0f, deltaSeconds * 5.0f, 1.0f);
        _smoothedGazeX = Lerp(_smoothedGazeX, _eyeTrackingX, gazeSmoothT);
        _smoothedGazeY = Lerp(_smoothedGazeY, _eyeTrackingY, gazeSmoothT);

        if (_idEyeBallX) SetParam(_idEyeBallX, _smoothedGazeX);
        if (_idEyeBallY) SetParam(_idEyeBallY, _smoothedGazeY);

        _model->SaveParameters();
        _model->Update();
    }

    void Draw(int width, int height) {
        if (!_initialized || _model == nullptr || GetRenderer<Rendering::CubismRenderer_OpenGLES2>() == nullptr || width <= 0 || height <= 0) {
            return;
        }

        CubismMatrix44 projection;
        float baseScaleX, baseScaleY;
        if (_model->GetCanvasWidth() > 1.0f && width < height) {
            baseScaleX = 1.0f;
            baseScaleY = static_cast<float>(width) / static_cast<float>(height);
        } else {
            baseScaleX = static_cast<float>(height) / static_cast<float>(width);
            baseScaleY = 1.0f;
        }

        // Upper-body close-up: apply the same zoom to both axes so the
        // aspect ratio is preserved.
        const float zoom = 1.65f;
        projection.Scale(baseScaleX * zoom, baseScaleY * zoom);
        projection.Translate(0.0f, -1.13f);

        if (_modelMatrix != nullptr) {
            projection.MultiplyByMatrix(_modelMatrix);
        }

        auto* renderer = GetRenderer<Rendering::CubismRenderer_OpenGLES2>();
        renderer->SetMvpMatrix(&projection);
        renderer->DrawModel();
    }

private:
    static float Lerp(float a, float b, float t) {
        return a + (b - a) * t;
    }

    static float Noise01(float x, float seed) {
        // Keep pseudo-noise continuous to avoid frame-to-frame discontinuities.
        const float s1 = std::sin(x * 1.37f + seed * 0.71f);
        const float s2 = std::sin(x * 2.11f + seed * 1.13f);
        const float s3 = std::sin(x * 0.73f + seed * 2.03f);
        return qBound(0.0f, 0.5f + s1 * 0.28f + s2 * 0.16f + s3 * 0.06f, 1.0f);
    }

    static float NoiseSigned(float x, float seed) {
        return (Noise01(x, seed) - 0.5f) * 2.0f;
    }

    static float Drift(float phase, float speed, float seed, float amplitude) {
        const float slow = NoiseSigned(phase * speed * 0.3f, seed);
        const float medium = NoiseSigned(phase * speed * 0.8f, seed + 50.0f);
        const float micro = NoiseSigned(phase * speed * 2.5f, seed + 100.0f);
        return (slow * 0.5f + medium * 0.35f + micro * 0.15f) * amplitude;
    }

    static float RandomRange(float minV, float maxV) {
        const float r = static_cast<float>(QRandomGenerator::global()->generateDouble());
        return minV + (maxV - minV) * r;
    }

    void SetParam(const CubismId* cachedId, float value) {
        if (_model == nullptr || cachedId == nullptr) {
            return;
        }
        _model->SetParameterValue(cachedId, value);
    }

    void CacheParamIds() {
        CubismIdManager* idm = CubismFramework::GetIdManager();
        if (!idm) return;
        _idBrowLY      = idm->GetId("ParamBrowLY");
        _idBrowRY      = idm->GetId("ParamBrowRY");
        _idBrowLForm   = idm->GetId("ParamBrowLForm");
        _idBrowRForm   = idm->GetId("ParamBrowRForm");
        _idBrowLAngle  = idm->GetId("ParamBrowLAngle");
        _idBrowRAngle  = idm->GetId("ParamBrowRAngle");
        _idEyeLSmile   = idm->GetId("ParamEyeLSmile");
        _idEyeRSmile   = idm->GetId("ParamEyeRSmile");
        _idMouthForm   = idm->GetId("ParamMouthForm");
        _idCheek       = idm->GetId("ParamCheek");
        _idEyeLOpen    = idm->GetId("ParamEyeLOpen");
        _idEyeROpen    = idm->GetId("ParamEyeROpen");
        _idBodyAngleX  = idm->GetId("ParamBodyAngleX");
        _idBodyAngleY  = idm->GetId("ParamBodyAngleY");
        _idBodyAngleZ  = idm->GetId("ParamBodyAngleZ");
        _idAngleX      = idm->GetId("ParamAngleX");
        _idAngleY      = idm->GetId("ParamAngleY");
        _idAngleZ      = idm->GetId("ParamAngleZ");
        _idMouthOpenY  = idm->GetId("ParamMouthOpenY");
        _idBreath      = idm->GetId("ParamBreath");
        _idEyeBallX    = idm->GetId("ParamEyeBallX");
        _idEyeBallY    = idm->GetId("ParamEyeBallY");
    }

    EmotionTarget GetEmotionTarget(const QString& tag) const {
        EmotionTarget e;
        const QString t = tag.toUpper();
        if (t == QStringLiteral("NORMAL")) {
            e.browY = 0.0f; e.browForm = 0.5f; e.browAngle = 0.0f;
            e.eyeOpen = 1.0f; e.eyeSmile = 0.0f;
            e.mouthForm = 0.0f;
            e.bodyAngleX = 0.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = 0.0f;
            e.headAngleX = 0.0f; e.headAngleY = 0.0f; e.headAngleZ = 0.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("SMILE")) {
            e.browY = 0.4f; e.browForm = 0.8f; e.browAngle = 0.2f;
            e.eyeOpen = 0.6f; e.eyeSmile = 1.0f;
            e.mouthForm = 1.0f;
            e.bodyAngleX = 3.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = -2.0f;
            e.headAngleX = 5.0f; e.headAngleY = 3.0f; e.headAngleZ = -3.0f;
            e.cheek = 0.3f;
        } else if (t == QStringLiteral("ANGRY")) {
            e.browY = -0.6f; e.browForm = -0.8f; e.browAngle = -0.8f;
            e.eyeOpen = 0.5f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.8f;
            e.bodyAngleX = -4.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = 0.0f;
            e.headAngleX = -5.0f; e.headAngleY = -5.0f; e.headAngleZ = 0.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("SAD")) {
            e.browY = -0.5f; e.browForm = -0.6f; e.browAngle = 0.6f;
            e.eyeOpen = 0.4f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.5f;
            e.bodyAngleX = -3.0f; e.bodyAngleY = -3.0f; e.bodyAngleZ = -3.0f;
            e.headAngleX = -8.0f; e.headAngleY = -7.0f; e.headAngleZ = -5.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("SURPRISED")) {
            e.browY = 0.8f; e.browForm = 0.5f; e.browAngle = 0.0f;
            e.eyeOpen = 1.25f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.4f;
            e.bodyAngleX = -2.0f; e.bodyAngleY = 5.0f; e.bodyAngleZ = 2.0f;
            e.headAngleX = 2.0f; e.headAngleY = 8.0f; e.headAngleZ = 0.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("BLUSH")) {
            e.browY = 0.2f; e.browForm = 0.4f; e.browAngle = 0.3f;
            e.eyeOpen = 0.6f; e.eyeSmile = 0.7f;
            e.mouthForm = 0.3f;
            e.bodyAngleX = 8.0f; e.bodyAngleY = -3.0f; e.bodyAngleZ = -3.0f;
            e.headAngleX = 8.0f; e.headAngleY = -8.0f; e.headAngleZ = -7.0f;
            e.cheek = 1.0f;
        } else if (t == QStringLiteral("WINK")) {
            e.browY = 0.5f; e.browForm = 0.8f; e.browAngle = 0.2f;
            e.eyeOpen = 1.0f; e.eyeSmile = 0.7f;
            e.mouthForm = 0.5f;
            e.bodyAngleX = 2.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = -5.0f;
            e.headAngleX = 5.0f; e.headAngleY = 2.0f; e.headAngleZ = -5.0f;
            e.cheek = 0.0f;
            e.isWink = true;
        } else if (t == QStringLiteral("DISGUST")) {
            e.browY = -0.3f; e.browForm = -0.9f; e.browAngle = -0.5f;
            e.eyeOpen = 0.4f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.9f;
            e.bodyAngleX = 5.0f; e.bodyAngleY = 4.0f; e.bodyAngleZ = 2.0f;
            e.headAngleX = 5.0f; e.headAngleY = -4.0f; e.headAngleZ = 3.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("SMUG")) {
            e.browY = 0.3f; e.browForm = 0.7f; e.browAngle = 0.4f;
            e.eyeOpen = 0.6f; e.eyeSmile = 0.8f;
            e.mouthForm = 0.6f;
            e.bodyAngleX = 4.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = -2.0f;
            e.headAngleX = 10.0f; e.headAngleY = 5.0f; e.headAngleZ = -2.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("THINKING")) {
            e.browY = -0.2f; e.browForm = -0.3f; e.browAngle = 0.2f;
            e.eyeOpen = 0.8f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.2f;
            e.bodyAngleX = -2.0f; e.bodyAngleY = 5.0f; e.bodyAngleZ = 5.0f;
            e.headAngleX = 5.0f; e.headAngleY = -8.0f; e.headAngleZ = 5.0f;
            e.cheek = 0.0f;
        } else if (t == QStringLiteral("PANIC")) {
            e.browY = 0.6f; e.browForm = -0.5f; e.browAngle = -0.3f;
            e.eyeOpen = 1.2f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.5f;
            e.bodyAngleX = -3.0f; e.bodyAngleY = 0.0f; e.bodyAngleZ = 0.0f;
            e.headAngleX = -2.0f; e.headAngleY = 0.0f; e.headAngleZ = 0.0f;
            e.cheek = 0.6f;
        } else if (t == QStringLiteral("SLEEPING")) {
            e.browY = -0.3f; e.browForm = 0.2f; e.browAngle = -0.2f;
            e.eyeOpen = 0.0f; e.eyeSmile = 0.0f;
            e.mouthForm = -0.1f;
            e.bodyAngleX = -1.0f; e.bodyAngleY = -2.0f; e.bodyAngleZ = -2.0f;
            e.headAngleX = -12.0f; e.headAngleY = -5.0f; e.headAngleZ = -8.0f;
            e.cheek = 0.0f;
        }
        return e;
    }

    MotionBurst GetMotionBurst(const QString& tag) const {
        MotionBurst b;
        const QString t = tag.toUpper();
        if (t == QStringLiteral("NORMAL")) {
            b.bodyX = 0.0f; b.bodyY = 1.0f; b.bodyZ = 0.0f;
            b.headX = 0.0f; b.headY = 1.0f; b.headZ = 0.0f;
            b.duration = 0.4f; b.intensity = 0.5f;
        } else if (t == QStringLiteral("SMILE")) {
            b.bodyX = 4.0f; b.bodyY = 2.0f; b.bodyZ = -2.0f;
            b.headX = 5.0f; b.headY = 3.0f; b.headZ = -3.0f;
            b.duration = 0.5f; b.intensity = 0.8f;
        } else if (t == QStringLiteral("ANGRY")) {
            b.bodyX = -5.0f; b.bodyY = -3.0f; b.bodyZ = 0.0f;
            b.headX = -5.0f; b.headY = -5.0f; b.headZ = 0.0f;
            b.duration = 0.5f; b.intensity = 1.2f;
        } else if (t == QStringLiteral("SAD")) {
            b.bodyX = -2.0f; b.bodyY = -3.0f; b.bodyZ = -2.0f;
            b.headX = -3.0f; b.headY = -4.0f; b.headZ = -2.0f;
            b.duration = 0.8f; b.intensity = 0.7f;
        } else if (t == QStringLiteral("SURPRISED")) {
            b.bodyX = -2.0f; b.bodyY = 5.0f; b.bodyZ = 2.0f;
            b.headX = 0.0f; b.headY = 8.0f; b.headZ = 0.0f;
            b.duration = 0.4f; b.intensity = 1.5f;
        } else if (t == QStringLiteral("BLUSH")) {
            b.bodyX = 8.0f; b.bodyY = -2.0f; b.bodyZ = -3.0f;
            b.headX = 12.0f; b.headY = -3.0f; b.headZ = -5.0f;
            b.duration = 0.6f; b.intensity = 1.0f;
        } else if (t == QStringLiteral("WINK")) {
            b.bodyX = 5.0f; b.bodyY = 2.0f; b.bodyZ = -2.0f;
            b.headX = 6.0f; b.headY = 3.0f; b.headZ = -4.0f;
            b.duration = 0.4f; b.intensity = 0.9f;
        } else if (t == QStringLiteral("DISGUST")) {
            b.bodyX = 5.0f; b.bodyY = 4.0f; b.bodyZ = 2.0f;
            b.headX = 7.0f; b.headY = -3.0f; b.headZ = 3.0f;
            b.duration = 0.5f; b.intensity = 1.1f;
        } else if (t == QStringLiteral("SMUG")) {
            b.bodyX = 2.0f; b.bodyY = 2.0f; b.bodyZ = -1.0f;
            b.headX = 5.0f; b.headY = 3.0f; b.headZ = -1.0f;
            b.duration = 0.7f; b.intensity = 0.6f;
        } else if (t == QStringLiteral("THINKING")) {
            b.bodyX = 0.0f; b.bodyY = 0.0f; b.bodyZ = 0.0f;
            b.headX = 2.0f; b.headY = -3.0f; b.headZ = 1.0f;
            b.duration = 0.8f; b.intensity = 0.3f;
        } else if (t == QStringLiteral("PANIC")) {
            b.bodyX = 0.0f; b.bodyY = 0.0f; b.bodyZ = 0.0f;
            b.headX = 0.0f; b.headY = 0.0f; b.headZ = 0.0f;
            b.duration = 0.2f; b.intensity = 2.0f;
        } else if (t == QStringLiteral("SLEEPING")) {
            b.bodyX = -1.0f; b.bodyY = -2.0f; b.bodyZ = -1.0f;
            b.headX = -2.0f; b.headY = -3.0f; b.headZ = -2.0f;
            b.duration = 2.0f; b.intensity = 0.3f;
        }
        return b;
    }

    void GetEmotionIdleMotion(const QString& tag, float phase,
                              float& bodyX, float& bodyY, float& bodyZ,
                              float& headX, float& headY, float& headZ) const {
        bodyX = bodyY = bodyZ = headX = headY = headZ = 0.0f;
        const QString t = tag.toUpper();

        if (t == QStringLiteral("NORMAL")) {
            bodyX = Drift(phase, 0.6f, 0.0f, 1.8f);
            bodyY = Drift(phase, 0.4f, 10.0f, 0.8f) + std::sin(phase * 0.8f) * 0.3f;
            bodyZ = Drift(phase, 0.35f, 20.0f, 0.6f);
            headX = Drift(phase, 0.5f, 30.0f, 3.0f);
            headY = Drift(phase, 0.4f, 40.0f, 2.0f);
            headZ = Drift(phase, 0.3f, 50.0f, 1.0f);
        } else if (t == QStringLiteral("SMILE")) {
            bodyX = Drift(phase, 1.2f, 5.0f, 3.0f);
            bodyY = Drift(phase, 1.0f, 15.0f, 1.5f);
            bodyZ = Drift(phase, 0.7f, 25.0f, 1.5f);
            headX = Drift(phase, 1.0f, 35.0f, 4.0f);
            headY = Drift(phase, 0.8f, 45.0f, 2.5f);
            headZ = Drift(phase, 0.9f, 55.0f, 2.0f);
        } else if (t == QStringLiteral("ANGRY")) {
            const float tension = NoiseSigned(phase * 3.0f, 7.0f);
            bodyX = Drift(phase, 1.5f, 8.0f, 2.5f) + tension * 1.5f;
            bodyY = Drift(phase, 0.5f, 18.0f, 0.8f);
            bodyZ = Drift(phase, 2.0f, 28.0f, 1.2f);
            headX = Drift(phase, 1.8f, 38.0f, 3.0f) + tension * 1.0f;
            headY = Drift(phase, 1.2f, 48.0f, 2.0f);
            headZ = Drift(phase, 0.8f, 58.0f, 1.0f);
        } else if (t == QStringLiteral("SAD")) {
            bodyX = Drift(phase, 0.4f, 3.0f, 2.5f);
            bodyY = Drift(phase, 0.3f, 13.0f, 1.5f);
            bodyZ = Drift(phase, 0.35f, 23.0f, 1.8f);
            headX = Drift(phase, 0.3f, 33.0f, 3.5f);
            headY = Drift(phase, 0.25f, 43.0f, 2.5f);
            headZ = Drift(phase, 0.3f, 53.0f, 1.5f);
        } else if (t == QStringLiteral("SURPRISED")) {
            bodyX = Drift(phase, 1.8f, 6.0f, 3.0f);
            bodyY = Drift(phase, 1.5f, 16.0f, 1.5f) + std::fabs(std::sin(phase * 1.5f)) * 0.8f;
            bodyZ = Drift(phase, 1.0f, 26.0f, 1.5f);
            headX = Drift(phase, 2.0f, 36.0f, 5.0f);
            headY = Drift(phase, 1.8f, 46.0f, 4.5f);
            headZ = Drift(phase, 1.0f, 56.0f, 1.5f);
        } else if (t == QStringLiteral("BLUSH")) {
            const float fidget = NoiseSigned(phase * 4.0f, 99.0f) * 0.75f;
            bodyX = Drift(phase, 0.8f, 9.0f, 3.0f) + 1.0f;
            bodyY = Drift(phase, 0.6f, 19.0f, 1.0f);
            bodyZ = Drift(phase, 0.9f, 29.0f, 2.0f);
            headX = Drift(phase, 0.6f, 39.0f, 4.0f) + 2.0f + fidget;
            headY = Drift(phase, 0.5f, 49.0f, 3.0f);
            headZ = Drift(phase, 0.7f, 59.0f, 2.5f);
        } else if (t == QStringLiteral("WINK")) {
            bodyX = Drift(phase, 1.3f, 4.0f, 3.5f);
            bodyY = Drift(phase, 0.8f, 14.0f, 1.2f);
            bodyZ = Drift(phase, 0.9f, 24.0f, 2.0f);
            headX = Drift(phase, 1.0f, 34.0f, 4.5f);
            headY = Drift(phase, 0.7f, 44.0f, 2.5f);
            headZ = Drift(phase, 1.1f, 54.0f, 2.5f);
        } else if (t == QStringLiteral("DISGUST")) {
            bodyX = Drift(phase, 0.7f, 2.0f, 2.5f) + 1.0f;
            bodyY = Drift(phase, 0.9f, 12.0f, 1.5f);
            bodyZ = Drift(phase, 0.5f, 22.0f, 1.0f);
            headX = Drift(phase, 0.8f, 32.0f, 3.5f) + 1.5f;
            headY = Drift(phase, 0.6f, 42.0f, 2.5f);
            headZ = Drift(phase, 0.5f, 52.0f, 1.5f);
        } else if (t == QStringLiteral("SMUG")) {
            bodyX = Drift(phase, 0.5f, 4.0f, 2.0f);
            bodyY = Drift(phase, 0.4f, 14.0f, 1.0f);
            bodyZ = Drift(phase, 0.4f, 24.0f, 1.5f);
            headX = Drift(phase, 0.6f, 34.0f, 3.0f) + 3.0f;
            headY = Drift(phase, 0.5f, 44.0f, 2.0f);
            headZ = Drift(phase, 0.5f, 54.0f, 1.0f);
        } else if (t == QStringLiteral("THINKING")) {
            bodyX = Drift(phase, 0.2f, 5.0f, 1.0f);
            bodyY = Drift(phase, 0.2f, 15.0f, 0.5f);
            bodyZ = Drift(phase, 0.2f, 25.0f, 0.5f);
            headX = Drift(phase, 0.2f, 35.0f, 1.0f);
            headY = Drift(phase, 0.2f, 45.0f, 1.0f);
            headZ = Drift(phase, 0.2f, 55.0f, 0.5f);
        } else if (t == QStringLiteral("PANIC")) {
            const float panic = NoiseSigned(phase * 15.0f, 999.0f) * 2.0f;
            bodyX = Drift(phase, 2.0f, 6.0f, 2.0f) + panic;
            bodyY = Drift(phase, 2.0f, 16.0f, 2.0f);
            bodyZ = Drift(phase, 2.0f, 26.0f, 2.0f);
            headX = Drift(phase, 3.0f, 36.0f, 3.0f) + panic;
            headY = panic * 1.5f;
            headZ = panic * 0.5f;
        } else if (t == QStringLiteral("SLEEPING")) {
            bodyX = Drift(phase * 0.4f, 0.2f, 0.0f, 0.8f);
            bodyY = Drift(phase * 0.4f, 0.8f, 10.0f, 1.2f) + std::sin(phase * 0.4f) * 0.5f;
            bodyZ = Drift(phase * 0.4f, 0.1f, 20.0f, 0.4f);
            headX = Drift(phase * 0.4f, 0.3f, 30.0f, 1.5f) + std::sin(phase * 0.4f * 0.8f) * 0.8f;
            headY = Drift(phase * 0.4f, 0.2f, 40.0f, 1.0f);
            headZ = Drift(phase * 0.4f, 0.15f, 50.0f, 0.5f);
        }
    }

    void UpdateBlink(float dt) {
        switch (_blinkState) {
        case BlinkState::Open:
            _blinkTimer += dt;
            if (_blinkTimer >= _blinkInterval) {
                _blinkTimer = 0.0f;
                _blinkState = BlinkState::Closing;
                _blinkInterval = RandomRange(2.5f, 6.0f);
            }
            _blinkValue = 1.0f;
            break;
        case BlinkState::Closing: {
            _blinkTimer += dt;
            const float closeRatio = qBound(0.0f, _blinkTimer / qMax(0.001f, _blinkDuration * 0.5f), 1.0f);
            _blinkValue = Lerp(1.0f, 0.0f, closeRatio);
            if (_blinkTimer >= _blinkDuration * 0.5f) {
                _blinkTimer = 0.0f;
                _blinkState = BlinkState::Opening;
            }
            break;
        }
        case BlinkState::Opening: {
            _blinkTimer += dt;
            const float openRatio = qBound(0.0f, _blinkTimer / qMax(0.001f, _blinkDuration * 0.5f), 1.0f);
            _blinkValue = Lerp(0.0f, 1.0f, openRatio);
            if (_blinkTimer >= _blinkDuration * 0.5f) {
                _blinkTimer = 0.0f;
                _blinkState = BlinkState::Open;
            }
            break;
        }
        }
    }

    bool _initialized;
    float _lipSyncValue;
    float _userTimeSeconds;
    float _idlePhase = 0.0f;
    float _emotionLerpSpeed = 3.0f;
    EmotionTarget _currentEmotion;
    EmotionTarget _targetEmotion;
    MotionBurst _activeBurst;
    float _burstTimer = 0.0f;
    float _burstProgress = 1.0f;
    float _wakeUpTimer = 0.0f;
    QString _currentEmotionTag;
    BlinkState _blinkState = BlinkState::Open;
    float _blinkTimer = 0.0f;
    float _blinkInterval = 4.0f;
    float _blinkDuration = 0.1f;
    float _blinkValue = 1.0f;
    float _mouthOpen = 0.0f;
    float _smoothedBodyX = 0.0f;
    float _smoothedBodyY = 0.0f;
    float _smoothedBodyZ = 0.0f;
    float _smoothedHeadX = 0.0f;
    float _smoothedHeadY = 0.0f;
    float _smoothedHeadZ = 0.0f;
    float _smoothedGazeX = 0.0f;
    float _smoothedGazeY = 0.0f;
    float _eyeTrackingX = 0.0f;
    float _eyeTrackingY = 0.0f;
    bool _lightweightMode = false;
    int _lightweightFrameSkip = 0;
    QString _modelDirectory;
    QString _emotionTag;
    CubismModelSettingJson* _setting;
    csmMap<csmString, ACubismMotion*> _expressions;
    csmVector<CubismIdHandle> _lipSyncIds;
    QVector<GLuint> _textureIds;
    QString _spokenChar;

    // ── Cached CubismId pointers (avoid per-frame string lookup) ──
    const CubismId* _idBrowLY = nullptr;
    const CubismId* _idBrowRY = nullptr;
    const CubismId* _idBrowLForm = nullptr;
    const CubismId* _idBrowRForm = nullptr;
    const CubismId* _idBrowLAngle = nullptr;
    const CubismId* _idBrowRAngle = nullptr;
    const CubismId* _idEyeLSmile = nullptr;
    const CubismId* _idEyeRSmile = nullptr;
    const CubismId* _idMouthForm = nullptr;
    const CubismId* _idCheek = nullptr;
    const CubismId* _idEyeLOpen = nullptr;
    const CubismId* _idEyeROpen = nullptr;
    const CubismId* _idBodyAngleX = nullptr;
    const CubismId* _idBodyAngleY = nullptr;
    const CubismId* _idBodyAngleZ = nullptr;
    const CubismId* _idAngleX = nullptr;
    const CubismId* _idAngleY = nullptr;
    const CubismId* _idAngleZ = nullptr;
    const CubismId* _idMouthOpenY = nullptr;
    const CubismId* _idBreath = nullptr;
    const CubismId* _idEyeBallX = nullptr;
    const CubismId* _idEyeBallY = nullptr;
};

AmadeusLive2DModel::AmadeusLive2DModel()
    : m_inner(nullptr), m_currentBackend(RenderBackend::OpenGL) {
    EnsureCubismInitialized();
    m_inner = new InnerModel();
}

AmadeusLive2DModel::~AmadeusLive2DModel() {
    delete m_inner;
    m_inner = nullptr;
}

bool AmadeusLive2DModel::EnsureLoaded(const QString& modelDirectory) {
    if (m_inner == nullptr) {
        return false;
    }
    return m_inner->EnsureLoaded(modelDirectory);
}

void AmadeusLive2DModel::SetEmotionTag(const QString& emotionTag) {
    if (m_inner == nullptr) {
        return;
    }
    m_inner->SetEmotionTag(emotionTag);
}

void AmadeusLive2DModel::SetLipSyncValue(float value) {
    if (m_inner == nullptr) {
        return;
    }
    m_inner->SetLipSyncValue(value);
}

void AmadeusLive2DModel::Update(float deltaSeconds) {
    if (m_inner == nullptr) {
        return;
    }
    m_inner->Update(deltaSeconds);
}

void AmadeusLive2DModel::Draw(int width, int height) {
    if (m_inner == nullptr) {
        return;
    }
    m_inner->Draw(width, height);
}

AmadeusLive2DModel::RenderBackend AmadeusLive2DModel::GetCurrentBackend() const {
    return m_currentBackend;
}

QString AmadeusLive2DModel::GetBackendName() const {
    switch (m_currentBackend) {
    case RenderBackend::OpenGL:    return "OpenGL";
    case RenderBackend::DirectX11: return "DirectX 11";
    case RenderBackend::Vulkan:    return "Vulkan";
    case RenderBackend::Metal:     return "Metal";
    }
    return "Unknown";
}

QStringList AmadeusLive2DModel::GetAvailableBackends() {
    QStringList backends;
    
#ifdef Q_OS_WIN
    // Windows: prefer Vulkan > DirectX 11 > OpenGL fallback
    backends << "Vulkan" << "DirectX11" << "OpenGL";
#elif defined(Q_OS_MACOS)
    // macOS: prefer native Metal if available, else OpenGL
    backends << "Metal" << "OpenGL";
#elif defined(Q_OS_IOS)
    // iOS: prefer Metal > OpenGL
    backends << "Metal" << "OpenGL";
#else
    // Linux, Android, others: prefer Vulkan > OpenGL
    backends << "Vulkan" << "OpenGL";
#endif
    
    return backends;
}

bool AmadeusLive2DModel::TryInitializeWithBackend(const QString& modelDirectory, RenderBackend backend) {
    // Currently, Live2D SDK integration is OpenGL-focused.
    // In future, extend this to:
    // - Vulkan: use CubismRenderer_VulkanES2 (when SDK supports)
    // - DirectX: use CubismRenderer_D3D11 (when SDK supports)
    // - Metal: use CubismRenderer_Metal (for iOS)
    
    // For now, all backends fall back to OpenGL ES2
    if (m_inner == nullptr) {
        return false;
    }
    
    // Log which backend was selected
    qInfo() << "[Live2D] Attempting initialization with backend:" << QString::fromStdString(std::to_string((int)backend));
    m_currentBackend = backend;
    
    // Attempt load with current backend (OpenGL ES2 for all)
    return m_inner->EnsureLoaded(modelDirectory);
}

void AmadeusLive2DModel::SetEyeTracking(float eyeX, float eyeY) {
    if (m_inner) {
        m_inner->SetEyeTracking(qBound(-1.0f, eyeX, 1.0f), qBound(-1.0f, eyeY, 1.0f));
    }
}

void AmadeusLive2DModel::SetLightweightMode(bool enabled) {
    if (m_inner) {
        m_inner->SetLightweightMode(enabled);
    }
}

void AmadeusLive2DModel::SetSpokenChar(const QString& spokenChar) {
    if (m_inner) {
        m_inner->SetSpokenChar(spokenChar);
    }
}

void AmadeusLive2DModel::Preload(const QString& modelDirectory) {
    if (modelDirectory.isEmpty()) return;

    {
        QMutexLocker locker(&s_cacheMutex);
        if (s_modelCache.contains(modelDirectory) || s_loadingDirs.contains(modelDirectory)) {
            return;
        }
        s_loadingDirs.insert(modelDirectory);
    }

    qDebug() << "[Live2D Cache] Starting background preload for:" << modelDirectory;

    QtConcurrent::run([modelDirectory]() {
        ModelDataCache cache;
        cache.modelDirectory = modelDirectory;

        QDir dir(modelDirectory);
        if (!dir.exists()) {
            QMutexLocker locker(&s_cacheMutex);
            s_loadingDirs.remove(modelDirectory);
            qWarning() << "[Live2D Cache] Preload failed: directory not found:" << modelDirectory;
            return;
        }

        QString model3Path;
        const QStringList model3Files = dir.entryList(QStringList() << "*.model3.json", QDir::Files);
        if (model3Files.isEmpty()) {
            QMutexLocker locker(&s_cacheMutex);
            s_loadingDirs.remove(modelDirectory);
            qWarning() << "[Live2D Cache] Preload failed: no .model3.json in" << modelDirectory;
            return;
        }
        model3Path = dir.filePath(model3Files.first());

        cache.model3Bytes = ReadAllBytes(model3Path);
        if (cache.model3Bytes.isEmpty()) {
            QMutexLocker locker(&s_cacheMutex);
            s_loadingDirs.remove(modelDirectory);
            qWarning() << "[Live2D Cache] Preload failed: empty model3.json in" << modelDirectory;
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(cache.model3Bytes, &parseError);
        if (doc.isNull() || !doc.isObject()) {
            QMutexLocker locker(&s_cacheMutex);
            s_loadingDirs.remove(modelDirectory);
            qWarning() << "[Live2D Cache] Preload failed: JSON parse error:" << parseError.errorString();
            return;
        }
        QJsonObject root = doc.object();

        // 1. Moc file
        QString mocFile = root["FileReferences"].toObject()["Moc"].toString();
        if (!mocFile.isEmpty()) {
            cache.mocBytes = ReadAllBytes(dir.filePath(mocFile));
        }

        // 2. Physics file
        QString physicsFile = root["FileReferences"].toObject()["Physics"].toString();
        if (!physicsFile.isEmpty()) {
            cache.physicsBytes = ReadAllBytes(dir.filePath(physicsFile));
        }

        // 3. Pose file
        QString poseFile = root["FileReferences"].toObject()["Pose"].toString();
        if (!poseFile.isEmpty()) {
            cache.poseBytes = ReadAllBytes(dir.filePath(poseFile));
        }

        // 4. Expressions
        QJsonArray expressions = root["FileReferences"].toObject()["Expressions"].toArray();
        for (const QJsonValue &val : expressions) {
            QString expFile = val.toObject()["File"].toString();
            QString name = val.toObject()["Name"].toString();
            if (!expFile.isEmpty() && !name.isEmpty()) {
                cache.expressionBytes[name] = ReadAllBytes(dir.filePath(expFile));
            }
        }

        // 5. Textures (load QImages)
        QJsonArray textures = root["FileReferences"].toObject()["Textures"].toArray();
        for (const QJsonValue &val : textures) {
            QString texFile = val.toString();
            if (!texFile.isEmpty()) {
                QImage img(dir.filePath(texFile));
                if (!img.isNull()) {
                    img = img.convertToFormat(QImage::Format_RGBA8888);
                    cache.textures.append(img);
                } else {
                    cache.textures.append(QImage());
                }
            }
        }

        cache.loaded = true;

        {
            QMutexLocker locker(&s_cacheMutex);
            s_modelCache[modelDirectory] = cache;
            s_loadingDirs.remove(modelDirectory);
        }
        qDebug() << "[Live2D Cache] Preloaded model in background:" << modelDirectory;
    });
}
