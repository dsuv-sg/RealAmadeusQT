#include "achievementmanager.h"
#include "localizationmanager.h"
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QDir>
#include <QDate>
#include <QDebug>

AchievementManager::AchievementManager(LocalizationManager *localization, QObject *parent)
    : QObject(parent)
    , m_localization(localization)
{
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataPath);
    m_savePath = dataPath + "/achievements.json";
    initDefinitions();
    loadState();
    updateLaunchStreak();

    if (m_localization) {
        connect(m_localization, &LocalizationManager::translationsChanged,
                this, &AchievementManager::achievementsChanged);
    }
}

QString AchievementManager::trAch(const QString &key, const QString &defaultValue) const
{
    if (m_localization)
        return m_localization->t(key, defaultValue);
    return defaultValue;
}

void AchievementManager::initDefinitions()
{
    m_definitions = {
        {"first_chat", "ach_first_chat_title", "ach_first_chat_desc", "初めまして", "初めて紅莉栖と会話した", "chat", false},
        {"chat_10", "ach_chat_10_title", "ach_chat_10_desc", "常連", "10回会話した", "chat", false},
        {"chat_50", "ach_chat_50_title", "ach_chat_50_desc", "親友", "50回会話した", "chat", false},
        {"chat_100", "ach_chat_100_title", "ach_chat_100_desc", "ラボメン", "100回会話した", "chat", false},
        {"first_angry", "ach_first_angry_title", "ach_first_angry_desc", "怒らせた", "初めて紅莉栖を怒らせた", "angry", false},
        {"first_blush", "ach_first_blush_title", "ach_first_blush_desc", "照れさせた", "初めて紅莉栖を照れさせた", "blush", false},
        {"first_smile", "ach_first_smile_title", "ach_first_smile_desc", "笑顔", "初めて紅莉栖を笑顔にした", "smile", false},
        {"first_normal", "ach_first_normal_title", "ach_first_normal_desc", "平常心", "初めて紅莉栖の平常な姿を見た", "normal", false},
        {"first_sad", "ach_first_sad_title", "ach_first_sad_desc", "悲しませた", "初めて紅莉栖を悲しませた", "sad", false},
        {"first_surprised", "ach_first_surprised_title", "ach_first_surprised_desc", "驚かせた", "初めて紅莉栖を驚かせた", "surprised", false},
        {"first_wink", "ach_first_wink_title", "ach_first_wink_desc", "ウインク", "初めて紅莉栖にウインクされた", "wink", false},
        {"first_disgust", "ach_first_disgust_title", "ach_first_disgust_desc", "呆れさせた", "初めて紅莉栖を呆れさせた", "disgust", false},
        {"first_smug", "ach_first_smug_title", "ach_first_smug_desc", "ドヤ顔", "初めて紅莉栖のドヤ顔を見た", "smug", false},
        {"first_thinking", "ach_first_thinking_title", "ach_first_thinking_desc", "考えさせた", "初めて紅莉栖を考え込ませた", "thinking", false},
        {"first_panic", "ach_first_panic_title", "ach_first_panic_desc", "パニック", "初めて紅莉栖をパニックにした", "panic", false},
        {"all_emotions", "ach_all_emotions_title", "ach_all_emotions_desc", "感情マスター", "全ての感情を引き出した", "emotions", false},
        {"night_owl", "ach_night_owl_title", "ach_night_owl_desc", "夜更かし", "深夜(0-4時)に会話した", "night", false},
        {"early_bird", "ach_early_bird_title", "ach_early_bird_desc", "早起き", "朝(5-7時)に会話した", "morning", false},
        {"streak_3", "ach_streak_3_title", "ach_streak_3_desc", "3日連続", "3日連続で起動した", "streak", false},
        {"streak_7", "ach_streak_7_title", "ach_streak_7_desc", "1週間", "7日連続で起動した", "streak", false},
        {"first_game", "ach_first_game_title", "ach_first_game_desc", "ゲーマー", "初めてミニゲームをプレイした", "game", false},
        {"game_win", "ach_game_win_title", "ach_game_win_desc", "勝利", "ミニゲームで勝利した", "game", false},
        {"game_perfect", "ach_game_perfect_title", "ach_game_perfect_desc", "パーフェクト", "ミニゲームで全問正解した", "game", false},
        {"export_chat", "ach_export_chat_title", "ach_export_chat_desc", "記録者", "会話記録をエクスポートした", "export", false},
        {"import_chat", "ach_import_chat_title", "ach_import_chat_desc", "時間旅行者", "会話記録をインポートした", "import", false},
        {"first_event", "ach_first_event_title", "ach_first_event_desc", "偶然の出会い", "起動時ランダムイベントが発生した", "event", false},
        {"dev_user", "ach_dev_user_title", "ach_dev_user_desc", "開発者", "開発コマンドを使用した", "dev", false},
        {"secret_reading_steiner", "ach_secret_reading_steiner_title", "ach_secret_reading_steiner_desc", "リーディングシュタイナー", "世界線を超えた秘密を発見した", "secret", true},
    };
}

int AchievementManager::unlockedCount() const
{
    return m_state.value("unlocked").toArray().size();
}

int AchievementManager::totalCount() const
{
    return m_definitions.size();
}

QVariantList AchievementManager::getAllAchievements() const
{
    QVariantList result;
    QJsonArray unlocked = m_state.value("unlocked").toArray();
    for (const auto &def : m_definitions) {
        QVariantMap item;
        bool isUnlocked = unlocked.contains(QJsonValue(def.id));
        item["id"] = def.id;
        item["icon"] = def.icon;
        item["secret"] = def.secret;
        item["unlocked"] = isUnlocked;
        if (def.secret && !isUnlocked) {
            item["title"] = QStringLiteral("???");
            item["description"] = trAch("achievement_secret_hint", "シークレットアチーブメント");
        } else {
            item["title"] = trAch(def.titleKey, def.defaultTitle);
            item["description"] = trAch(def.descKey, def.defaultDesc);
        }
        QString unlockedAt = m_state.value("dates").toObject().value(def.id).toString();
        item["unlockedAt"] = unlockedAt;
        result.append(item);
    }
    return result;
}

bool AchievementManager::isUnlocked(const QString &id) const
{
    return m_state.value("unlocked").toArray().contains(QJsonValue(id));
}

void AchievementManager::unlock(const QString &id)
{
    if (isUnlocked(id))
        return;

    QJsonArray arr = m_state.value("unlocked").toArray();
    arr.append(id);
    m_state["unlocked"] = arr;

    QJsonObject dates = m_state.value("dates").toObject();
    dates[id] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm");
    m_state["dates"] = dates;

    saveState();

    QString title, desc;
    for (const auto &def : m_definitions) {
        if (def.id == id) {
            title = trAch(def.titleKey, def.defaultTitle);
            desc = trAch(def.descKey, def.defaultDesc);
            break;
        }
    }
    emit achievementUnlocked(id, title, desc);
    emit achievementsChanged();
}

void AchievementManager::notifyEvent(const QString &eventType, const QVariantMap &data)
{
    checkAutoUnlocks(eventType, data);
}

void AchievementManager::checkAutoUnlocks(const QString &eventType, const QVariantMap &data)
{
    int totalInteractions = data.value("totalInteractions", 0).toInt();
    QString emotion = data.value("emotion", "").toString();
    int hour = QDateTime::currentDateTime().time().hour();

    if (eventType == "chat") {
        if (totalInteractions >= 1) unlock("first_chat");
        if (totalInteractions >= 10) unlock("chat_10");
        if (totalInteractions >= 50) unlock("chat_50");
        if (totalInteractions >= 100) unlock("chat_100");
    }

    if (eventType == "emotion") {
        if (emotion == "ANGRY") unlock("first_angry");
        if (emotion == "BLUSH") unlock("first_blush");
        if (emotion == "SMILE") unlock("first_smile");
        if (emotion == "NORMAL") unlock("first_normal");
        if (emotion == "SAD") unlock("first_sad");
        if (emotion == "SURPRISED") unlock("first_surprised");
        if (emotion == "WINK") unlock("first_wink");
        if (emotion == "DISGUST") unlock("first_disgust");
        if (emotion == "SMUG") unlock("first_smug");
        if (emotion == "THINKING") unlock("first_thinking");
        if (emotion == "PANIC") unlock("first_panic");

        static const QStringList allEmotions = {
            "NORMAL", "SMILE", "ANGRY", "SAD", "SURPRISED",
            "BLUSH", "WINK", "DISGUST", "SMUG", "THINKING", "PANIC"
        };
        QJsonArray seen = m_state.value("seenEmotions").toArray();
        if (!seen.contains(QJsonValue(emotion))) {
            seen.append(emotion);
            m_state["seenEmotions"] = seen;
            saveState();
        }
        bool allSeen = true;
        for (const QString &e : allEmotions) {
            if (!seen.contains(QJsonValue(e))) { allSeen = false; break; }
        }
        if (allSeen) unlock("all_emotions");
    }

    if (eventType == "chat") {
        if (hour >= 0 && hour < 4) unlock("night_owl");
        if (hour >= 5 && hour < 7) unlock("early_bird");
    }

    if (eventType == "startup") {
        int streak = data.value("streak", 0).toInt();
        if (streak >= 3) unlock("streak_3");
        if (streak >= 7) unlock("streak_7");
    }

    if (eventType == "game_play") unlock("first_game");
    if (eventType == "game_win") unlock("game_win");
    if (eventType == "game_perfect") unlock("game_perfect");
    if (eventType == "export") unlock("export_chat");
    if (eventType == "import") unlock("import_chat");
    if (eventType == "random_event") unlock("first_event");
    if (eventType == "dev_command") unlock("dev_user");
    if (eventType == "secret_steiner") unlock("secret_reading_steiner");
}

void AchievementManager::updateLaunchStreak()
{
    QDate today = QDate::currentDate();
    QDate last = QDate::fromString(m_state.value("lastLaunchDate").toString(), QStringLiteral("yyyy-MM-dd"));
    int streak = m_state.value("launchStreak").toInt();

    if (last == today) {
        // Relaunched on the same day: keep the current streak.
    } else if (last.isValid() && last.daysTo(today) == 1) {
        streak += 1;
    } else {
        streak = 1;
    }

    m_state["lastLaunchDate"] = today.toString(QStringLiteral("yyyy-MM-dd"));
    m_state["launchStreak"] = streak;
    saveState();

    if (streak >= 3) unlock("streak_3");
    if (streak >= 7) unlock("streak_7");
}

void AchievementManager::resetAll()
{
    m_state = QJsonObject();
    m_state["unlocked"] = QJsonArray();
    m_state["dates"] = QJsonObject();
    m_state["seenEmotions"] = QJsonArray();
    saveState();
    emit achievementsChanged();
}

void AchievementManager::loadState()
{
    QFile file(m_savePath);
    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            m_state = doc.object();
        }
    }
    if (!m_state.contains("unlocked")) m_state["unlocked"] = QJsonArray();
    if (!m_state.contains("dates")) m_state["dates"] = QJsonObject();
    if (!m_state.contains("seenEmotions")) m_state["seenEmotions"] = QJsonArray();
}

void AchievementManager::saveState()
{
    QSaveFile file(m_savePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_state).toJson());
        file.commit();
    }
}
