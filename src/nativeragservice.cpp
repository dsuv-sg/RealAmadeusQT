#include "nativeragservice.h"
#include <QSettings>
#include <QDateTime>
#include <QRandomGenerator>
#include <QDebug>
#include <cmath>

NativeRAGService::NativeRAGService(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_enabled = settings.value("Config_NativeRAG_Enabled", false).toBool();
    m_topK = settings.value("Config_NativeRAG_TopK", 5).toInt();
    m_threshold = settings.value("Config_NativeRAG_Threshold", 0.3).toDouble();
}

bool NativeRAGService::isEnabled() const
{
    return m_enabled;
}

void NativeRAGService::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        QSettings().setValue("Config_NativeRAG_Enabled", enabled);
        emit enabledChanged();
    }
}

int NativeRAGService::topK() const
{
    return m_topK;
}

void NativeRAGService::setTopK(int k)
{
    if (m_topK != k) {
        m_topK = k;
        QSettings().setValue("Config_NativeRAG_TopK", k);
        emit topKChanged();
    }
}

qreal NativeRAGService::threshold() const
{
    return m_threshold;
}

void NativeRAGService::setThreshold(qreal thresh)
{
    if (!qFuzzyCompare(m_threshold, thresh)) {
        m_threshold = thresh;
        QSettings().setValue("Config_NativeRAG_Threshold", thresh);
        emit thresholdChanged();
    }
}

void NativeRAGService::addDocument(const QString &content, const QString &category,
                                    const QJsonObject &metadata)
{
    if (content.trimmed().isEmpty()) return;
    QString id = generateId();
    Document doc;
    doc.id = id;
    doc.content = content;
    doc.category = category;
    doc.metadata = metadata;
    m_documents[id] = doc;
    emit documentAdded(id);
}

void NativeRAGService::search(const QString &query)
{
    if (!m_enabled) {
        emit searchError("Native RAG is not enabled");
        return;
    }
    if (query.trimmed().isEmpty()) {
        emit searchComplete(QVariantList());
        return;
    }
    if (m_documents.isEmpty()) {
        emit searchComplete(QVariantList());
        return;
    }

    // Compute average document length
    qreal totalLen = 0;
    for (const auto &doc : m_documents) {
        totalLen += tokenize(doc.content).size();
    }
    qreal avgDocLen = totalLen / m_documents.size();

    // Compute document frequency for each term in query
    QStringList qTerms = tokenize(query);
    QMap<QString, int> docFreq;
    for (const QString &term : qTerms) {
        int df = 0;
        for (const auto &doc : m_documents) {
            if (tokenize(doc.content).contains(term)) df++;
        }
        docFreq[term] = df;
    }

    QVector<SearchResult> results;
    for (const auto &doc : m_documents) {
        qreal score = computeBM25Score(query, doc, avgDocLen, docFreq);
        if (score >= m_threshold) {
            SearchResult r;
            r.id = doc.id;
            r.content = doc.content;
            r.score = score;
            r.metadata = doc.metadata;
            results.append(r);
        }
    }

    std::sort(results.begin(), results.end(),
              [](const SearchResult &a, const SearchResult &b) { return a.score > b.score; });

    if (results.size() > m_topK) results.resize(m_topK);

    QVariantList list;
    for (const auto &r : results) {
        QVariantMap m;
        m["id"] = r.id;
        m["content"] = r.content;
        m["score"] = r.score;
        m["metadata"] = r.metadata.toVariantMap();
        list.append(m);
    }
    emit searchComplete(list);
}

void NativeRAGService::removeDocument(const QString &id)
{
    m_documents.remove(id);
}

void NativeRAGService::clearAll()
{
    m_documents.clear();
}

int NativeRAGService::documentCount() const
{
    return m_documents.size();
}

QString NativeRAGService::getContextForPrompt(const QVariantList &results) const
{
    QStringList parts;
    for (const auto &v : results) {
        QVariantMap m = v.toMap();
        QString content = m.value("content").toString();
        if (!content.isEmpty()) parts.append(content);
    }
    if (parts.isEmpty()) return QString();
    return "Relevant context:\n" + parts.join("\n---\n");
}

QString NativeRAGService::generateId() const
{
    return QString::number(QDateTime::currentMSecsSinceEpoch()) + "_" + QString::number(QRandomGenerator::global()->bounded(100000));
}

QStringList NativeRAGService::tokenize(const QString &text) const
{
    QStringList tokens;
    QString lower = text.toLower();
    // Simple CJK / word tokenization
    QString current;
    for (const QChar &c : lower) {
        if (c.isLetterOrNumber() || c.unicode() >= 0x4E00) {
            current.append(c);
        } else {
            if (!current.isEmpty()) {
                tokens.append(current);
                current.clear();
            }
        }
    }
    if (!current.isEmpty()) tokens.append(current);
    return tokens;
}

QMap<QString, int> NativeRAGService::termFrequency(const QString &text) const
{
    QMap<QString, int> freq;
    for (const QString &t : tokenize(text)) freq[t]++;
    return freq;
}

qreal NativeRAGService::computeBM25Score(const QString &query, const Document &doc,
                                          qreal avgDocLen, const QMap<QString, int> &docFreq) const
{
    QStringList qTerms = tokenize(query);
    QMap<QString, int> tf = termFrequency(doc.content);
    int docLen = tokenize(doc.content).size();
    if (docLen == 0) return 0.0;

    qreal score = 0.0;
    int N = m_documents.size();
    for (const QString &term : qTerms) {
        int f = tf.value(term, 0);
        if (f == 0) continue;
        int df = docFreq.value(term, 1);
        qreal idf = std::log((N - df + 0.5) / (df + 0.5) + 1.0);
        qreal numerator = f * (K1 + 1.0);
        qreal denominator = f + K1 * (1.0 - B + B * (docLen / avgDocLen));
        score += idf * (numerator / denominator);
    }
    return score;
}