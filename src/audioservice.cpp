#include "audioservice.h"
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QRandomGenerator>
#include <cmath>

AudioService::AudioService(QObject *parent)
    : QObject(parent)
{
    // Load saved volume BEFORE initializing audio
    m_volume = m_settings.value("Config_VoiceVolume", 1.0).toDouble();
    initializeAudio();
    
    // Setup lip sync timer
    m_lipSyncTimer.setInterval(LIP_SYNC_UPDATE_MS);
    connect(&m_lipSyncTimer, &QTimer::timeout, this, &AudioService::updateLipSync);
}

AudioService::~AudioService()
{
    stop();
    QFile::remove(m_tempFilePath);
}

void AudioService::initializeAudio()
{
    m_audioOutput = std::make_unique<QAudioOutput>();
    m_player = std::make_unique<QMediaPlayer>();
    m_player->setAudioOutput(m_audioOutput.get());
    
    m_audioOutput->setVolume(static_cast<float>(m_volume));
    
    connect(m_player.get(), &QMediaPlayer::mediaStatusChanged,
            this, &AudioService::onMediaStatusChanged);
    connect(m_player.get(), &QMediaPlayer::playbackStateChanged,
            this, &AudioService::onPlaybackStateChanged);
    connect(m_player.get(), &QMediaPlayer::errorOccurred,
            this, &AudioService::onErrorOccurred);
}

bool AudioService::isPlaying() const
{
    return m_isPlaying;
}

qreal AudioService::currentLipSyncValue() const
{
    return m_currentLipSyncValue;
}

qreal AudioService::volume() const
{
    return m_volume;
}

void AudioService::setVolume(qreal vol)
{
    m_volume = qBound(0.0, vol, 1.0);
    if (m_audioOutput) {
        m_audioOutput->setVolume(static_cast<float>(m_volume));
    }
    m_settings.setValue("Config_VoiceVolume", m_volume);
    emit volumeChanged(m_volume);
}

void AudioService::playFromFile(const QString &filePath)
{
    stop();
    
    QUrl url = QUrl::fromLocalFile(filePath);
    if (!QFile::exists(filePath)) {
        emit errorOccurred(QString("Audio file not found: %1").arg(filePath));
        return;
    }
    
    m_player->setSource(url);
    m_player->play();
}

void AudioService::playFromData(const QByteArray &wavData)
{
    stop();
    
    if (!m_tempFilePath.isEmpty()) {
        QFile::remove(m_tempFilePath);
        m_tempFilePath.clear();
    }
    
    m_currentAudioData = wavData;
    m_audioBuffer = std::make_unique<QBuffer>(&m_currentAudioData);
    m_audioBuffer->open(QIODevice::ReadOnly);
    
    QString tempPath = QDir::tempPath() + QStringLiteral("/amadeus_tts_%1.wav")
        .arg(QRandomGenerator::global()->generate(), 16, 16, QLatin1Char('0'));
    m_tempFilePath = tempPath;
    QFile tempFile(tempPath);
    if (tempFile.open(QIODevice::WriteOnly)) {
        tempFile.write(wavData);
        tempFile.close();
        playFromFile(tempPath);
    } else {
        emit errorOccurred("Failed to create temporary audio file");
    }
}


void AudioService::playFromUrl(const QUrl &url)
{
    stop();
    m_player->setSource(url);
    m_player->play();
}

void AudioService::stop()
{
    m_lipSyncTimer.stop();
    m_currentLipSyncValue = 0.0;
    emit lipSyncValueChanged(m_currentLipSyncValue);
    
    if (m_player) {
        m_player->stop();
    }
    
    if (m_audioBuffer) {
        m_audioBuffer->close();
        m_audioBuffer.reset();
    }
    
    if (!m_tempFilePath.isEmpty()) {
        QFile::remove(m_tempFilePath);
        m_tempFilePath.clear();
    }
    
    m_isPlaying = false;
    emit playbackStateChanged();
}

void AudioService::pause()
{
    if (m_player) {
        m_player->pause();
        m_lipSyncTimer.stop();
    }
}

void AudioService::resume()
{
    if (m_player) {
        m_player->play();
        if (m_isPlaying) {
            m_lipSyncTimer.start();
        }
    }
}

void AudioService::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    switch (status) {
    case QMediaPlayer::LoadedMedia:
        qDebug() << "[AudioService] Media loaded, starting playback";
        break;
    case QMediaPlayer::EndOfMedia:
        m_lipSyncTimer.stop();
        m_currentLipSyncValue = 0.0;
        emit lipSyncValueChanged(m_currentLipSyncValue);
        m_isPlaying = false;
        emit playbackStateChanged();
        emit playbackFinished();
        break;
    case QMediaPlayer::InvalidMedia:
        emit errorOccurred("Invalid media format");
        break;
    default:
        break;
    }
}

void AudioService::onPlaybackStateChanged(QMediaPlayer::PlaybackState state)
{
    bool wasPlaying = m_isPlaying;
    m_isPlaying = (state == QMediaPlayer::PlayingState);
    
    if (m_isPlaying && !wasPlaying) {
        m_lipSyncTimer.start();
        emit playbackStarted();
    } else if (!m_isPlaying && wasPlaying) {
        m_lipSyncTimer.stop();
    }
    
    emit playbackStateChanged();
}

void AudioService::onErrorOccurred(QMediaPlayer::Error error, const QString &errorString)
{
    Q_UNUSED(error)
    qWarning() << "[AudioService] Error:" << errorString;
    emit errorOccurred(errorString);
}

void AudioService::updateLipSync()
{
    if (!m_isPlaying) {
        m_currentLipSyncValue = 0.0;
        emit lipSyncValueChanged(m_currentLipSyncValue);
        return;
    }
    
    qreal targetValue = extractLipSyncFromAudio();
    
    // Smooth transition
    m_currentLipSyncValue = m_currentLipSyncValue * (1.0 - LIP_SYNC_SMOOTHING) + 
                           targetValue * LIP_SYNC_SMOOTHING;
    
    emit lipSyncValueChanged(m_currentLipSyncValue);
}

qreal AudioService::extractLipSyncFromAudio()
{
    // Since we don't have direct access to audio samples in Qt6 QMediaPlayer,
    // we generate a procedural lip sync based on playback position
    // This provides smooth, natural-looking mouth movement
    
    if (!m_player) return 0.0;
    
    qint64 position = m_player->position();
    qint64 duration = m_player->duration();
    
    if (duration <= 0) return 0.0;
    
    // Create varied but smooth lip movement
    double time = position / 1000.0; // Convert to seconds
    
    // Multiple sine waves for natural movement
    double base = std::sin(time * 8.0) * 0.3 + 0.5;
    double detail = std::sin(time * 15.0) * 0.15;
    double accent = std::sin(time * 3.0) * 0.1;
    
    // Add some randomness for natural feel
    double noise = (QRandomGenerator::global()->bounded(100) - 50) / 500.0;
    
    double result = base + detail + accent + noise;
    return qBound(0.0, result, 1.0);
}
