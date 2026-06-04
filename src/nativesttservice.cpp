#include "nativesttservice.h"
#include "whisper.h"
#include <QSettings>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QDebug>
#include <cmath>
#include <algorithm>
#include <thread>
#include <QtConcurrent>
#include <QFutureWatcher>

NativeSTTService::NativeSTTService(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_enabled = settings.value("Config_NativeSTT_Enabled", false).toBool();
    m_useGPU = settings.value("Config_NativeSTT_UseGPU", false).toBool();

    m_silenceTimer.setSingleShot(true);
    connect(&m_silenceTimer, &QTimer::timeout, this, &NativeSTTService::onSilenceTimeout);

    m_levelTimer.setInterval(100);
    connect(&m_levelTimer, &QTimer::timeout, this, &NativeSTTService::onLevelTimer);
}

NativeSTTService::~NativeSTTService()
{
    stopRecording();
}

bool NativeSTTService::isEnabled() const
{
    return m_enabled;
}

void NativeSTTService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        QSettings().setValue("Config_NativeSTT_Enabled", enabled);
        emit enabledChanged();
    }
}

bool NativeSTTService::useGPU() const
{
    return m_useGPU;
}

void NativeSTTService::setUseGPU(bool use)
{
    if (m_useGPU != use) {
        m_useGPU = use;
        QSettings().setValue("Config_NativeSTT_UseGPU", use);
        emit useGPUChanged();
    }
}

bool NativeSTTService::isRecording() const
{
    return m_isRecording;
}

bool NativeSTTService::isWhisperAvailable() const
{
    if (m_whisperChecked) return m_whisperAvailableCached;

    QString modelPath = resolveWhisperModelPath();
    if (modelPath.isEmpty() || !QFile::exists(modelPath)) {
        qDebug() << "[NativeSTTService] Whisper model not found at" << modelPath;
        m_whisperAvailableCached = false;
        m_whisperChecked = true;
        return false;
    }

    // File existence check is sufficient for availability, avoiding heavy synchronous model loading on UI thread.
    m_whisperAvailableCached = true;
    m_whisperChecked = true;
    return m_whisperAvailableCached;
}

void NativeSTTService::initializeAudioInput()
{
    QAudioFormat format;
    format.setSampleRate(SAMPLE_RATE);
    format.setChannelCount(CHANNELS);
    format.setSampleFormat(QAudioFormat::Int16);

    QAudioDevice inputDevice = QMediaDevices::defaultAudioInput();
    if (!inputDevice.isFormatSupported(format)) {
        qWarning() << "[NativeSTTService] Audio format not supported by device";
        format = inputDevice.preferredFormat();
    }

    m_audioSource = std::make_unique<QAudioSource>(inputDevice, format);
}

void NativeSTTService::startRecording()
{
    if (!m_enabled) {
        emit transcriptionError("Native STT is not enabled");
        return;
    }
    if (m_isRecording) return;

    initializeAudioInput();
    m_audioData.clear();
    m_audioBuffer = std::make_unique<QBuffer>(&m_audioData);
    m_audioBuffer->open(QIODevice::WriteOnly);
    m_audioSource->start(m_audioBuffer.get());
    m_isRecording = true;
    m_levelTimer.start();

    QTimer::singleShot(m_maxRecordingMs, this, [this]() {
        if (m_isRecording) stopRecording();
    });

    emit recordingStateChanged();
    qDebug() << "[NativeSTTService] Recording started";
}

// Static helper to avoid accessing NativeSTTService* in a background thread
static QPair<QString, QString> doWhisperTranscriptionBackground(const QString &modelPath, const QByteArray &wavData) {
    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context *ctx = whisper_init_from_file_with_params(modelPath.toUtf8().constData(), cparams);
    if (!ctx) {
        return qMakePair(QString(), QString("Failed to initialize Whisper context"));
    }

    // Convert WAV bytes to float samples (skip 44-byte header)
    QByteArray pcmData = wavData.mid(44);
    const qint16 *samples = reinterpret_cast<const qint16*>(pcmData.constData());
    int nSamples = pcmData.size() / sizeof(qint16);
    QVector<float> fSamples(nSamples);
    for (int i = 0; i < nSamples; ++i) fSamples[i] = samples[i] / 32768.0f;

    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_special = false;
    wparams.print_realtime = false;
    wparams.translate = false;
    wparams.language = "ja";
    wparams.n_threads = std::max(1, (int)std::thread::hardware_concurrency() / 2);

    int ret = whisper_full(ctx, wparams, fSamples.constData(), fSamples.size());

    QString resultText;
    if (ret == 0) {
        int n = whisper_full_n_segments(ctx);
        for (int i = 0; i < n; ++i) {
            const char* txt = whisper_full_get_segment_text(ctx, i);
            if (txt) resultText += QString::fromUtf8(txt);
        }
    }

    whisper_free(ctx);

    if (ret != 0) {
        return qMakePair(QString(), QString("Whisper transcription failed"));
    }

    resultText = resultText.trimmed();
    if (resultText.isEmpty()) {
        return qMakePair(QString(), QString("No speech detected"));
    }

    return qMakePair(resultText, QString());
}

void NativeSTTService::stopRecording()
{
    if (!m_isRecording) return;

    m_levelTimer.stop();
    m_silenceTimer.stop();
    if (m_audioSource) m_audioSource->stop();
    m_isRecording = false;
    emit recordingStateChanged();

    if (m_audioBuffer) m_audioBuffer->close();

    qDebug() << "[NativeSTTService] Recording stopped, size:" << m_audioData.size();

    if (m_audioData.size() > 1000) {
        QByteArray wavData = createWavHeader(m_audioData.size(), SAMPLE_RATE, CHANNELS, BITS_PER_SAMPLE);
        wavData.append(m_audioData);

        QString modelPath = resolveWhisperModelPath();
        if (modelPath.isEmpty()) {
            emit transcriptionError("Whisper model file not found");
        } else {
            // Asynchronously transcribe audio in a worker thread
            auto watcher = new QFutureWatcher<QPair<QString, QString>>(this);
            connect(watcher, &QFutureWatcher<QPair<QString, QString>>::finished, this, [this, watcher]() {
                QPair<QString, QString> res = watcher->result();
                watcher->deleteLater();

                QString text = res.first;
                QString error = res.second;

                if (!error.isEmpty()) {
                    emit transcriptionError(error);
                } else {
                    emit transcriptionComplete(text);
                }
            });

            QFuture<QPair<QString, QString>> future = QtConcurrent::run([modelPath, wavData]() {
                return doWhisperTranscriptionBackground(modelPath, wavData);
            });
            watcher->setFuture(future);
        }
    } else {
        emit transcriptionError("Recording too short");
    }

    m_audioSource.reset();
    m_audioBuffer.reset();
}

void NativeSTTService::onSilenceTimeout()
{
    if (m_isRecording) stopRecording();
}

void NativeSTTService::onLevelTimer()
{
    if (!m_isRecording) return;
    qreal level = calculateAudioLevel(m_audioData.right(SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE / 8) / 10));
    emit recordingProgress(level);
    if (level < m_silenceThreshold) {
        if (!m_silenceTimer.isActive()) m_silenceTimer.start(m_silenceTimeoutMs);
    } else {
        m_silenceTimer.stop();
    }
}

QByteArray NativeSTTService::createWavHeader(int dataSize, int sampleRate, int channels, int bitsPerSample)
{
    QByteArray header;
    QDataStream stream(&header, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    int byteRate = sampleRate * channels * bitsPerSample / 8;
    int blockAlign = channels * bitsPerSample / 8;
    stream.writeRawData("RIFF", 4);
    stream << qint32(36 + dataSize);
    stream.writeRawData("WAVE", 4);
    stream.writeRawData("fmt ", 4);
    stream << qint32(16);
    stream << qint16(1);
    stream << qint16(channels);
    stream << qint32(sampleRate);
    stream << qint32(byteRate);
    stream << qint16(blockAlign);
    stream << qint16(bitsPerSample);
    stream.writeRawData("data", 4);
    stream << qint32(dataSize);
    return header;
}

qreal NativeSTTService::calculateAudioLevel(const QByteArray &data)
{
    if (data.isEmpty()) return 0.0;
    const qint16 *samples = reinterpret_cast<const qint16*>(data.constData());
    int sampleCount = data.size() / sizeof(qint16);
    qreal sum = 0.0;
    for (int i = 0; i < sampleCount; ++i) sum += std::abs(samples[i]);
    return (sum / sampleCount) / 32768.0;
}

// transcribeWithWhisper removed in favor of static doWhisperTranscriptionBackground

QString NativeSTTService::resolveWhisperModelPath() const
{
    QStringList candidates;
    QString appDir = QCoreApplication::applicationDirPath();
    candidates << appDir + "/whisper-base.bin"
               << appDir + "/models/whisper-base.bin"
               << appDir + "/../models/whisper-base.bin"
               << QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/whisper-base.bin"
               << QStandardPaths::writableLocation(QStandardPaths::HomeLocation) + "/.realamadeus/whisper-base.bin"
               << QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/RealAmadeus/whisper-base.bin";

    for (const QString &path : candidates) {
        if (QFile::exists(path)) return path;
    }
    return QString();
}