#include "vectordatabase.h"
#include <QJsonDocument>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QUuid>
#include <QNetworkRequest>
#include <cmath>

VectorDatabase::VectorDatabase(QObject *parent)
    : QObject(parent)
{
    // Load settings
    m_enabled = m_settings.value("Config_Experimental_RAG_Enabled", false).toBool();
    m_serverUrl = m_settings.value("Config_Experimental_RAG_ServerUrl", "http://localhost:5102").toString();
    m_topK = m_settings.value("Config_Experimental_RAG_TopK", 5).toInt();
    m_threshold = m_settings.value("Config_Experimental_RAG_Threshold", 0.7).toDouble();
    
    // Load stored vectors
    load();
    
    if (m_enabled) {
        checkServerHealth();
    }
}

VectorDatabase::~VectorDatabase()
{
    save();
}

bool VectorDatabase::isEnabled() const
{
    return m_enabled;
}

void VectorDatabase::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_settings.setValue("Config_Experimental_RAG_Enabled", enabled);
        emit enabledChanged();
        
        if (enabled) {
            checkServerHealth();
        }
    }
}

QString VectorDatabase::serverUrl() const
{
    return m_serverUrl;
}

void VectorDatabase::setServerUrl(const QString &url)
{
    if (m_serverUrl != url) {
        m_serverUrl = url;
        m_settings.setValue("Config_Experimental_RAG_ServerUrl", url);
        emit serverUrlChanged();
        checkServerHealth();
    }
}

int VectorDatabase::topK() const
{
    return m_topK;
}

void VectorDatabase::setTopK(int k)
{
    k = qBound(1, k, 20);
    if (m_topK != k) {
        m_topK = k;
        m_settings.setValue("Config_Experimental_RAG_TopK", k);
        emit topKChanged();
    }
}

qreal VectorDatabase::threshold() const
{
    return m_threshold;
}

void VectorDatabase::setThreshold(qreal thresh)
{
    thresh = qBound(0.0, thresh, 1.0);
    if (!qFuzzyCompare(m_threshold, thresh)) {
        m_threshold = thresh;
        m_settings.setValue("Config_Experimental_RAG_Threshold", thresh);
        emit thresholdChanged();
    }
}

bool VectorDatabase::isServerAvailable() const
{
    return m_serverAvailable;
}

void VectorDatabase::addEntry(const QString &content, const QString &category,
                              const QJsonObject &metadata)
{
    if (!m_enabled || content.trimmed().isEmpty()) {
        return;
    }
    
    QString id = generateId();
    
    // Request embedding from server
    requestEmbedding(content, [this, id, content, category, metadata](const QVector<float> &embedding) {
        if (embedding.isEmpty()) {
            qWarning() << "[VectorDatabase] Failed to get embedding for content";
            return;
        }
        
        VectorEntry entry;
        entry.id = id;
        entry.content = content;
        entry.category = category;
        entry.embedding = embedding;
        entry.metadata = metadata;
        
        m_entries[id] = entry;
        save();
        
        emit entryAdded(id);
        qDebug() << "[VectorDatabase] Entry added:" << id;
    });
}

void VectorDatabase::search(const QString &query)
{
    if (!m_enabled || query.trimmed().isEmpty()) {
        emit searchComplete(QVariantList());
        return;
    }
    
    // Get embedding for query
    requestEmbedding(query, [this](const QVector<float> &queryEmbedding) {
        if (queryEmbedding.isEmpty()) {
            emit searchError("Failed to get query embedding");
            return;
        }
        
        // Calculate similarities
        QList<QPair<QString, qreal>> similarities;
        
        for (auto it = m_entries.constBegin(); it != m_entries.constEnd(); ++it) {
            qreal sim = cosineSimilarity(queryEmbedding, it.value().embedding);
            if (sim >= m_threshold) {
                similarities.append(qMakePair(it.key(), sim));
            }
        }
        
        // Sort by similarity (descending)
        std::sort(similarities.begin(), similarities.end(),
                  [](const auto &a, const auto &b) { return a.second > b.second; });
        
        // Take top K results
        QVariantList results;
        int count = qMin(m_topK, similarities.size());
        
        for (int i = 0; i < count; ++i) {
            const QString &id = similarities[i].first;
            const VectorEntry &entry = m_entries[id];
            
            QVariantMap result;
            result["id"] = id;
            result["content"] = entry.content;
            result["category"] = entry.category;
            result["similarity"] = similarities[i].second;
            result["metadata"] = entry.metadata.toVariantMap();
            
            results.append(result);
        }
        
        emit searchComplete(results);
    });
}

void VectorDatabase::removeEntry(const QString &id)
{
    if (m_entries.remove(id) > 0) {
        save();
        qDebug() << "[VectorDatabase] Entry removed:" << id;
    }
}

void VectorDatabase::clearAll()
{
    m_entries.clear();
    save();
    qDebug() << "[VectorDatabase] All entries cleared";
}

int VectorDatabase::entryCount() const
{
    return m_entries.size();
}

void VectorDatabase::checkServerHealth()
{
    QUrl url(m_serverUrl + "/health");
    QNetworkRequest request(url);
    request.setTransferTimeout(5000);
    
    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onHealthCheckFinished(reply);
    });
}

void VectorDatabase::save()
{
    QJsonArray entriesArray;
    
    for (auto it = m_entries.constBegin(); it != m_entries.constEnd(); ++it) {
        const VectorEntry &entry = it.value();
        
        QJsonObject obj;
        obj["id"] = entry.id;
        obj["content"] = entry.content;
        obj["category"] = entry.category;
        obj["metadata"] = entry.metadata;
        
        // Store embedding as array
        QJsonArray embeddingArray;
        for (float val : entry.embedding) {
            embeddingArray.append(static_cast<double>(val));
        }
        obj["embedding"] = embeddingArray;
        
        entriesArray.append(obj);
    }
    
    QJsonObject root;
    root["entries"] = entriesArray;
    root["version"] = 1;
    
    QString path = getStoragePath();
    QFile file(path);
    
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        file.close();
        qDebug() << "[VectorDatabase] Saved" << m_entries.size() << "entries";
    } else {
        qWarning() << "[VectorDatabase] Failed to save:" << path;
    }
}

void VectorDatabase::load()
{
    QString path = getStoragePath();
    QFile file(path);
    
    if (!file.exists()) {
        qDebug() << "[VectorDatabase] No stored data found";
        return;
    }
    
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[VectorDatabase] Failed to open:" << path;
        return;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        qWarning() << "[VectorDatabase] Invalid data format";
        return;
    }
    
    QJsonObject root = doc.object();
    QJsonArray entriesArray = root["entries"].toArray();
    
    m_entries.clear();
    
    for (const QJsonValue &val : entriesArray) {
        QJsonObject obj = val.toObject();
        
        VectorEntry entry;
        entry.id = obj["id"].toString();
        entry.content = obj["content"].toString();
        entry.category = obj["category"].toString();
        entry.metadata = obj["metadata"].toObject();
        
        QJsonArray embeddingArray = obj["embedding"].toArray();
        for (const QJsonValue &v : embeddingArray) {
            entry.embedding.append(static_cast<float>(v.toDouble()));
        }
        
        if (!entry.id.isEmpty() && !entry.embedding.isEmpty()) {
            m_entries[entry.id] = entry;
        }
    }
    
    qDebug() << "[VectorDatabase] Loaded" << m_entries.size() << "entries";
}

QString VectorDatabase::getContextForPrompt(const QList<SearchResult> &results) const
{
    if (results.isEmpty()) {
        return QString();
    }
    
    QString context = "【関連する過去の記憶】\n";
    
    for (const SearchResult &result : results) {
        context += QString("- %1 (類似度: %2%)\n")
                       .arg(result.content)
                       .arg(static_cast<int>(result.similarity * 100));
    }
    
    return context;
}

void VectorDatabase::requestEmbedding(const QString &text, 
                                      std::function<void(const QVector<float>&)> callback)
{
    QUrl url(m_serverUrl + "/embed");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    QJsonObject body;
    body["text"] = text;
    
    QNetworkReply *reply = m_nam.post(request, QJsonDocument(body).toJson());
    m_pendingCallbacks[reply] = callback;
    
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onEmbeddingReceived(reply);
    });
}

void VectorDatabase::onEmbeddingReceived(QNetworkReply *reply)
{
    reply->deleteLater();
    
    auto callback = m_pendingCallbacks.take(reply);
    
    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "[VectorDatabase] Embedding request failed:" << reply->errorString();
        if (callback) callback(QVector<float>());
        return;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject obj = doc.object();
    
    QVector<float> embedding;
    QJsonArray arr = obj["embedding"].toArray();
    
    for (const QJsonValue &val : arr) {
        embedding.append(static_cast<float>(val.toDouble()));
    }
    
    if (callback) {
        callback(embedding);
    }
}

void VectorDatabase::onSearchComplete(QNetworkReply *reply)
{
    // Not used - we do local search after getting embedding
    reply->deleteLater();
}

void VectorDatabase::onHealthCheckFinished(QNetworkReply *reply)
{
    reply->deleteLater();
    
    bool wasAvailable = m_serverAvailable;
    m_serverAvailable = (reply->error() == QNetworkReply::NoError);
    
    if (m_serverAvailable != wasAvailable) {
        emit serverAvailableChanged();
    }
    
    qDebug() << "[VectorDatabase] Server available:" << m_serverAvailable;
}

QString VectorDatabase::generateId() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

qreal VectorDatabase::cosineSimilarity(const QVector<float> &a, const QVector<float> &b) const
{
    if (a.size() != b.size() || a.isEmpty()) {
        return 0.0;
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.size(); ++i) {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    
    double denominator = std::sqrt(normA) * std::sqrt(normB);
    if (denominator < 1e-10) {
        return 0.0;
    }
    
    return dotProduct / denominator;
}

QString VectorDatabase::getStoragePath() const
{
    QString basePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(basePath);
    return basePath + "/vector_store.json";
}
