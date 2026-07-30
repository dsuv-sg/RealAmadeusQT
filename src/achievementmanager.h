#pragma once
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QStringList>

class LocalizationManager;

class AchievementManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int unlockedCount READ unlockedCount NOTIFY achievementsChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY achievementsChanged)
public:
    explicit AchievementManager(LocalizationManager *localization = nullptr, QObject *parent = nullptr);

    int unlockedCount() const;
    int totalCount() const;

    Q_INVOKABLE QVariantList getAllAchievements() const;
    Q_INVOKABLE bool isUnlocked(const QString &id) const;
    Q_INVOKABLE void unlock(const QString &id);
    Q_INVOKABLE void notifyEvent(const QString &eventType, const QVariantMap &data = {});
    Q_INVOKABLE void resetAll();

signals:
    void achievementsChanged();
    void achievementUnlocked(const QString &id, const QString &title, const QString &description);

private:
    struct AchievementDef {
        QString id;
        QString titleKey;
        QString descKey;
        QString defaultTitle;
        QString defaultDesc;
        QString icon;
        bool secret = false;
    };

    void initDefinitions();
    void loadState();
    void saveState();
    void checkAutoUnlocks(const QString &eventType, const QVariantMap &data);
    void updateLaunchStreak();
    QString trAch(const QString &key, const QString &defaultValue) const;

    QList<AchievementDef> m_definitions;
    QJsonObject m_state;
    QString m_savePath;
    LocalizationManager *m_localization;
};
