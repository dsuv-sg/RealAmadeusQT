#pragma once
#include <QObject>
#include <QSettings>
#include <QString>

/// AppSettings - QSettings wrapper that mirrors Unity PlayerPrefs keys.
class AppSettings : public QObject
{
    Q_OBJECT
public:
    explicit AppSettings(QObject *parent = nullptr);

    Q_INVOKABLE int    getInt(const QString &key, int    defaultValue = 0)    const;
    Q_INVOKABLE double getFloat(const QString &key, double defaultValue = 0.0) const;
    Q_INVOKABLE QString getString(const QString &key, const QString &defaultValue = {}) const;

    Q_INVOKABLE void setInt(const QString &key, int    value);
    Q_INVOKABLE void setFloat(const QString &key, double value);
    Q_INVOKABLE void setString(const QString &key, const QString &value);
    Q_INVOKABLE void save();

signals:
    void settingsChanged(const QString &key);

private:
    QSettings m_settings;
};
