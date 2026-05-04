#pragma once
#include <QObject>
#include <QSettings>
#include <QSystemTrayIcon>
#include <QIcon>
#include <QApplication>

/// NotificationService - Desktop notifications via QSystemTrayIcon.
/// Controlled by Config_DesktopNotifications setting.
class NotificationService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit NotificationService(QObject *parent = nullptr);

    bool isEnabled() const;
    void setEnabled(bool enabled);

    /// Show a desktop notification (respects enabled setting).
    /// Only shows when the application window is not active.
    Q_INVOKABLE void show(const QString &title, const QString &message);

signals:
    void enabledChanged();

private:
    void ensureTrayIcon();

    QSystemTrayIcon *m_trayIcon = nullptr;
    QSettings m_settings;
    bool m_enabled = true;
};
