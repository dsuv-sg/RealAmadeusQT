#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QAudioSource>
#include <QAudioFormat>
#include <QBuffer>
#include <QTimer>
#include <memory>

/// STTService - Speech-to-Text client
/// Communicates with Python STT server (Whisper)
class STTService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY providerChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingStateChanged)
    Q_PROPERTY(bool serverAvailable READ isServerAvailable NOTIFY serverAvailableChanged)

public:
    explicit STTService(QObject *parent = nullptr);
    ~STTService();

    bool isEnabled() const;
    void setEnabled(bool enabled);
    
    QString provider() const;
    void setProvider(const QString &provider);
    
    QString serverUrl() const;
    void setServerUrl(const QString &url);
    
    QString language() const;
    void setLanguage(const QString &lang);
    
    bool isRecording() const;
    bool isServerAvailable() const;

    /// Start recording from microphone
    Q_INVOKABLE void startRecording();
    
    /// Stop recording and transcribe
    Q_INVOKABLE void stopRecording();
    
    /// Transcribe audio file
    Q_INVOKABLE void transcribeFile(const QString &filePath);
    
    /// Transcribe audio data (WAV format)
    Q_INVOKABLE void transcribeData(const QByteArray &audioData);
    
    /// Check if server is available
    Q_INVOKABLE void checkServerHealth();

signals:
    void transcriptionComplete(const QString &text);
    void transcriptionError(const QString &error);
    void enabledChanged();
    void providerChanged();
    void serverUrlChanged();
    void languageChanged();
    void recordingStateChanged();
    void serverAvailableChanged();
    void recordingProgress(qreal level);

private slots:
    void onAudioDataReady();
    void onSilenceTimeout();
    void onTranscriptionFinished(QNetworkReply *reply);
    void onHealthCheckFinished(QNetworkReply *reply);

private:
    void initializeAudioInput();
    QByteArray createWavHeader(int dataSize, int sampleRate, int channels, int bitsPerSample);
    qreal calculateAudioLevel(const QByteArray &data);
    
    QNetworkAccessManager m_nam;
    QSettings m_settings;
    
    std::unique_ptr<QAudioSource> m_audioSource;
    std::unique_ptr<QBuffer> m_audioBuffer;
    QByteArray m_audioData;
    
    QTimer m_silenceTimer;
    QTimer m_levelTimer;
    
    bool m_enabled = false;
    QString m_provider = "groq";
    QString m_serverUrl = "http://localhost:5101";
    QString m_language = "ja";
    bool m_isRecording = false;
    bool m_serverAvailable = false;
    
    qreal m_silenceThreshold = 0.01;
    int m_silenceTimeoutMs = 1500;
    int m_maxRecordingMs = 30000;
    
    static constexpr int SAMPLE_RATE = 16000;
    static constexpr int CHANNELS = 1;
    static constexpr int BITS_PER_SAMPLE = 16;
};
