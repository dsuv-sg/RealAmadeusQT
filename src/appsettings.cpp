#include "appsettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings("RealAmadeus", "AmadeusSystem")
{}

int AppSettings::getInt(const QString &key, int defaultValue) const
{
    return m_settings.value(key, defaultValue).toInt();
}

float AppSettings::getFloat(const QString &key, float defaultValue) const
{
    return m_settings.value(key, (double)defaultValue).toFloat();
}

QString AppSettings::getString(const QString &key, const QString &defaultValue) const
{
    return m_settings.value(key, defaultValue).toString();
}

void AppSettings::setInt(const QString &key, int value)
{
    m_settings.setValue(key, value);
    emit settingsChanged(key);
}

void AppSettings::setFloat(const QString &key, float value)
{
    m_settings.setValue(key, (double)value);
    emit settingsChanged(key);
}

void AppSettings::setString(const QString &key, const QString &value)
{
    m_settings.setValue(key, value);
    emit settingsChanged(key);
}

void AppSettings::save()
{
    m_settings.sync();
}
