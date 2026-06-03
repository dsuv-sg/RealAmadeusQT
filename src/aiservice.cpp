#include "aiservice.h"
#include "appsettings.h"
#include "securesettings.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>
#include <QDebug>
#include <QProcess>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QTimer>
#include <QtConcurrent>

#include <functional>
#include <memory>

namespace {
constexpr int kVertexTokenCacheMinutes = 50;
const char *kVertexRegions[] = {
    "us-central1",
    "us-west1",
    "us-east4",
    "asia-northeast1",
    "northamerica-northeast1"
};

QStringList getVertexTargetRegions(const QString &preferredLocation)
{
    QStringList targets;
    const QString preferred = preferredLocation.trimmed();
    if (!preferred.isEmpty()) {
        targets << preferred;
    }

    for (const char *region : kVertexRegions) {
        const QString candidate = QString::fromUtf8(region);
        if (!targets.contains(candidate)) {
            targets << candidate;
        }
    }
    return targets;
}

QString buildVertexUrl(const QString &projectId, const QString &location,
                       const QString &model, const QString &method)
{
    if (location == "global") {
        return QString("https://aiplatform.googleapis.com/v1/projects/%1"
                       "/locations/global/publishers/google/models/%2:%3")
            .arg(projectId, model, method);
    }
    return QString("https://%1-aiplatform.googleapis.com/v1/projects/%2"
                   "/locations/%3/publishers/google/models/%4:%5")
        .arg(location, projectId, location, model, method);
}

bool isVertexRetryableStatus(int statusCode)
{
    return statusCode == 429 || statusCode >= 500;
}

bool isValidGroqModel(const QString &model, bool allowCompound)
{
    if (model.contains("llama") ||
        model.contains("mixtral") ||
        model.contains("gemma") ||
        model.contains("qwen") ||
        model.contains("deepseek")) {
        return true;
    }
    return allowCompound && model.contains("compound");
}

QString unescapeJsonLikeUnity(const QString &text)
{
    QString out = text;
    out.replace("\\n", "\n");
    out.replace("\\r", "\r");
    out.replace("\\t", "\t");
    out.replace("\\\"", "\"");
    out.replace("\\\\", "\\");
    return out;
}

int findClosingQuoteLikeUnity(const QString &json, int startAfterQuote)
{
    for (int i = startAfterQuote; i < json.size(); ++i) {
        if (json.at(i) != '"') {
            continue;
        }

        int backslashes = 0;
        int j = i - 1;
        while (j >= 0 && json.at(j) == '\\') {
            ++backslashes;
            --j;
        }
        if ((backslashes % 2) == 0) {
            return i;
        }
    }
    return json.size();
}

QStringList extractVertexStreamTokensLikeUnity(const QByteArray &chunk)
{
    const QString jsonChunk = QString::fromUtf8(chunk);
    QStringList tokens;
    int idx = 0;

    while ((idx = jsonChunk.indexOf("\"text\":", idx)) >= 0) {
        int start = jsonChunk.indexOf('"', idx + 7);
        if (start < 0) {
            break;
        }
        ++start;

        const int end = findClosingQuoteLikeUnity(jsonChunk, start);
        if (end > start) {
            tokens.append(unescapeJsonLikeUnity(jsonChunk.mid(start, end - start)));
            idx = end;
        } else {
            break;
        }
    }

    return tokens;
}

QByteArray buildGroqCompoundBody(const QVariantList &messages, bool stream)
{
    QJsonArray msgs;
    for (const QVariant &v : messages) {
        const QVariantMap m = v.toMap();
        QJsonObject obj;
        obj["role"] = m.value("role").toString();
        obj["content"] = m.value("content").toString();
        msgs.append(obj);
    }

    QJsonObject body;
    body["model"] = "groq/compound";
    body["messages"] = msgs;
    body["max_tokens"] = 2048;
    body["temperature"] = 0.85;
    if (stream) {
        body["stream"] = true;
    }
    return QJsonDocument(body).toJson(QJsonDocument::Compact);
}
}

// ─────────────────────────────────────────────────────
// Constructor
// ─────────────────────────────────────────────────────
AIService::AIService(QObject *parent)
    : QObject(parent),
      m_settings("RealAmadeus", "AmadeusSystem")
{}

bool AIService::isWebSearchEnabled() const
{
    QMutexLocker locker(&m_settingsMutex);
    return m_settings.value("Config_WebSearch", 0).toInt() == 1;
}

void AIService::setWebSearchEnabled(bool enabled)
{
    {
        QMutexLocker locker(&m_settingsMutex);
        m_settings.setValue("Config_WebSearch", enabled ? 1 : 0);
    }
    emit webSearchEnabledChanged();
}

// ─────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────
QString AIService::getApiKey(int provider) const
{
    QMutexLocker locker(&m_settingsMutex);
    QString keyKey = QString("Config_ApiKey_%1").arg(provider);
    QString key = SecureSettings::getProtectedString(const_cast<QSettings&>(m_settings), keyKey, "");
    if (key.isEmpty())
        key = SecureSettings::getProtectedString(const_cast<QSettings&>(m_settings), "Config_ApiKey", "");
    return key;
}


QString AIService::getModel(int provider) const
{
    QMutexLocker locker(&m_settingsMutex);
    QString model = m_settings.value(QString("Config_ModelName_%1").arg(provider), "").toString();
    if (model.isEmpty())
        model = m_settings.value("Config_ModelName", "").toString();
    return model;
}

QString AIService::runGcloudAccessToken(const QString &gcloudPath) const
{
    QProcess proc;
    proc.setProgram(gcloudPath);
    proc.setArguments({"auth", "print-access-token"});
    proc.setProcessChannelMode(QProcess::SeparateChannels);
    proc.start();
    if (!proc.waitForStarted(3000)) {
        return {};
    }
    if (!proc.waitForFinished(10000)) {
        proc.kill();
        proc.waitForFinished(1000);
        return {};
    }

    const QString output = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    if (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0 && output.startsWith("ya29.")) {
        return output;
    }

    return {};
}

QString AIService::getVertexAccessToken()
{
    {
        QMutexLocker locker(&m_tokenMutex);
        if (!m_cachedVertexToken.isEmpty() && QDateTime::currentDateTimeUtc() < m_vertexTokenExpiry) {
            return m_cachedVertexToken;
        }
    }

    QStringList candidates;
#ifdef Q_OS_WIN
    candidates << "gcloud";

    const QString localAppData = qEnvironmentVariable("LOCALAPPDATA");
    if (!localAppData.isEmpty()) {
        candidates << QDir(localAppData).filePath("Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd");
    }

    const QString programFiles = qEnvironmentVariable("ProgramFiles");
    if (!programFiles.isEmpty()) {
        candidates << QDir(programFiles).filePath("Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd");
    }

    const QString userProfile = qEnvironmentVariable("USERPROFILE");
    if (!userProfile.isEmpty()) {
        candidates << QDir(userProfile).filePath("AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd");
    }
#else
    candidates << "gcloud" << "/usr/local/bin/gcloud" << "/usr/bin/gcloud";
#endif

    for (const QString &candidate : candidates) {
        if (candidate != "gcloud" && !QFileInfo::exists(candidate)) {
            continue;
        }
        const QString token = runGcloudAccessToken(candidate);
        if (!token.isEmpty()) {
            QMutexLocker locker(&m_tokenMutex);
            m_cachedVertexToken = token;
            m_vertexTokenExpiry = QDateTime::currentDateTimeUtc().addSecs(kVertexTokenCacheMinutes * 60);
            qInfo() << "[Vertex AI] Access token acquired via" << candidate
                    << "cached for" << kVertexTokenCacheMinutes << "minutes.";
            return m_cachedVertexToken;
        }
    }

    return {};
}

QString AIService::escapeJson(const QString &s)
{
    QString r = s;
    r.replace("\\", "\\\\");
    r.replace("\"", "\\\"");
    r.replace("\n", "\\n");
    r.replace("\r", "\\r");
    r.replace("\t", "\\t");
    return r;
}

// ─────────────────────────────────────────────────────
// Body Builders
// ─────────────────────────────────────────────────────
QByteArray AIService::buildOpenAIBody(const QVariantList &messages, const QString &model,
                                      bool stream, bool isGroq) const
{
    QJsonArray msgs;
    for (const QVariant &v : messages) {
        QVariantMap m = v.toMap();
        QJsonObject obj;
        obj["role"]    = m.value("role").toString();
        obj["content"] = m.value("content").toString();
        msgs.append(obj);
    }

    QJsonObject body;
    body["model"]      = model;
    body["messages"]   = msgs;
    body["max_tokens"] = 2048;
    if (isGroq) {
        body["temperature"] = 0.85;
        body["top_p"]       = 0.9;
        if (model.contains("qwen"))
            body["reasoning_format"] = "hidden";
    }
    if (stream) body["stream"] = true;

    return QJsonDocument(body).toJson(QJsonDocument::Compact);
}

QByteArray AIService::buildGeminiBody(const QVariantList &messages, bool useGrounding) const
{
    QJsonArray contents;
    QString systemInstruction;

    for (const QVariant &v : messages) {
        QVariantMap m = v.toMap();
        QString role    = m.value("role").toString();
        QString content = m.value("content").toString();

        if (role == "system") {
            systemInstruction = content;
            continue;
        }

        QString geminiRole = (role == "assistant") ? "model" : "user";
        QJsonObject part;
        part["text"] = content;
        QJsonObject obj;
        obj["role"]  = geminiRole;
        obj["parts"] = QJsonArray{ part };
        contents.append(obj);
    }

    QJsonObject body;
    if (!systemInstruction.isEmpty()) {
        QJsonObject si;
        si["parts"] = QJsonArray{ QJsonObject{ {"text", systemInstruction} } };
        body["system_instruction"] = si;
    }
    body["contents"] = contents;
    QJsonObject genConf;
    genConf["maxOutputTokens"] = 2048;
    body["generationConfig"] = genConf;
    if (useGrounding) {
        QJsonObject googleSearch;
        body["tools"] = QJsonArray{ QJsonObject{ {"googleSearch", googleSearch} } };
    }
    return QJsonDocument(body).toJson(QJsonDocument::Compact);
}

QByteArray AIService::buildClaudeBody(const QVariantList &messages, const QString &model) const
{
    QString systemText;
    QJsonArray msgs;

    for (const QVariant &v : messages) {
        QVariantMap m = v.toMap();
        QString role    = m.value("role").toString();
        QString content = m.value("content").toString();
        if (role == "system") { systemText = content; continue; }
        QJsonObject obj;
        obj["role"]    = role;
        obj["content"] = content;
        msgs.append(obj);
    }

    QJsonObject body;
    body["model"]      = model;
    body["max_tokens"] = 2048;
    if (!systemText.isEmpty()) body["system"] = systemText;
    body["messages"] = msgs;
    return QJsonDocument(body).toJson(QJsonDocument::Compact);
}

// ─────────────────────────────────────────────────────
// Response Parsers
// ─────────────────────────────────────────────────────
QString AIService::extractOpenAIResponse(const QByteArray &json) const
{
    QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject()) return "[Parse Error]";
    QJsonArray choices = doc.object()["choices"].toArray();
    if (choices.isEmpty()) return "[Parse Error]";
    return choices[0].toObject()["message"].toObject()["content"].toString();
}

QString AIService::extractGeminiResponse(const QByteArray &json) const
{
    QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject()) return "[Parse Error]";
    QJsonArray cands = doc.object()["candidates"].toArray();
    if (cands.isEmpty()) return "[Parse Error]";
    QJsonArray parts = cands[0].toObject()["content"].toObject()["parts"].toArray();
    if (parts.isEmpty()) return "[Parse Error]";
    return parts[0].toObject()["text"].toString();
}

QString AIService::extractClaudeResponse(const QByteArray &json) const
{
    QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject()) return "[Parse Error]";
    QJsonArray content = doc.object()["content"].toArray();
    if (content.isEmpty()) return "[Parse Error]";
    return content[0].toObject()["text"].toString();
}

QString AIService::extractStreamToken(const QByteArray &chunk) const
{
    QJsonDocument doc = QJsonDocument::fromJson(chunk);
    if (!doc.isObject()) return {};
    QJsonArray choices = doc.object()["choices"].toArray();
    if (choices.isEmpty()) return {};
    return choices[0].toObject()["delta"].toObject()["content"].toString();
}

// ─────────────────────────────────────────────────────
// SSE processing helper
// ─────────────────────────────────────────────────────
void AIService::processSSEData(const QByteArray &data, QByteArray &/*buf*/,
                               QString &fullResponse, bool &done)
{
    QList<QByteArray> lines = data.split('\n');
    for (const QByteArray &line : lines) {
        if (!line.startsWith("data: ")) continue;
        QByteArray payload = line.mid(6).trimmed();
        if (payload == "[DONE]") { done = true; continue; }
        QString tok = extractStreamToken(payload);
        if (!tok.isEmpty()) {
            fullResponse += tok;
            emit streamToken(tok);
        }
    }
}

// ─────────────────────────────────────────────────────
// sendChat  (non-streaming)
// ─────────────────────────────────────────────────────
void AIService::sendChat(const QVariantList &messages)
{
    QMutexLocker locker(&m_settingsMutex);
    int provider = m_settings.value("Config_ApiProvider", 0).toInt();
    QString apiKey = getApiKey(provider);
    QString model  = getModel(provider);
    bool webSearch = isWebSearchEnabled();

    // Vertex uses gcloud token, handled separately
    if (apiKey.isEmpty() && provider != PROVIDER_VERTEX) {
        emit errorOccurred("API Key が設定されていません。CONFIGから設定してください。");
        return;
    }

    QString customUrl = m_settings.value(QString("Config_CustomEndpoint_%1").arg(provider), "").toString().trimmed();
    if (customUrl.isEmpty()) {
        customUrl = m_settings.value("Config_CustomEndpoint", "").toString().trimmed();
    }

    QNetworkRequest req;
    QByteArray body;

    switch (provider) {
    case PROVIDER_OPENAI: {
        if (model.isEmpty()) model = "gpt-4o";
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://api.openai.com/v1/chat/completions" : customUrl));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model);
        break;
    }
    case PROVIDER_GEMINI: {
        if (model.isEmpty() || model.startsWith("gpt")) model = "gemini-2.0-flash";
        QString baseUrl = customUrl.isEmpty()
            ? "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent"
            : customUrl;
        req.setUrl(QUrl(baseUrl + "?key=" + apiKey));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildGeminiBody(messages);
        break;
    }
    case PROVIDER_CLAUDE: {
        if (model.isEmpty() || model.startsWith("gpt") || model.startsWith("gemini"))
            model = "claude-3-7-sonnet-20250219";
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://api.anthropic.com/v1/messages" : customUrl));
        req.setRawHeader("x-api-key", apiKey.toUtf8());
        req.setRawHeader("anthropic-version", "2023-06-01");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildClaudeBody(messages, model);
        break;
    }
    case PROVIDER_GROQ: {
        if (model.isEmpty() || !isValidGroqModel(model, true)) {
            model = "qwen3-32b";
        }
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://api.groq.com/openai/v1/chat/completions" : customUrl));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        if (webSearch) {
            body = buildGroqCompoundBody(messages, false);
        } else {
            body = buildOpenAIBody(messages, model, false, true);
        }
        break;
    }
    case PROVIDER_OLLAMA: {
        if (model.isEmpty()) model = "llama3";
        QString ollamaHost = m_settings.value("Config_OllamaHost", "http://localhost:11434").toString().trimmed();
        if (ollamaHost.isEmpty()) ollamaHost = "http://localhost:11434";
        QString host = customUrl.isEmpty() ? ollamaHost + "/v1/chat/completions" : customUrl;
        req.setUrl(QUrl(host));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model);
        break;
    }
    case PROVIDER_OPENROUTER: {
        if (model.isEmpty()) model = "openai/gpt-4o";
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://openrouter.ai/api/v1/chat/completions" : customUrl));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model);
        break;
    }
    case PROVIDER_VERTEX: {
        // Vertex: mirror Unity flow (gcloud token with cache and path probing).
        // Token acquisition is done asynchronously to avoid UI freezing.
        QString projectId = m_settings.value("Config_VertexProject", "").toString();
        QString location  = m_settings.value("Config_VertexLocation", "us-central1").toString();
        const QString lowerModel = model.toLower();
        QString vertexModel = model;
        if (vertexModel.isEmpty() || lowerModel.startsWith("gpt")) {
            vertexModel = "gemini-2.0-flash";
        }

        if (projectId.trimmed().isEmpty()) {
            emit errorOccurred("Vertex AI: Project ID が未設定です。Config_VertexProject を設定してください。");
            return;
        }

        // Acquire token asynchronously in background thread
        const QByteArray vertexBody = buildGeminiBody(messages, webSearch);
        auto tokenFuture = QtConcurrent::run([this]() { return getVertexAccessToken(); });

        // Setup async handler when token is ready
        auto watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, projectId, vertexModel, location, vertexBody]() {
            QString token = watcher->result();
            watcher->deleteLater();

            if (token.isEmpty()) {
                // Fallback to manual key in Config when gcloud retrieval fails
                token = getApiKey(PROVIDER_VERTEX);
            }
            if (token.isEmpty()) {
                emit errorOccurred("Vertex AI: アクセストークンの取得に失敗しました。\n"
                                   "gcloud CLI がインストールされ、gcloud auth login 済みか確認してください。");
                return;
            }

            // Now execute the Vertex API call with obtained token
            const QStringList targetRegions = getVertexTargetRegions(location);
            auto regionIndex = std::make_shared<int>(0);
            auto errors = std::make_shared<QStringList>();
            auto attempt = std::make_shared<std::function<void()>>();
            std::weak_ptr<std::function<void()>> weakAttempt = attempt;

            *attempt = [this, projectId, vertexModel, token, targetRegions, vertexBody, regionIndex, errors, weakAttempt]() {
                if (*regionIndex >= targetRegions.size()) {
                    emit errorOccurred(QString("Vertex AI: All regions failed (%1). Errors: %2")
                                           .arg(targetRegions.join(", "), errors->join("; ")));
                    return;
                }

                const QString currentRegion = targetRegions.at(*regionIndex);
                QNetworkRequest vertexReq;
                vertexReq.setUrl(QUrl(buildVertexUrl(projectId, currentRegion, vertexModel, "generateContent")));
                vertexReq.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
                vertexReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
                vertexReq.setTransferTimeout(60000);

                QNetworkReply *vertexReply = m_nam.post(vertexReq, vertexBody);
                connect(vertexReply, &QNetworkReply::finished, this,
                        [this, vertexReply, currentRegion, targetRegions, regionIndex, errors, weakAttempt]() {
                    const int statusCode = vertexReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                    const QByteArray responseBody = vertexReply->readAll();
                    const QNetworkReply::NetworkError netError = vertexReply->error();
                    const QString netErrorText = vertexReply->errorString();
                    vertexReply->deleteLater();

                    if (netError == QNetworkReply::NoError) {
                        emit responseReceived(extractGeminiResponse(responseBody));
                        return;
                    }

                    if (isVertexRetryableStatus(statusCode)) {
                        errors->append(QString("%1: %2").arg(currentRegion).arg(statusCode));
                        ++(*regionIndex);

                        const int jitterMs = QRandomGenerator::global()->bounded(100, 401);
                        QTimer::singleShot(jitterMs, this, [weakAttempt]() {
                            if (auto sharedAttempt = weakAttempt.lock()) {
                                (*sharedAttempt)();
                            }
                        });
                        return;
                    }

                    emit httpErrorOccurred(statusCode, netErrorText);
                    emit errorOccurred(QString("Vertex AI Error (%1): %2\n%3")
                                           .arg(currentRegion, netErrorText, QString::fromUtf8(responseBody)));
                });
            };


            (*attempt)();
        });
        watcher->setFuture(tokenFuture);
        return;
    }
    default:
        emit errorOccurred("Unknown provider.");
        return;
    }

    req.setTransferTimeout(60000);
    QNetworkReply *reply = m_nam.post(req, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, provider]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (statusCode > 0)
                emit httpErrorOccurred(statusCode, reply->errorString());
            emit errorOccurred(reply->errorString() + "\n" + reply->readAll());
            return;
        }
        QByteArray data = reply->readAll();
        QString response;
        switch (provider) {
        case PROVIDER_OPENAI:
        case PROVIDER_GROQ:
        case PROVIDER_OLLAMA:
        case PROVIDER_OPENROUTER: response = extractOpenAIResponse(data); break;
        case PROVIDER_GEMINI:
        case PROVIDER_VERTEX:  response = extractGeminiResponse(data); break;
        case PROVIDER_CLAUDE:  response = extractClaudeResponse(data); break;
        }
        emit responseReceived(response);
    });
}

// ─────────────────────────────────────────────────────
// sendChatStreaming (SSE — Groq / Vertex)
// ─────────────────────────────────────────────────────
void AIService::sendChatStreaming(const QVariantList &messages)
{
    QMutexLocker locker(&m_settingsMutex);
    int provider = m_settings.value("Config_ApiProvider", 0).toInt();
    QString apiKey = getApiKey(provider);
    QString model  = getModel(provider);
    bool webSearch = isWebSearchEnabled();

    QString customUrl = m_settings.value(QString("Config_CustomEndpoint_%1").arg(provider), "").toString().trimmed();
    if (customUrl.isEmpty()) {
        customUrl = m_settings.value("Config_CustomEndpoint", "").toString().trimmed();
    }

    // Non-streaming providers: fallback to sendChat
    if (provider != PROVIDER_GROQ && provider != PROVIDER_VERTEX && provider != PROVIDER_OLLAMA && provider != PROVIDER_OPENROUTER) {
        sendChat(messages);
        return;
    }

    if (apiKey.isEmpty() && provider != PROVIDER_VERTEX) {
        emit errorOccurred("API Key が設定されていません。CONFIGから設定してください。");
        return;
    }

    QNetworkRequest req;
    QByteArray body;

    if (provider == PROVIDER_GROQ) {
        if (model.isEmpty() || !isValidGroqModel(model, false)) {
            model = "qwen3-32b";
        }
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://api.groq.com/openai/v1/chat/completions" : customUrl));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("Accept", "text/event-stream");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        if (webSearch) {
            body = buildGroqCompoundBody(messages, true);
        } else {
            body = buildOpenAIBody(messages, model, true, true);
        }
    } else if (provider == PROVIDER_OLLAMA) {
        if (model.isEmpty()) model = "llama3";
        QString ollamaHost = m_settings.value("Config_OllamaHost", "http://localhost:11434").toString().trimmed();
        if (ollamaHost.isEmpty()) ollamaHost = "http://localhost:11434";
        QString host = customUrl.isEmpty() ? ollamaHost + "/v1/chat/completions" : customUrl;
        req.setUrl(QUrl(host));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("Accept", "text/event-stream");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model, true, false);
    } else if (provider == PROVIDER_OPENROUTER) {
        if (model.isEmpty()) model = "openai/gpt-4o";
        req.setUrl(QUrl(customUrl.isEmpty() ? "https://openrouter.ai/api/v1/chat/completions" : customUrl));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("Accept", "text/event-stream");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model, true, false);
    } else {
        // Vertex streaming - acquire token asynchronously to avoid UI freezing
        QString projectId = m_settings.value("Config_VertexProject", "").toString();
        if (projectId.trimmed().isEmpty()) {
            emit errorOccurred("Vertex AI: Project ID が未設定です。Config_VertexProject を設定してください。");
            return;
        }
        
        QString location = m_settings.value("Config_VertexLocation", "us-central1").toString();
        const QString lowerModel = model.toLower();
        QString vertexModel = model;
        if (vertexModel.isEmpty() || lowerModel.startsWith("gpt")) {
            vertexModel = "gemini-2.0-flash";
        }

        // Build request body before token acquisition
        const QByteArray vertexBody = buildGeminiBody(messages, webSearch);

        // Get token asynchronously in background thread
        auto tokenFuture = QtConcurrent::run([this]() { return getVertexAccessToken(); });

        // Setup async handler when token is ready
        auto watcher = new QFutureWatcher<QString>(this);
        connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, projectId, vertexModel, location, vertexBody]() {
            QString token = watcher->result();
            watcher->deleteLater();

            if (token.isEmpty()) {
                token = getApiKey(PROVIDER_VERTEX);
            }
            if (token.isEmpty()) {
                emit errorOccurred("Vertex AI: アクセストークンの取得に失敗しました。\n"
                                   "gcloud CLI がインストールされ、gcloud auth login 済みか確認してください。");
                return;
            }

            // Now execute the Vertex streaming API call with obtained token
            const QStringList targetRegions = getVertexTargetRegions(location);
            auto regionIndex = std::make_shared<int>(0);
            auto errors = std::make_shared<QStringList>();
            auto attempt = std::make_shared<std::function<void()>>();
            std::weak_ptr<std::function<void()>> weakAttempt = attempt;

            *attempt = [this, projectId, vertexModel, token, targetRegions, vertexBody, regionIndex, errors, weakAttempt]() {
                if (*regionIndex >= targetRegions.size()) {
                    emit errorOccurred(QString("Vertex AI Stream: All regions failed (%1). Errors: %2")
                                           .arg(targetRegions.join(", "), errors->join("; ")));
                    return;
                }

                const QString currentRegion = targetRegions.at(*regionIndex);
                QNetworkRequest vertexReq;
                vertexReq.setUrl(QUrl(buildVertexUrl(projectId, currentRegion, vertexModel, "streamGenerateContent")));
                vertexReq.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
                vertexReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
                vertexReq.setTransferTimeout(120000);

                QNetworkReply *vertexReply = m_nam.post(vertexReq, vertexBody);
                auto fullResponse = std::make_shared<QString>();
                auto rawBuffer = std::make_shared<QByteArray>();
                auto lastProcessedIndex = std::make_shared<int>(0);
                auto gotTokens = std::make_shared<bool>(false);

                connect(vertexReply, &QNetworkReply::readyRead, this,
                        [this, vertexReply, fullResponse, rawBuffer, lastProcessedIndex, gotTokens]() {
                    *rawBuffer += vertexReply->readAll();

                    if (rawBuffer->size() <= *lastProcessedIndex) {
                        return;
                    }

                    const QByteArray newData = rawBuffer->mid(*lastProcessedIndex);
                    *lastProcessedIndex = rawBuffer->size();
                    *gotTokens = true;

                    const QStringList tokens = extractVertexStreamTokensLikeUnity(newData);
                    for (const QString &tok : tokens) {
                        if (!tok.isEmpty()) {
                            *fullResponse += tok;
                            emit streamToken(tok);
                        }
                    }
                });

                connect(vertexReply, &QNetworkReply::finished, this,
                        [this, vertexReply, currentRegion, regionIndex, errors, weakAttempt, fullResponse, rawBuffer, lastProcessedIndex, gotTokens]() {
                    *rawBuffer += vertexReply->readAll();

                    if (rawBuffer->size() > *lastProcessedIndex) {
                        const QByteArray remaining = rawBuffer->mid(*lastProcessedIndex);
                        *lastProcessedIndex = rawBuffer->size();
                        *gotTokens = true;

                        const QStringList tokens = extractVertexStreamTokensLikeUnity(remaining);
                        for (const QString &tok : tokens) {
                            if (!tok.isEmpty()) {
                                *fullResponse += tok;
                                emit streamToken(tok);
                            }
                        }
                    }

                    const int statusCode = vertexReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                    const QByteArray responseBody = *rawBuffer;
                    const QNetworkReply::NetworkError netError = vertexReply->error();
                    const QString netErrorText = vertexReply->errorString();
                    vertexReply->deleteLater();

                    if (netError == QNetworkReply::NoError) {
                        emit streamComplete(*fullResponse);
                        return;
                    }

                    if (*gotTokens) {
                        emit streamComplete(*fullResponse);
                        emit errorOccurred(QString("Vertex AI Stream Interrupted (%1): %2")
                                               .arg(currentRegion, netErrorText));
                        return;
                    }

                    if (isVertexRetryableStatus(statusCode)) {
                        errors->append(QString("%1: %2").arg(currentRegion).arg(statusCode));
                        ++(*regionIndex);

                        const int jitterMs = QRandomGenerator::global()->bounded(100, 401);
                        QTimer::singleShot(jitterMs, this, [weakAttempt]() {
                            if (auto sharedAttempt = weakAttempt.lock()) {
                                (*sharedAttempt)();
                            }
                        });
                        return;
                    }

                    emit streamComplete(*fullResponse);
                    emit httpErrorOccurred(statusCode, netErrorText);
                    emit errorOccurred(QString("Vertex AI Stream Error (%1): %2\n%3")
                                           .arg(currentRegion, netErrorText, QString::fromUtf8(responseBody)));
                });
            };


            (*attempt)();
        });
        watcher->setFuture(tokenFuture);
        return;
    }

    req.setTransferTimeout(120000);
    QNetworkReply *reply = m_nam.post(req, body);

    // We accumulate SSE data as it arrives
    auto fullResponse = std::make_shared<QString>();
    auto sseBuffer    = std::make_shared<QByteArray>();
    auto isDone       = std::make_shared<bool>(false);

    connect(reply, &QNetworkReply::readyRead, this, [this, reply, fullResponse, sseBuffer, isDone, provider]() {
        QByteArray chunk = reply->readAll();
        *sseBuffer += chunk;

        // Process complete lines
        while (true) {
            int idx = sseBuffer->indexOf('\n');
            if (idx < 0) break;
            QByteArray line = sseBuffer->left(idx).trimmed();

            if (line.isEmpty()) {
                *sseBuffer = sseBuffer->mid(idx + 1);
                continue;
            }
            if (!line.startsWith("data: ")) {
                *sseBuffer = sseBuffer->mid(idx + 1);
                continue;
            }

            QByteArray payload = line.mid(6).trimmed();
            if (payload == "[DONE]") {
                *isDone = true;
                *sseBuffer = sseBuffer->mid(idx + 1);
                continue;
            }

            // Check if JSON payload is complete and parseable
            QJsonParseError parseError;
            QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);
            if (doc.isNull() && parseError.error != QJsonParseError::NoError) {
                // Incomplete JSON chunk, leave it in buffer and wait for next readyRead
                break;
            }

            // Safe to consume this line from the buffer
            *sseBuffer = sseBuffer->mid(idx + 1);

            QString tok;
            if (provider == PROVIDER_GROQ || provider == PROVIDER_OLLAMA || provider == PROVIDER_OPENROUTER) {
                QJsonArray choices = doc.object()["choices"].toArray();
                if (!choices.isEmpty()) {
                    tok = choices[0].toObject()["delta"].toObject()["content"].toString();
                }
            } else {
                // Vertex Gemini streaming format
                QJsonArray cands = doc.object()["candidates"].toArray();
                if (!cands.isEmpty()) {
                    QJsonArray parts = cands[0].toObject()["content"].toObject()["parts"].toArray();
                    if (!parts.isEmpty())
                        tok = parts[0].toObject()["text"].toString();
                }
            }
            if (!tok.isEmpty()) {
                *fullResponse += tok;
                emit streamToken(tok);
            }
        }
    });


    connect(reply, &QNetworkReply::finished, this, [this, reply, fullResponse, sseBuffer, isDone, provider]() {
        reply->deleteLater();
        // process remaining buffer
        if (!sseBuffer->isEmpty()) {
            QList<QByteArray> lines = sseBuffer->split('\n');
            for (const QByteArray &line : lines) {
                if (!line.startsWith("data: ")) continue;
                QByteArray payload = line.mid(6).trimmed();
                if (payload == "[DONE]") continue;
                QString tok;
                if (provider == PROVIDER_GROQ || provider == PROVIDER_OLLAMA || provider == PROVIDER_OPENROUTER) {
                    tok = extractStreamToken(payload);
                } else {
                    QJsonDocument doc = QJsonDocument::fromJson(payload);
                    if (doc.isObject()) {
                        QJsonArray cands = doc.object()["candidates"].toArray();
                        if (!cands.isEmpty()) {
                            QJsonArray parts = cands[0].toObject()["content"].toObject()["parts"].toArray();
                            if (!parts.isEmpty()) {
                                tok = parts[0].toObject()["text"].toString();
                            }
                        }
                    }
                }
                if (!tok.isEmpty()) { *fullResponse += tok; emit streamToken(tok); }
            }
        }

        if (reply->error() != QNetworkReply::NoError) {
            emit streamComplete(*fullResponse);
            emit errorOccurred(reply->errorString());
            return;
        }
        emit streamComplete(*fullResponse);
    });
}
