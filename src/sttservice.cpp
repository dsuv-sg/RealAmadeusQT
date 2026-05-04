#include "sttservice.h"
#include <QMediaDevices>
#include <QAudioDevice>
#include <QFile>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <cmath>

STTService::STTService(QObject *parent)
    : QObject(parent)
{
    // Load settings
    m_enabled = m_settings.value("Config_Experimental_STT_Enabled", false).toBool();
    m_provider = m_settings.value("Config_Experimental_STT_Provider", "groq").toString();
    m_serverUrl = m_settings.value("Config_Experimental_STT_ServerUrl", "http://localhost:5101").toString();
    m_language = m_settings.value("Config_Experimental_STT_Language", "ja").toString();
    
    // Setup silence detection timer
    m_silenceTimer.setSingleShot(true);
    connect(&m_silenceTimer, &QTimer::timeout, this, &STTService::onSilenceTimeout);
    
    // Setup level monitoring timer
    m_levelTimer.setInterval(100);
    connect(&m_levelTimer, &QTimer::timeout, this, [this]() {
        if (m_isRecording && m_audioBuffer) {
            qreal level = calculateAudioLevel(m_audioData.right(SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE / 8) / 10));
            emit recordingProgress(level);
            
            if (level < m_silenceThreshold) {
                if (!m_silenceTimer.isActive()) {
                    m_silenceTimer.start(m_silenceTimeoutMs);
                }
            } else {
                m_silenceTimer.stop();
            }
        }
    });
    
    if (m_enabled) {
        checkServerHealth();
    }
}

STTService::~STTService()
{
    stopRecording();
}

bool STTService::isEnabled() const
{
    return m_enabled;
}

void STTService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_settings.setValue("Config_Experimental_STT_Enabled", enabled);
        emit enabledChanged();
        
        if (enabled) {
            checkServerHealth();
        }
    }
}

QString STTService::provider() const
{
    return m_provider;
}

void STTService::setProvider(const QString &provider)
{
    if (m_provider != provider) {
        m_provider = provider;
        m_settings.setValue("Config_Experimental_STT_Provider", provider);
        emit providerChanged();
    }
}

QString STTService::serverUrl() const
{
    return m_serverUrl;
}

void STTService::setServerUrl(const QString &url)
{
    if (m_serverUrl != url) {
        m_serverUrl = url;
        m_settings.setValue("Config_Experimental_STT_ServerUrl", url);
        emit serverUrlChanged();
        checkServerHealth();
    }
}

QString STTService::language() const
{
    return m_language;
}

void STTService::setLanguage(const QString &lang)
{
    if (m_language != lang) {
        m_language = lang;
        m_settings.setValue("Config_Experimental_STT_Language", lang);
        emit languageChanged();
    }
}

bool STTService::isRecording() const
{
    return m_isRecording;
}

bool STTService::isServerAvailable() const
{
    return m_serverAvailable;
}

void STTService::initializeAudioInput()
{
    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(CHANNELS);
    format.setSampleFormat(QAudioFormat::Int16);
    
    QAudioDevice inputDevice = QMediaDevices::defaultAudioInput();
    if (!inputDevice.isFormatSupported(format)) {
        qWarning() << "[STTService] Audio format not supported by device";
        format = inputDevice.preferredFormat();
    }
    
    m_audioSource = std::make_unique<QAudioSource>(inputDevice, format);
}

void STTService::startRecording()
{
    if (!m_enabled) {
        emit transcriptionError("STT is not enabled");
        return;
    }
    
    if (m_isRecording) {
        qDebug() << "[STTService] Already recording";
        return;
    }
    
    initializeAudioInput();
    
    m_audioData.clear();
    m_audioBuffer = std::make_unique<QBuffer>(&m_audioData);
    m_audioBuffer->open(QIODevice::WriteOnly);
    
    m_audioSource->start(m_audioBuffer.get());
    m_isRecording = true;
    
    m_levelTimer.start();
    
    // Set maximum recording time
    QTimer::singleShot(m_maxRecordingMs, this, [this]() {
        if (m_isRecording) {
            qDebug() << "[STTService] Max recording time reached";
            stopRecording();
        }
    });
    
    emit recordingStateChanged();
    qDebug() << "[STTService] Recording started";
}

void STTService::stopRecording()
{
    if (!m_isRecording) {
        return;
    }
    
    m_levelTimer.stop();
    m_silenceTimer.stop();
    
    if (m_audioSource) {
        m_audioSource->stop();
    }
    
    m_isRecording = false;
    emit recordingStateChanged();
    
    if (m_audioBuffer) {
        m_audioBuffer->close();
    }
    
    qDebug() << "[STTService] Recording stopped, audio size:" << m_audioData.size();
    
    if (m_audioData.size() > 1000) {
        transcribeData(m_audioData);
    } else {
        emit transcriptionError("Recording too short");
    }
    
    m_audioSource.reset();
    m_audioBuffer.reset();
}

void STTService::transcribeFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit transcriptionError(QString("Cannot open file: %1").arg(filePath));
        return;
    }
    
    transcribeData(file.readAll());
}

void STTService::transcribeData(const QByteArray &audioData)
{
    if (!m_enabled) {
        emit transcriptionError("STT is not enabled");
        return;
    }
    
    // Create WAV data with header
    QByteArray wavData = createWavHeader(audioData.size(), SAMPLE_RATE, CHANNELS, BITS_PER_SAMPLE);
    wavData.append(audioData);
    
    // Create multipart request
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    
    // Audio file part
    QHttpPart audioPart;
    audioPart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("audio/wav"));
    audioPart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                        QVariant("form-data; name=\"audio\"; filename=\"recording.wav\""));
    audioPart.setBody(wavData);
    multiPart->append(audioPart);
    
    // Provider part
    QHttpPart providerPart;
    providerPart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                           QVariant("form-data; name=\"provider\""));
    providerPart.setBody(m_provider.toUtf8());
    multiPart->append(providerPart);
    
    // Language part
    QHttpPart languagePart;
    languagePart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                           QVariant("form-data; name=\"language\""));
    languagePart.setBody(m_language.toUtf8());
    multiPart->append(languagePart);
    
    QUrl url(m_serverUrl + "/transcribe");
    QNetworkRequest request(url);
    
    QNetworkReply *reply = m_nam.post(request, multiPart);
    multiPart->setParent(reply);
    
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onTranscriptionFinished(reply);
    });
    
    qDebug() << "[STTService] Sending audio for transcription";
}

void STTService::checkServerHealth()
{
    QUrl url(m_serverUrl + "/health");
    QNetworkRequest request(url);
    request.setTransferTimeout(5000);
    
    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onHealthCheckFinished(reply);
    });
}

void STTService::onAudioDataReady()
{
    // This is handled by QBuffer automatically
}

void STTService::onSilenceTimeout()
{
    if (m_isRecording) {
        qDebug() << "[STTService] Silence detected, stopping recording";
        stopRecording();
    }
}

void STTService::onTranscriptionFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = QString("Transcription failed: %1").arg(reply->errorString());
        qWarning() << "[STTService]" << errorMsg;
        emit transcriptionError(errorMsg);
        return;
    }
    
    QByteArray responseData = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(responseData);
    QJsonObject obj = doc.object();
    
    if (obj.contains("error")) {
        emit transcriptionError(obj["error"].toString());
        return;
    }
    
    QString text = obj["text"].toString();
    qDebug() << "[STTService] Transcription:" << text;
    emit transcriptionComplete(text);
}

void STTService::onHealthCheckFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    bool wasAvailable = m_serverAvailable;
    m_serverAvailable = (reply->error() == QNetworkReply::NoError);
    
    if (m_serverAvailable != wasAvailable) {
        emit serverAvailableChanged();
    }
    
    qDebug() << "[STTService] Server available:" << m_serverAvailable;
}

QByteArray STTService::createWavHeader(int dataSize, int sampleRate, int channels, int bitsPerSample)
{
    QByteArray header;
    QDataStream stream(&header, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    
    int byteRate = sampleRate * channels * bitsPerSample / 8;
    int blockAlign = channels * bitsPerSample / 8;
    
    // RIFF header
    stream.writeRawData("RIFF", 4);
    stream << qint32(36 + dataSize);
    stream.writeRawData("WAVE", 4);
    
    // fmt chunk
    stream.writeRawData("fmt ", 4);
    stream << qint32(16);           // Chunk size
    stream << qint16(1);            // Audio format (PCM)
    stream << qint16(channels);
    stream << qint32(sampleRate);
    stream << qint32(byteRate);
    stream << qint16(blockAlign);
    stream << qint16(bitsPerSample);
    
    // data chunk
    stream.writeRawData("data", 4);
    stream << qint32(dataSize);
    
    return header;
}

qreal STTService::calculateAudioLevel(const QByteArray &data)
{
    if (data.isEmpty()) return 0.0;
    
    const qint16 *samples = reinterpret_cast<const qint16*>(data.constData());
    int sampleCount = data.size() / sizeof(qint16);
    
    qreal sum = 0.0;
    for (int i = 0; i < sampleCount; ++i) {
        sum += std::abs(samples[i]);
    }
    
    qreal average = sum / sampleCount;
    return average / 32768.0;  // Normalize to 0-1
}
