#include "ttsservice.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QDebug>
#include <QFileInfo>

TTSService::TTSService(QObject *parent)
    : QObject(parent)
{
    // Load settings
    m_enabled = m_settings.value("Config_Experimental_TTS_Enabled", false).toBool();
    m_speaker = m_settings.value("Config_Experimental_TTS_Speaker", "christina-jp").toString();
    m_serverUrl = m_settings.value("Config_Experimental_TTS_ServerUrl", "http://localhost:5100").toString();
    
    // Create cache directory
    QDir().mkpath(getCachePath());
    
    // Check server on startup if enabled
    if (m_enabled) {
        checkServerHealth();
    }
}

bool TTSService::isEnabled() const
{
    return m_enabled;
}

void TTSService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_settings.setValue("Config_Experimental_TTS_Enabled", enabled);
        emit enabledChanged();
        
        if (enabled) {
            checkServerHealth();
        }
    }
}

QString TTSService::speaker() const
{
    return m_speaker;
}

void TTSService::setSpeaker(const QString &speaker)
{
    if (m_speaker != speaker) {
        m_speaker = speaker;
        m_settings.setValue("Config_Experimental_TTS_Speaker", speaker);
        emit speakerChanged();
    }
}

QString TTSService::serverUrl() const
{
    return m_serverUrl;
}

void TTSService::setServerUrl(const QString &url)
{
    if (m_serverUrl != url) {
        m_serverUrl = url;
        m_settings.setValue("Config_Experimental_TTS_ServerUrl", url);
        emit serverUrlChanged();
        checkServerHealth();
    }
}

bool TTSService::isServerAvailable() const
{
    return m_serverAvailable;
}

bool TTSService::isUsingGpu() const
{
    return m_usingGpu;
}

QString TTSService::runtimeDevice() const
{
    return m_runtimeDevice;
}

QString TTSService::runtimeDetails() const
{
    return m_runtimeDetails;
}

void TTSService::synthesize(const QString &text)
{
    if (!m_enabled) {
        emit synthesisError("TTS is not enabled");
        return;
    }
    
    if (text.trimmed().isEmpty()) {
        emit synthesisError("Empty text provided");
        return;
    }
    
    // Check cache first
    QString cacheKey = getCacheKey(text, m_speaker);
    if (hasCachedAudio(cacheKey)) {
        QString cachedPath = getCachedAudioPath(cacheKey);
        qDebug() << "[TTSService] Using cached audio:" << cachedPath;
        emit synthesisComplete(cachedPath);
        return;
    }
    
    // Build request
    QUrl url(m_serverUrl + "/synthesize");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    QJsonObject body;
    body["text"] = text;
    body["speaker"] = m_speaker;
    body["use_cache"] = true;
    
    QByteArray jsonData = QJsonDocument(body).toJson();
    
    qDebug() << "[TTSService] Synthesizing:" << text.left(50) << "...";
    
    QNetworkReply *reply = m_nam.post(request, jsonData);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cacheKey]() {
        onSynthesisFinished(reply);
    });
    
    // Store cache key in reply for later use
    reply->setProperty("cacheKey", cacheKey);
}

void TTSService::checkServerHealth()
{
    QUrl url(m_serverUrl + "/health");
    QNetworkRequest request(url);
    request.setTransferTimeout(5000); // 5 second timeout
    
    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onHealthCheckFinished(reply);
    });
}

void TTSService::fetchSpeakers()
{
    QUrl url(m_serverUrl + "/speakers");
    QNetworkRequest request(url);
    
    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onSpeakersFinished(reply);
    });
}

void TTSService::preloadModel()
{
    QUrl url(m_serverUrl + "/preload");
    QNetworkRequest request(url);
    
    m_nam.post(request, QByteArray());
}

void TTSService::clearServerCache()
{
    QUrl url(m_serverUrl + "/clear_cache");
    QNetworkRequest request(url);
    
    m_nam.post(request, QByteArray());
}

void TTSService::clearLocalCache()
{
    QDir cacheDir(getCachePath());
    if (cacheDir.exists()) {
        for (const QString &file : cacheDir.entryList(QDir::Files)) {
            cacheDir.remove(file);
        }
    }
    qDebug() << "[TTSService] Local cache cleared";
}

void TTSService::onSynthesisFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = QString("Synthesis failed: %1").arg(reply->errorString());
        qWarning() << "[TTSService]" << errorMsg;
        emit synthesisError(errorMsg);
        return;
    }
    
    QByteArray audioData = reply->readAll();
    
    if (audioData.isEmpty()) {
        emit synthesisError("Received empty audio data");
        return;
    }
    
    // Save to cache
    QString cacheKey = reply->property("cacheKey").toString();
    saveToCache(cacheKey, audioData);
    
    QString audioPath = getCachedAudioPath(cacheKey);
    qDebug() << "[TTSService] Synthesis complete:" << audioPath;
    emit synthesisComplete(audioPath);
}

void TTSService::onHealthCheckFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    bool wasAvailable = m_serverAvailable;
    m_serverAvailable = (reply->error() == QNetworkReply::NoError);
    
    if (m_serverAvailable != wasAvailable) {
        emit serverAvailableChanged();
    }
    
    if (m_serverAvailable) {
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();
        const QJsonObject runtime = obj.value("runtime").toObject();
        const QJsonObject torchInfo = obj.value("torch").toObject();

        bool newUsingGpu = runtime.value("using_gpu").toBool(false);
        const QString newDevice = runtime.value("device").toString("unknown");
        const QString newGpuName = runtime.value("gpu_name").toString("");
        const QString newAttn = runtime.value("attn_implementation").toString("");
        const bool cudaAvailable = torchInfo.value("cuda_available").toBool(false);
        const QString detectedGpuName = torchInfo.value("detected_gpu_name").toString("");
        const QString details = newGpuName.isEmpty()
                ? newDevice
                : QString("%1 (%2)").arg(newDevice, newGpuName);
        QString newRuntimeDetails = newAttn.isEmpty()
                ? details
                : QString("%1, %2").arg(details, newAttn);

        if (newDevice == "not_loaded") {
            newUsingGpu = false;
            if (cudaAvailable) {
                if (!detectedGpuName.isEmpty()) {
                    newRuntimeDetails = QString("not_loaded (CUDA available: %1)").arg(detectedGpuName);
                } else {
                    newRuntimeDetails = "not_loaded (CUDA available)";
                }
            } else {
                newRuntimeDetails = "not_loaded (CUDA unavailable)";
            }
        }

        bool runtimeChanged = false;
        if (m_usingGpu != newUsingGpu) {
            m_usingGpu = newUsingGpu;
            runtimeChanged = true;
        }
        if (m_runtimeDevice != newDevice) {
            m_runtimeDevice = newDevice;
            runtimeChanged = true;
        }
        if (m_runtimeDetails != newRuntimeDetails) {
            m_runtimeDetails = newRuntimeDetails;
            runtimeChanged = true;
        }
        if (runtimeChanged) {
            emit runtimeInfoChanged();
        }

        qDebug() << "[TTSService] Server is available";
        qDebug() << "[TTSService] Runtime:" << m_runtimeDetails << "GPU=" << m_usingGpu;
    } else {
        bool runtimeChanged = false;
        if (m_usingGpu) {
            m_usingGpu = false;
            runtimeChanged = true;
        }
        if (m_runtimeDevice != "unavailable") {
            m_runtimeDevice = "unavailable";
            runtimeChanged = true;
        }
        if (m_runtimeDetails != "unavailable") {
            m_runtimeDetails = "unavailable";
            runtimeChanged = true;
        }
        if (runtimeChanged) {
            emit runtimeInfoChanged();
        }

        qDebug() << "[TTSService] Server is not available:" << reply->errorString();
    }
}

void TTSService::onSpeakersFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "[TTSService] Failed to fetch speakers:" << reply->errorString();
        return;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject obj = doc.object();
    QJsonArray speakersArray = obj["speakers"].toArray();
    
    QStringList speakers;
    for (const QJsonValue &val : speakersArray) {
        speakers << val.toString();
    }
    
    emit speakersReceived(speakers);
}

QString TTSService::getCacheKey(const QString &text, const QString &speaker) const
{
    QByteArray data = (text + "|" + speaker).toUtf8();
    return QCryptographicHash::hash(data, QCryptographicHash::Md5).toHex();
}

QString TTSService::getCachePath() const
{
    QString basePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return basePath + "/tts_cache";
}

QString TTSService::getCachedAudioPath(const QString &cacheKey) const
{
    return getCachePath() + "/" + cacheKey + ".wav";
}

bool TTSService::hasCachedAudio(const QString &cacheKey) const
{
    return QFile::exists(getCachedAudioPath(cacheKey));
}

void TTSService::saveToCache(const QString &cacheKey, const QByteArray &audioData)
{
    QString path = getCachedAudioPath(cacheKey);
    QFile file(path);
    
    if (file.open(QIODevice::WriteOnly)) {
        file.write(audioData);
        file.close();
        qDebug() << "[TTSService] Saved to cache:" << path;
    } else {
        qWarning() << "[TTSService] Failed to save cache:" << path;
    }
}
