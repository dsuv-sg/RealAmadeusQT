#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

/// AIService - mirrors Unity AIService.cs
/// Supports OpenAI / Gemini / Claude / Groq (+ Groq Compound) / Vertex AI
/// Emits per-token signals for streaming providers.
class AIService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool webSearchEnabled READ isWebSearchEnabled CONSTANT)
public:
    explicit AIService(QObject *parent = nullptr);

    bool isWebSearchEnabled() const;

    /// Non-streaming chat. Emits responseReceived or errorOccurred.
    Q_INVOKABLE void sendChat(const QVariantList &messages);

    /// Streaming chat (Groq/Vertex). Emits streamToken, streamComplete, or errorOccurred.
    Q_INVOKABLE void sendChatStreaming(const QVariantList &messages);

signals:
    void responseReceived(const QString &response);
    void streamToken(const QString &token);
    void streamComplete(const QString &fullResponse);
    void errorOccurred(const QString &error);

private:
    // ─── Builders ───
    QByteArray buildOpenAIBody(const QVariantList &messages, const QString &model,
                               bool stream = false, bool isGroq = false) const;
    QByteArray buildGeminiBody(const QVariantList &messages, bool useGrounding = false) const;
    QByteArray buildClaudeBody(const QVariantList &messages, const QString &model) const;
    QByteArray buildVertexBody(const QVariantList &messages) const;

    // ─── Parsers ───
    QString extractOpenAIResponse(const QByteArray &json) const;
    QString extractGeminiResponse(const QByteArray &json) const;
    QString extractClaudeResponse(const QByteArray &json) const;
    QString extractStreamToken(const QByteArray &chunk) const;

    // ─── Helpers ───
    static QString escapeJson(const QString &s);
    QString getApiKey(int provider) const;
    QString getModel(int provider) const;

    // ─── SSE streaming processor ───
    void processSSEData(const QByteArray &data, QByteArray &buffer,
                        QString &fullResponse, bool &done);

    QNetworkAccessManager m_nam;
    QByteArray m_streamBuffer; // for streaming reply

    static constexpr int PROVIDER_OPENAI  = 0;
    static constexpr int PROVIDER_GEMINI  = 1;
    static constexpr int PROVIDER_CLAUDE  = 2;
    static constexpr int PROVIDER_GROQ    = 3;
    static constexpr int PROVIDER_VERTEX  = 4;
};
