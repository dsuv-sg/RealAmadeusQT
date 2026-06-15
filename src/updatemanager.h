#pragma once
#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class UpdateManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasUpdate READ hasUpdate NOTIFY hasUpdateChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY versionChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY versionChanged)
    Q_PROPERTY(QString updateUrl READ updateUrl NOTIFY versionChanged)
    Q_PROPERTY(bool isChecking READ isChecking NOTIFY isCheckingChanged)

public:
    explicit UpdateManager(QObject *parent = nullptr);

    bool hasUpdate() const { return m_hasUpdate; }
    QString currentVersion() const { return m_currentVersion; }
    QString latestVersion() const { return m_latestVersion; }
    QString updateUrl() const { return m_updateUrl; }
    bool isChecking() const { return m_isChecking; }

    Q_INVOKABLE void checkForUpdate();
    Q_INVOKABLE void startUpdate(int langIndex = 0);

signals:
    void hasUpdateChanged();
    void versionChanged();
    void isCheckingChanged();
    void updateCheckFinished(bool success, bool hasUpdate);

private slots:
    void onReplyFinished();

private:
    bool m_hasUpdate = false;
    bool m_isChecking = false;
    QString m_currentVersion;
    QString m_latestVersion;
    QString m_updateUrl = QStringLiteral("https://github.com/dsuv-sg/RealAmadeusQT/releases/latest");
    qint64 m_assetSize = 0;
    QNetworkAccessManager m_networkManager;

    static QString cleanVersion(QString version);
    static bool compareVersions(const QString &current, const QString &latest);
    static QString getUpdaterScriptContent();
};
