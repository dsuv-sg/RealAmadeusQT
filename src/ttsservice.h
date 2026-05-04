#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QCache>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>

/// TTSService - Text-to-Speech client for Christina-TTS
/// Communicates with Python TTS server
class TTSService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString speaker READ speaker WRITE setSpeaker NOTIFY speakerChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(bool serverAvailable READ isServerAvailable NOTIFY serverAvailableChanged)
    Q_PROPERTY(bool usingGpu READ isUsingGpu NOTIFY runtimeInfoChanged)
    Q_PROPERTY(QString runtimeDevice READ runtimeDevice NOTIFY runtimeInfoChanged)
    Q_PROPERTY(QString runtimeDetails READ runtimeDetails NOTIFY runtimeInfoChanged)

public:
    explicit TTSService(QObject *parent = nullptr);

    bool isEnabled() const;
    void setEnabled(bool enabled);
    
    QString speaker() const;
    void setSpeaker(const QString &speaker);
    
    QString serverUrl() const;
    void setServerUrl(const QString &url);
    
    bool isServerAvailable() const;
    bool isUsingGpu() const;
    QString runtimeDevice() const;
    QString runtimeDetails() const;

    /// Synthesize text to speech
    Q_INVOKABLE void synthesize(const QString &text);
    
    /// Check if server is available
    Q_INVOKABLE void checkServerHealth();
    
    /// Get available speakers from server
    Q_INVOKABLE void fetchSpeakers();
    
    /// Preload model on server
    Q_INVOKABLE void preloadModel();
    
    /// Clear server cache
    Q_INVOKABLE void clearServerCache();
    
    /// Clear local cache
    Q_INVOKABLE void clearLocalCache();

signals:
    void synthesisComplete(const QString &audioFilePath);
    void synthesisError(const QString &error);
    void enabledChanged();
    void speakerChanged();
    void serverUrlChanged();
    void serverAvailableChanged();
    void speakersReceived(const QStringList &speakers);
    void runtimeInfoChanged();

private slots:
    void onSynthesisFinished(QNetworkReply *reply);
    void onHealthCheckFinished(QNetworkReply *reply);
    void onSpeakersFinished(QNetworkReply *reply);

private:
    QString getCacheKey(const QString &text, const QString &speaker) const;
    QString getCachePath() const;
    QString getCachedAudioPath(const QString &cacheKey) const;
    bool hasCachedAudio(const QString &cacheKey) const;
    void saveToCache(const QString &cacheKey, const QByteArray &audioData);
    
    QNetworkAccessManager m_nam;
    QSettings m_settings;
    
    bool m_enabled = false;
    QString m_speaker = "christina-jp";
    QString m_serverUrl = "http://localhost:5100";
    bool m_serverAvailable = false;
    bool m_usingGpu = false;
    QString m_runtimeDevice = "unknown";
    QString m_runtimeDetails = "unknown";
    
    // Cache settings
    static constexpr int MAX_CACHE_SIZE_MB = 100;
};
