#pragma once
#include <QObject>
#include <QStringList>

class LocalizationManager;

class RandomEventService : public QObject
{
    Q_OBJECT
public:
    explicit RandomEventService(QObject *parent = nullptr);

    void setLocalizationManager(LocalizationManager *locManager);

    Q_INVOKABLE bool tryTriggerEvent();
    Q_INVOKABLE QString getEventText() const;
    Q_INVOKABLE QString getEventEmotion() const;
    Q_INVOKABLE QString getEventKey() const;

signals:
    void eventTriggered(const QString &text, const QString &emotion);

private:
    void initEvents();
    LocalizationManager *m_locManager = nullptr;
    QString m_lastEventKey;
    QString m_lastEventDefaultText;
    QString m_lastEventEmotion;

    struct RandomEvent {
        QString key;
        QString defaultText;
        QString emotion;
        int weight;
    };
    QList<RandomEvent> m_events;
};
