#include "localizationmanager.h"
#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QDir>

LocalizationManager::LocalizationManager(AppSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_languageIndex(0)
{
    m_languages = {"ja", "en", "zh", "ko", "es", "fr", "de", "ru", "uk", "pt", "tr", "he", "ar"};

    if (m_settings) {
        m_languageIndex = m_settings->getInt("Config_Language", 0);
        connect(m_settings, &AppSettings::settingsChanged, this, [this](const QString &key) {
            if (key == "Config_Language") {
                int newLang = m_settings->getInt("Config_Language", 0);
                if (newLang != m_languageIndex) {
                    setLanguage(newLang);
                }
            }
        });
    }

    loadTranslations();
}

QVariantMap LocalizationManager::translations() const
{
    return m_translations;
}

int LocalizationManager::language() const
{
    return m_languageIndex;
}

void LocalizationManager::setLanguage(int langIndex)
{
    if (langIndex < 0 || langIndex >= m_languages.size()) {
        langIndex = 0;
    }
    if (m_languageIndex != langIndex) {
        m_languageIndex = langIndex;
        emit languageChanged(m_languageIndex);
        loadTranslations();
    }
}

QString LocalizationManager::t(const QString &key, const QString &defaultValue) const
{
    if (m_translations.contains(key)) {
        return m_translations.value(key).toString();
    }
    return defaultValue.isEmpty() ? key : defaultValue;
}

void LocalizationManager::loadTranslations()
{
    QString langCode = "ja";
    if (m_languageIndex >= 0 && m_languageIndex < m_languages.size()) {
        langCode = m_languages.at(m_languageIndex);
    }

    // Attempt to load from the following locations in order:
    // 1. External path relative to application (allows runtime edits by translators)
    // 2. Fallback using CMake's REALAMADEUS_PROJECT_ROOT definition
    // 3. Fallback embedded resource path (qrc)
    QString basePath = QCoreApplication::applicationDirPath() + "/resources/locales/";
    QString filePath = basePath + langCode + ".json";

    QFile file(filePath);
    bool opened = file.open(QIODevice::ReadOnly | QIODevice::Text);

#ifdef REALAMADEUS_PROJECT_ROOT
    if (!opened) {
        filePath = QDir(REALAMADEUS_PROJECT_ROOT).absoluteFilePath("resources/locales/" + langCode + ".json");
        file.setFileName(filePath);
        opened = file.open(QIODevice::ReadOnly | QIODevice::Text);
    }
#endif

    if (!opened) {
        filePath = ":/qt/qml/RealAmadeusPC/resources/locales/" + langCode + ".json";
        file.setFileName(filePath);
        opened = file.open(QIODevice::ReadOnly | QIODevice::Text);
    }

    if (opened) {
        QByteArray data = file.readAll();
        file.close();

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (doc.isNull()) {
            qWarning() << "Failed to parse translation file:" << filePath << "Error:" << parseError.errorString();
            return;
        }

        QJsonObject obj = doc.object();
        m_translations = obj.toVariantMap();
        emit translationsChanged();
        qDebug() << "Loaded translations for language:" << langCode << "from" << filePath;
    } else {
        qWarning() << "Could not open translation file in any location. Language:" << langCode;
    }
}
