#pragma once
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>
#include <QVector>

struct ChatMessage {
    QString role;    // "system", "user", "assistant"
    QString content;
};

/// MemoryManager - mirrors Unity MemoryManager.cs
/// Manages short-term conversation window and long-term JSON persistence.
class MemoryManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString userName READ userName NOTIFY userNameChanged)
    Q_PROPERTY(int totalInteractions READ totalInteractions NOTIFY statsChanged)
public:
    explicit MemoryManager(QObject *parent = nullptr);

    QString userName() const { return m_memory.value("userName").toString(); }
    int totalInteractions() const { return m_memory.value("totalInteractions").toInt(); }

    Q_INVOKABLE QString getMemoryContext() const;
    Q_INVOKABLE QString getDynamicContext(int turnCount) const;
    Q_INVOKABLE QString getTimeContext() const;

    Q_INVOKABLE void recordInteraction();
    Q_INVOKABLE void recordEmotion(const QString &emotion);
    Q_INVOKABLE bool isEmotionRepeated() const;

    Q_INVOKABLE void setUserName(const QString &name);
    Q_INVOKABLE void addUserFact(const QString &fact);
    Q_INVOKABLE void addConversationSummary(const QString &summary);

    /// Trims conversation history (mutates the list in-place via QML variant list).
    /// Returns number of messages removed.
    Q_INVOKABLE int trimConversationHistory(QVariantList &history, int maxTurns = 30);

    Q_INVOKABLE void clearAllMemory();

signals:
    void userNameChanged();
    void statsChanged();

private:
    void loadMemory();
    void saveMemory();

    QJsonObject m_memory;
    QStringList m_emotionHistory; // recent 10
    QString m_savePath;

    static const int EMOTION_HISTORY_SIZE = 10;
};
