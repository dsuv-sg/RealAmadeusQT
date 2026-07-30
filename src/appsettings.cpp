#include "appsettings.h"
#include "securesettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings("RealAmadeus", "AmadeusSystem")
{}

int AppSettings::getInt(const QString &key, int defaultValue) const
{
    return m_settings.value(key, defaultValue).toInt();
}

double AppSettings::getFloat(const QString &key, double defaultValue) const
{
    return m_settings.value(key, defaultValue).toDouble();
}

QString AppSettings::getString(const QString &key, const QString &defaultValue) const
{
    if (key.contains(QStringLiteral("ApiKey"))) {
        return SecureSettings::getProtectedString(m_settings, key, defaultValue);
    }
    return m_settings.value(key, defaultValue).toString();
}

void AppSettings::setInt(const QString &key, int value)
{
    m_settings.setValue(key, value);
    emit settingsChanged(key);
}

void AppSettings::setFloat(const QString &key, double value)
{
    m_settings.setValue(key, value);
    emit settingsChanged(key);
}

void AppSettings::setString(const QString &key, const QString &value)
{
    if (key.contains(QStringLiteral("ApiKey"))) {
        SecureSettings::setProtectedString(m_settings, key, value);
        emit settingsChanged(key);
        return;
    }
    m_settings.setValue(key, value);
    emit settingsChanged(key);
}

void AppSettings::save()
{
    m_settings.sync();
}

