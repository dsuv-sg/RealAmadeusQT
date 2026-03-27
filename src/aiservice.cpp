#include "aiservice.h"
#include "appsettings.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>
#include <QDebug>
#include <QProcess>

// ─────────────────────────────────────────────────────
// Constructor
// ─────────────────────────────────────────────────────
AIService::AIService(QObject *parent)
    : QObject(parent)
{}

bool AIService::isWebSearchEnabled() const
{
    QSettings s("RealAmadeus", "AmadeusSystem");
    return s.value("Config_WebSearch", 0).toInt() == 1;
}

// ─────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────
QString AIService::getApiKey(int provider) const
{
    QSettings s("RealAmadeus", "AmadeusSystem");
    QString key = s.value(QString("Config_ApiKey_%1").arg(provider), "").toString();
    if (key.isEmpty())
        key = s.value("Config_ApiKey", "").toString();
    return key;
}

QString AIService::getModel(int provider) const
{
    QSettings s("RealAmadeus", "AmadeusSystem");
    QString model = s.value(QString("Config_ModelName_%1").arg(provider), "").toString();
    if (model.isEmpty())
        model = s.value("Config_ModelName", "").toString();
    return model;
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
    QSettings s("RealAmadeus", "AmadeusSystem");
    int provider = s.value("Config_ApiProvider", 0).toInt();
    QString apiKey = getApiKey(provider);
    QString model  = getModel(provider);
    bool webSearch = isWebSearchEnabled();

    // Vertex uses gcloud token, handled separately
    if (apiKey.isEmpty() && provider != PROVIDER_VERTEX) {
        emit errorOccurred("API Key が設定されていません。CONFIGから設定してください。");
        return;
    }

    QNetworkRequest req;
    QByteArray body;

    switch (provider) {
    case PROVIDER_OPENAI: {
        if (model.isEmpty()) model = "gpt-4o";
        req.setUrl(QUrl("https://api.openai.com/v1/chat/completions"));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, model);
        break;
    }
    case PROVIDER_GEMINI: {
        if (model.isEmpty() || model.startsWith("gpt")) model = "gemini-2.0-flash";
        QString url = "https://generativelanguage.googleapis.com/v1beta/models/"
                      + model + ":generateContent?key=" + apiKey;
        req.setUrl(QUrl(url));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildGeminiBody(messages);
        break;
    }
    case PROVIDER_CLAUDE: {
        if (model.isEmpty() || model.startsWith("gpt") || model.startsWith("gemini"))
            model = "claude-3-7-sonnet-20250219";
        req.setUrl(QUrl("https://api.anthropic.com/v1/messages"));
        req.setRawHeader("x-api-key", apiKey.toUtf8());
        req.setRawHeader("anthropic-version", "2023-06-01");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildClaudeBody(messages, model);
        break;
    }
    case PROVIDER_GROQ: {
        if (model.isEmpty()) model = "qwen3-32b";
        QString groqModel = (webSearch) ? "groq/compound" : model;
        req.setUrl(QUrl("https://api.groq.com/openai/v1/chat/completions"));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, groqModel, false, true);
        break;
    }
    case PROVIDER_VERTEX: {
        // Vertex: run gcloud to get token synchronously, then POST
        QString projectId = s.value("Config_VertexProject", "").toString();
        QString location  = s.value("Config_VertexLocation", "us-central1").toString();
        if (model.isEmpty()) model = "gemini-2.0-flash-001";

        QProcess proc;
        proc.start("gcloud", {"auth", "print-access-token"});
        proc.waitForFinished(10000);
        QString token = proc.readAllStandardOutput().trimmed();
        if (token.isEmpty()) {
            emit errorOccurred("Vertex AI: gcloudトークン取得失敗。gcloud auth loginしてください。");
            return;
        }

        QString url = QString("https://%1-aiplatform.googleapis.com/v1/projects/%2"
                              "/locations/%3/publishers/google/models/%4:generateContent")
                          .arg(location, projectId, location, model);
        req.setUrl(QUrl(url));
        req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildGeminiBody(messages); // Vertex uses same format as Gemini
        break;
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
            emit errorOccurred(reply->errorString() + "\n" + reply->readAll());
            return;
        }
        QByteArray data = reply->readAll();
        QString response;
        switch (provider) {
        case PROVIDER_OPENAI:
        case PROVIDER_GROQ:    response = extractOpenAIResponse(data); break;
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
    QSettings s("RealAmadeus", "AmadeusSystem");
    int provider = s.value("Config_ApiProvider", 0).toInt();
    QString apiKey = getApiKey(provider);
    QString model  = getModel(provider);
    bool webSearch = isWebSearchEnabled();

    // Non-streaming providers: fallback to sendChat
    if (provider != PROVIDER_GROQ && provider != PROVIDER_VERTEX) {
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
        if (model.isEmpty()) model = "qwen3-32b";
        QString groqModel = webSearch ? "groq/compound" : model;
        req.setUrl(QUrl("https://api.groq.com/openai/v1/chat/completions"));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("Accept", "text/event-stream");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildOpenAIBody(messages, groqModel, true, true);
    } else {
        // Vertex streaming
        QProcess proc;
        proc.start("gcloud", {"auth", "print-access-token"});
        proc.waitForFinished(10000);
        QString token = proc.readAllStandardOutput().trimmed();
        if (token.isEmpty()) {
            emit errorOccurred("Vertex AI: gcloudトークン取得失敗。");
            return;
        }
        if (model.isEmpty()) model = "gemini-2.0-flash-001";
        QString location  = s.value("Config_VertexLocation", "us-central1").toString();
        QString projectId = s.value("Config_VertexProject", "").toString();
        QString url = QString("https://%1-aiplatform.googleapis.com/v1/projects/%2"
                              "/locations/%3/publishers/google/models/%4:streamGenerateContent?alt=sse")
                          .arg(location, projectId, location, model);
        req.setUrl(QUrl(url));
        req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
        req.setRawHeader("Accept", "text/event-stream");
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        body = buildGeminiBody(messages);
    }

    req.setTransferTimeout(120000);
    QNetworkReply *reply = m_nam.post(req, body);

    // We accumulate SSE data as it arrives
    auto *fullResponse = new QString();
    auto *sseBuffer    = new QByteArray();
    bool *isDone       = new bool(false);

    connect(reply, &QNetworkReply::readyRead, this, [this, reply, fullResponse, sseBuffer, isDone, provider]() {
        QByteArray chunk = reply->readAll();
        *sseBuffer += chunk;

        // Process complete lines
        while (true) {
            int idx = sseBuffer->indexOf('\n');
            if (idx < 0) break;
            QByteArray line = sseBuffer->left(idx + 1);
            *sseBuffer = sseBuffer->mid(idx + 1);

            if (!line.startsWith("data: ")) continue;
            QByteArray payload = line.mid(6).trimmed();
            if (payload == "[DONE]") { *isDone = true; continue; }

            QString tok;
            if (provider == PROVIDER_GROQ)
                tok = extractStreamToken(payload);
            else {
                // Vertex Gemini streaming format
                QJsonDocument doc = QJsonDocument::fromJson(payload);
                if (doc.isObject()) {
                    QJsonArray cands = doc.object()["candidates"].toArray();
                    if (!cands.isEmpty()) {
                        QJsonArray parts = cands[0].toObject()["content"].toObject()["parts"].toArray();
                        if (!parts.isEmpty())
                            tok = parts[0].toObject()["text"].toString();
                    }
                }
            }
            if (!tok.isEmpty()) {
                *fullResponse += tok;
                emit streamToken(tok);
            }
        }
    });

    connect(reply, &QNetworkReply::finished, this, [this, reply, fullResponse, sseBuffer, isDone]() {
        reply->deleteLater();
        // process remaining buffer
        if (!sseBuffer->isEmpty()) {
            QList<QByteArray> lines = sseBuffer->split('\n');
            for (const QByteArray &line : lines) {
                if (!line.startsWith("data: ")) continue;
                QByteArray payload = line.mid(6).trimmed();
                if (payload == "[DONE]") continue;
                QString tok = extractStreamToken(payload);
                if (!tok.isEmpty()) { *fullResponse += tok; emit streamToken(tok); }
            }
        }
        delete sseBuffer;
        delete isDone;

        if (reply->error() != QNetworkReply::NoError) {
            delete fullResponse;
            emit errorOccurred(reply->errorString());
            return;
        }
        emit streamComplete(*fullResponse);
        delete fullResponse;
    });
}
