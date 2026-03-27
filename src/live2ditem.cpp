#include "live2ditem.h"

#include "amadeuslive2dmodel.h"

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QQuickWindow>

namespace {

static QString ResolveModelDirectory(const QString& modelPath) {
    if (modelPath.isEmpty()) {
        return QString();
    }

    QDir inputDir(modelPath);
    if (inputDir.exists()) {
        return inputDir.absolutePath();
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        QDir::cleanPath(appDir + "/resources/models/" + modelPath),
        QDir::cleanPath(QStringLiteral(REALAMADEUS_PROJECT_ROOT) + "/resources/models/" + modelPath),
        QDir::cleanPath(QStringLiteral(REALAMADEUS_PROJECT_ROOT) + "/../RealAmadeusUnity/Assets/" + modelPath)
    };

    for (const QString& candidate : candidates) {
        if (QDir(candidate).exists()) {
            return candidate;
        }
    }

    return QDir::cleanPath(QStringLiteral(REALAMADEUS_PROJECT_ROOT) + "/../RealAmadeusUnity/Assets/" + modelPath);
}

class Live2DRenderer final : public QQuickFramebufferObject::Renderer, protected QOpenGLFunctions {
public:
    Live2DRenderer()
        : m_model(new AmadeusLive2DModel()),
                    m_glReady(false),
          m_lipSyncValue(0.0f) {
        m_timer.start();
    }

    ~Live2DRenderer() override {
        delete m_model;
    }

    QOpenGLFramebufferObject* createFramebufferObject(const QSize& size) override {
        QOpenGLFramebufferObjectFormat format;
        format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
        format.setSamples(0);
        return new QOpenGLFramebufferObject(size, format);
    }

    void synchronize(QQuickFramebufferObject* item) override {
        auto* live2dItem = static_cast<Live2DItem*>(item);
        m_modelDir = ResolveModelDirectory(live2dItem->modelPath());
        m_emotion = live2dItem->emotion();
        m_lipSyncValue = live2dItem->lipSyncValue();
    }

    void render() override {
        if (!m_glReady) {
            initializeOpenGLFunctions();
            glDisable(GL_SCISSOR_TEST);
            m_glReady = true;
        }

        // Restore only states that Cubism renderer may modify
        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        if (!m_model->EnsureLoaded(m_modelDir)) {
            glViewport(0, 0, framebufferObject()->width(), framebufferObject()->height());
            glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
            update();
            return;
        }

        const qint64 elapsedMs = m_timer.restart();
        const float deltaSeconds = qBound(0.001f, elapsedMs / 1000.0f, 0.1f);

        glViewport(0, 0, framebufferObject()->width(), framebufferObject()->height());
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        m_model->SetEmotionTag(m_emotion);
        m_model->SetLipSyncValue(m_lipSyncValue);
        m_model->Update(deltaSeconds);
        m_model->Draw(framebufferObject()->width(), framebufferObject()->height());

        update();
    }

private:
    AmadeusLive2DModel* m_model;
    bool m_glReady;
    QString m_modelDir;
    QString m_emotion;
    float m_lipSyncValue;
    QElapsedTimer m_timer;
};

} // namespace

Live2DItem::Live2DItem(QQuickItem* parent)
    : QQuickFramebufferObject(parent),
      m_modelPath(QStringLiteral("AmadeusKurisu5.0/reama5.0")),
      m_emotion(QStringLiteral("NORMAL")),
      m_lipSyncValue(0.0f) {
}

QQuickFramebufferObject::Renderer* Live2DItem::createRenderer() const {
    return new Live2DRenderer();
}

QString Live2DItem::modelPath() const {
    return m_modelPath;
}

void Live2DItem::setModelPath(const QString& value) {
    if (m_modelPath == value) {
        return;
    }
    m_modelPath = value;
    emit modelPathChanged();
    update();
}

QString Live2DItem::emotion() const {
    return m_emotion;
}

void Live2DItem::setEmotion(const QString& value) {
    if (m_emotion == value) {
        return;
    }
    m_emotion = value;
    emit emotionChanged();
    update();
}

float Live2DItem::lipSyncValue() const {
    return m_lipSyncValue;
}

void Live2DItem::setLipSyncValue(float value) {
    if (qFuzzyCompare(m_lipSyncValue, value)) {
        return;
    }
    m_lipSyncValue = value;
    emit lipSyncValueChanged();
    update();
}

void Live2DItem::itemChange(ItemChange change, const ItemChangeData& value) {
    QQuickFramebufferObject::itemChange(change, value);
    
    // Lazy initialize model when item becomes visible on screen
    if (change == ItemVisibleHasChanged && value.boolValue) {
        TryLazyInitialize();
    }
}

void Live2DItem::TryLazyInitialize() {
    if (m_lazyInitialized || m_modelPath.isEmpty()) {
        return;
    }
    
    m_lazyInitialized = true;
    qInfo() << "[Live2DItem] Lazy initializing model:" << m_modelPath;
    
    // Model will be loaded asynchronously on next frame render
    // This prevents blocking startup while showing boot/login UI
    update();
}
