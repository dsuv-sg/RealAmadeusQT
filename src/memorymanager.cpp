#include "memorymanager.h"
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QRandomGenerator>
#include <QDebug>

MemoryManager::MemoryManager(QObject *parent)
    : QObject(parent)
{
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataPath);
    m_savePath = dataPath + "/kurisu_memory.json";
    loadMemory();
}

QString MemoryManager::getMemoryContext() const
{
    QStringList lines;

    QJsonArray userFacts = m_memory.value("userFacts").toArray();
    if (!userFacts.isEmpty()) {
        lines << "【ユーザーについて知っていること】";
        for (const auto &f : userFacts)
            lines << "- " + f.toString();
    }

    QJsonArray summaries = m_memory.value("conversationSummaries").toArray();
    if (!summaries.isEmpty()) {
        lines << "【過去の会話の記憶】";
        int start = qMax(0, summaries.size() - 3);
        for (int i = start; i < summaries.size(); ++i)
            lines << "- " + summaries[i].toString();
    }

    QString lastDate = m_memory.value("lastSessionDate").toString();
    if (!lastDate.isEmpty())
        lines << "【前回のセッション】" + lastDate;

    int total = m_memory.value("totalInteractions").toInt();
    if (total > 0)
        lines << QString("【累計やりとり回数】%1回").arg(total);

    QJsonArray emotions = m_memory.value("recentEmotions").toArray();
    if (emotions.size() >= 3) {
        QStringList emoList;
        for (const auto &e : emotions) emoList << e.toString();
        lines << "【最近の感情傾向】" + emoList.join("→") + "（同じ感情が続きすぎないように意識して）";
    }

    return lines.join("\n");
}

QString MemoryManager::getDynamicContext(int turnCount) const
{
    QStringList lines;
    lines << QString("【現在の状況】時間帯: %1 / 会話ターン数: %2")
                 .arg(getTimeContext()).arg(turnCount);

    static const QStringList moodHints = {
        "（今は少しリラックスしている）",
        "（知的好奇心が高まっている）",
        "（少し眠そう）",
        "（何かを考え込んでいる）",
        "（いつも通りの調子）"
    };
    int idx = QRandomGenerator::global()->bounded(moodHints.size());
    lines << moodHints[idx];
    return lines.join("\n");
}

QString MemoryManager::getTimeContext() const
{
    int hour = QDateTime::currentDateTime().time().hour();
    if (hour >= 5  && hour < 10) return "朝";
    if (hour >= 10 && hour < 12) return "午前中";
    if (hour >= 12 && hour < 14) return "昼";
    if (hour >= 14 && hour < 17) return "午後";
    if (hour >= 17 && hour < 20) return "夕方";
    if (hour >= 20 && hour < 24) return "夜";
    return "深夜";
}

void MemoryManager::recordInteraction()
{
    int total = m_memory.value("totalInteractions").toInt() + 1;
    m_memory["totalInteractions"] = total;
    m_memory["lastSessionDate"] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm");
    saveMemory();
    emit statsChanged();
}

void MemoryManager::recordEmotion(const QString &emotion)
{
    m_emotionHistory.append(emotion);
    if (m_emotionHistory.size() > EMOTION_HISTORY_SIZE)
        m_emotionHistory.removeFirst();

    QJsonArray arr = m_memory.value("recentEmotions").toArray();
    arr.append(emotion);
    while (arr.size() > EMOTION_HISTORY_SIZE) arr.removeAt(0);
    m_memory["recentEmotions"] = arr;
}

bool MemoryManager::isEmotionRepeated() const
{
    if (m_emotionHistory.size() < 3) return false;
    int consecutive = 0;
    QString last;
    for (const QString &e : m_emotionHistory) {
        if (e == last) consecutive++;
        else { consecutive = 1; last = e; }
    }
    return consecutive >= 3;
}

void MemoryManager::setUserName(const QString &name)
{
    const QString currentName = m_memory.value("userName").toString();
    if (currentName == name) return;

    if (name.isEmpty()) {
        m_memory.remove("userName");
    } else {
        m_memory["userName"] = name;
    }
    saveMemory();
    emit userNameChanged();
}

void MemoryManager::addUserFact(const QString &fact)
{
    if (fact.isEmpty()) return;
    QJsonArray arr = m_memory.value("userFacts").toArray();
    for (const auto &f : arr)
        if (f.toString() == fact) return; // duplicate
    arr.append(fact);
    while (arr.size() > 50) arr.removeAt(0);
    m_memory["userFacts"] = arr;
    saveMemory();
}

void MemoryManager::addConversationSummary(const QString &summary)
{
    if (summary.isEmpty()) return;
    QJsonArray arr = m_memory.value("conversationSummaries").toArray();
    arr.append(summary);
    while (arr.size() > 10) arr.removeAt(0);
    m_memory["conversationSummaries"] = arr;
    saveMemory();
}

QVariantList MemoryManager::trimConversationHistory(QVariantList history, int maxTurns)
{
    // Count non-system messages
    int nonSystem = 0;
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        if (m.value("role").toString() != "system") nonSystem++;
    }
    if (nonSystem <= maxTurns) return history;

    int toRemove = nonSystem - maxTurns + 4;
    QStringList toSummarize;
    int removedCount = 0;
    int idx = 1; // skip system prompt at 0

    while (idx < history.size() && removedCount < toRemove) {
        QVariantMap m = history[idx].toMap();
        QString role    = m.value("role").toString();
        QString content = m.value("content").toString();
        if (content.length() > 50) content = content.left(50) + "...";
        toSummarize << role + ": " + content;
        history.removeAt(idx);
        removedCount++;
    }

    if (!toSummarize.isEmpty()) {
        QString summary = "[" + QDateTime::currentDateTime().toString("MM/dd HH:mm") + "の会話] ";
        summary += toSummarize.join(" / ");
        if (summary.length() > 300) summary = summary.left(300) + "...";
        addConversationSummary(summary);
    }
    return history;
}

void MemoryManager::clearAllMemory()
{
    m_memory = QJsonObject();
    m_emotionHistory.clear();
    saveMemory();
    emit statsChanged();
    emit userNameChanged();
    qDebug() << "[MemoryManager] All memory cleared.";
}

void MemoryManager::saveMemory()
{
    QSaveFile file(m_savePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_memory).toJson());
        file.commit();
    } else {
        qWarning() << "[MemoryManager] Failed to save:" << m_savePath;
    }
}

void MemoryManager::loadMemory()
{
    QFile file(m_savePath);
    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            m_memory = doc.object();
            QJsonArray emos = m_memory.value("recentEmotions").toArray();
            for (const auto &e : emos) m_emotionHistory << e.toString();
            qDebug() << "[MemoryManager] Loaded." << m_memory.value("totalInteractions").toInt() << "interactions.";
        }
    } else {
        qDebug() << "[MemoryManager] No saved memory, starting fresh.";
    }
}
