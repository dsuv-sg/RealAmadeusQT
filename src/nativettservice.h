#pragma once
#include <QObject>
#include <QTextToSpeech>

/// NativeTTSService - Qt TextToSpeech backend (no external server)
class NativeTTSService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool useGPU READ useGPU WRITE setUseGPU NOTIFY useGPUChanged)
    Q_PROPERTY(bool speaking READ isSpeaking NOTIFY speakingChanged)
    Q_PROPERTY(bool gpuAvailable READ isGPUAvailable NOTIFY gpuAvailableChanged)

public:
    explicit NativeTTSService(QObject *parent = nullptr);
    ~NativeTTSService();

    bool isEnabled() const;
    void setEnabled(bool enabled);

    bool useGPU() const;
    void setUseGPU(bool use);

    bool isGPUAvailable() const;
    bool isSpeaking() const;

    Q_INVOKABLE void speak(const QString &text);
    Q_INVOKABLE void stop();

signals:
    void speakingStarted();
    void speakingFinished();
    void enabledChanged();
    void useGPUChanged();
    void speakingChanged();
    void gpuAvailableChanged();

private slots:
    void onStateChanged(QTextToSpeech::State state);

private:
    QTextToSpeech *m_speech = nullptr;
    bool m_enabled = false;
    bool m_useGPU = false;
};