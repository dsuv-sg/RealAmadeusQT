#pragma once
#include <QObject>
#include <QAudioSource>
#include <QAudioFormat>
#include <QBuffer>
#include <QTimer>
#include <memory>

/// NativeSTTService - Local speech-to-text via Whisper.cpp DLL
class NativeSTTService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool useGPU READ useGPU WRITE setUseGPU NOTIFY useGPUChanged)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingStateChanged)
    Q_PROPERTY(bool whisperAvailable READ isWhisperAvailable NOTIFY whisperAvailableChanged)

public:
    explicit NativeSTTService(QObject *parent = nullptr);
    ~NativeSTTService();

    bool isEnabled() const;
    void setEnabled(bool enabled);

    bool useGPU() const;
    void setUseGPU(bool use);

    bool isRecording() const;
    bool isWhisperAvailable() const;

    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();

signals:
    void transcriptionComplete(const QString &text);
    void transcriptionError(const QString &error);
    void enabledChanged();
    void useGPUChanged();
    void recordingStateChanged();
    void whisperAvailableChanged();
    void recordingProgress(qreal level);

private slots:
    void onSilenceTimeout();
    void onLevelTimer();

private:
    void initializeAudioInput();
    QByteArray createWavHeader(int dataSize, int sampleRate, int channels, int bitsPerSample);
    qreal calculateAudioLevel(const QByteArray &data);
    QString resolveWhisperModelPath() const;

    std::unique_ptr<QAudioSource> m_audioSource;
    std::unique_ptr<QBuffer> m_audioBuffer;
    QByteArray m_audioData;

    QTimer m_silenceTimer;
    QTimer m_levelTimer;

    bool m_enabled = false;
    bool m_useGPU = false;
    bool m_isRecording = false;
    mutable bool m_whisperAvailableCached = false;
    mutable bool m_whisperChecked = false;

    qreal m_silenceThreshold = 0.01;
    int m_silenceTimeoutMs = 1500;
    int m_maxRecordingMs = 30000;

    static constexpr int SAMPLE_RATE = 16000;
    static constexpr int CHANNELS = 1;
    static constexpr int BITS_PER_SAMPLE = 16;
};