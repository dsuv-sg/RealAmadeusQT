#include "nativettservice.h"
#include <QSettings>
#include <QDebug>

NativeTTSService::NativeTTSService(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_enabled = settings.value("Config_NativeTTS_Enabled", false).toBool();
    m_useGPU = settings.value("Config_NativeTTS_UseGPU", false).toBool();

    m_speech = new QTextToSpeech(this);
    connect(m_speech, &QTextToSpeech::stateChanged, this, &NativeTTSService::onStateChanged);

    // Try to set a Japanese voice if available
    const auto voices = m_speech->availableVoices();
    for (const auto &voice : voices) {
        if (voice.locale().language() == QLocale::Japanese) {
            m_speech->setVoice(voice);
            break;
        }
    }
}

NativeTTSService::~NativeTTSService()
{
}

bool NativeTTSService::isEnabled() const
{
    return m_enabled;
}

void NativeTTSService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        QSettings().setValue("Config_NativeTTS_Enabled", enabled);
        emit enabledChanged();
    }
}

bool NativeTTSService::useGPU() const
{
    return m_useGPU;
}

void NativeTTSService::setUseGPU(bool use)
{
    if (m_useGPU != use) {
        m_useGPU = use;
        QSettings().setValue("Config_NativeTTS_UseGPU", use);
        emit useGPUChanged();
    }
}

bool NativeTTSService::isGPUAvailable() const
{
    // QTextToSpeech itself does not use GPU.
    // Future: check for ONNX Runtime + DirectML/CUDA backends.
    return false;
}

bool NativeTTSService::isSpeaking() const
{
    return m_speech && m_speech->state() == QTextToSpeech::Speaking;
}

void NativeTTSService::speak(const QString &text)
{
    if (!m_enabled || !m_speech) {
        qDebug() << "[NativeTTSService] Not enabled or speech engine unavailable";
        return;
    }
    if (text.trimmed().isEmpty()) return;
    m_speech->say(text);
}

void NativeTTSService::stop()
{
    if (m_speech)
        m_speech->stop();
}

void NativeTTSService::onStateChanged(QTextToSpeech::State state)
{
    emit speakingChanged();
    if (state == QTextToSpeech::Speaking) {
        emit speakingStarted();
    } else if (state == QTextToSpeech::Ready) {
        emit speakingFinished();
    }
}