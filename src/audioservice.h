#pragma once
#include <QObject>
#include <QAudioOutput>
#include <QMediaPlayer>
#include <QBuffer>
#include <QByteArray>
#include <QUrl>
#include <QTimer>
#include <QSettings>
#include <memory>

/// AudioService - manages audio playback with lip sync support
/// Mirrors Unity AudioManager.cs functionality
class AudioService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playbackStateChanged)
    Q_PROPERTY(qreal currentLipSyncValue READ currentLipSyncValue NOTIFY lipSyncValueChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    
public:
    explicit AudioService(QObject *parent = nullptr);
    ~AudioService();

    bool isPlaying() const;
    qreal currentLipSyncValue() const;
    qreal volume() const;
    void setVolume(qreal vol);

    /// Play audio from file path (WAV/MP3)
    Q_INVOKABLE void playFromFile(const QString &filePath);

    /// Play audio from raw WAV data
    Q_INVOKABLE void playFromData(const QByteArray &wavData);

    /// Play audio from URL
    Q_INVOKABLE void playFromUrl(const QUrl &url);

    /// Stop current playback
    Q_INVOKABLE void stop();

    /// Pause/resume playback
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();

signals:
    void playbackStarted();
    void playbackFinished();
    void playbackStateChanged();
    void lipSyncValueChanged(qreal value);
    void volumeChanged(qreal volume);
    void errorOccurred(const QString &error);

private slots:
    void onMediaStatusChanged(QMediaPlayer::MediaStatus status);
    void onPlaybackStateChanged(QMediaPlayer::PlaybackState state);
    void onErrorOccurred(QMediaPlayer::Error error, const QString &errorString);
    void updateLipSync();

private:
    void initializeAudio();
    qreal extractLipSyncFromAudio();
    
    std::unique_ptr<QMediaPlayer> m_player;
    std::unique_ptr<QAudioOutput> m_audioOutput;
    std::unique_ptr<QBuffer> m_audioBuffer;
    QByteArray m_currentAudioData;
    
    QTimer m_lipSyncTimer;
    qreal m_currentLipSyncValue = 0.0;
    qreal m_volume = 1.0;
    bool m_isPlaying = false;
    
    QSettings m_settings;
    
    static constexpr int LIP_SYNC_UPDATE_MS = 50;
    static constexpr qreal LIP_SYNC_SMOOTHING = 0.3;
};
