#include "notificationservice.h"
#include <QGuiApplication>
#include <QWindow>
#include <QDebug>

NotificationService::NotificationService(QObject *parent)
    : QObject(parent)
    , m_settings("RealAmadeus", "AmadeusSystem")
{
    m_enabled = m_settings.value("Config_DesktopNotifications", 1).toInt() == 1;
}

bool NotificationService::isEnabled() const
{
    return m_enabled;
}

void NotificationService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_settings.setValue("Config_DesktopNotifications", enabled ? 1 : 0);
        emit enabledChanged();
    }
}

void NotificationService::ensureTrayIcon()
{
    if (m_trayIcon)
        return;

    m_trayIcon = new QSystemTrayIcon(this);

    // Use application icon
    QIcon appIcon = QApplication::windowIcon();
    if (appIcon.isNull()) {
        appIcon = QIcon::fromTheme("dialog-information");
    }
    m_trayIcon->setIcon(appIcon);
    m_trayIcon->setToolTip("Real Amadeus");
    m_trayIcon->show();
}

void NotificationService::show(const QString &title, const QString &message)
{
    if (!m_enabled)
        return;

    // Only notify when window is not active
    const auto windows = QGuiApplication::allWindows();
    for (const auto *win : windows) {
        if (win && win->isActive())
            return;
    }

    if (!QSystemTrayIcon::supportsMessages()) {
        qDebug() << "[Notification] System does not support tray notifications";
        return;
    }

    ensureTrayIcon();

    // Truncate for safety
    QString safeTitle = title.left(64);
    QString safeMessage = message.left(220);

    m_trayIcon->showMessage(safeTitle, safeMessage,
                            QSystemTrayIcon::Information, 3000);
}
