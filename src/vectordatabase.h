#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QJsonArray>
#include <QJsonObject>
#include <QVector>
#include <QString>
#include <QMap>
#include <QFile>
#include <QMutex>

/// VectorDatabase - RAG vector store for semantic memory search
/// Communicates with Python embedding server
class VectorDatabase : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(int topK READ topK WRITE setTopK NOTIFY topKChanged)
    Q_PROPERTY(qreal threshold READ threshold WRITE setThreshold NOTIFY thresholdChanged)
    Q_PROPERTY(bool serverAvailable READ isServerAvailable NOTIFY serverAvailableChanged)

public:
    struct VectorEntry {
        QString id;
        QString content;
        QString category;
        QVector<float> embedding;
        QJsonObject metadata;
    };
    
    struct SearchResult {
        QString id;
        QString content;
        qreal similarity;
        QJsonObject metadata;
    };

    explicit VectorDatabase(QObject *parent = nullptr);
    ~VectorDatabase();

    bool isEnabled() const;
    void setEnabled(bool enabled);
    
    QString serverUrl() const;
    void setServerUrl(const QString &url);
    
    int topK() const;
    void setTopK(int k);
    
    qreal threshold() const;
    void setThreshold(qreal thresh);
    
    bool isServerAvailable() const;

    /// Add a new entry to the vector database
    Q_INVOKABLE void addEntry(const QString &content, const QString &category = "general",
                               const QJsonObject &metadata = QJsonObject());
    
    /// Search for similar entries
    Q_INVOKABLE void search(const QString &query);
    
    /// Remove entry by ID
    Q_INVOKABLE void removeEntry(const QString &id);
    
    /// Clear all entries
    Q_INVOKABLE void clearAll();
    
    /// Get entry count
    Q_INVOKABLE int entryCount() const;
    
    /// Check server health
    Q_INVOKABLE void checkServerHealth();
    
    /// Save database to disk
    Q_INVOKABLE void save();
    
    /// Load database from disk
    Q_INVOKABLE void load();
    
    /// Get context string for AI prompt
    Q_INVOKABLE QString getContextForPrompt(const QList<SearchResult> &results) const;

signals:
    void entryAdded(const QString &id);
    void searchComplete(const QVariantList &results);
    void searchError(const QString &error);
    void enabledChanged();
    void serverUrlChanged();
    void topKChanged();
    void thresholdChanged();
    void serverAvailableChanged();

private slots:
    void onEmbeddingReceived(QNetworkReply *reply);
    void onSearchComplete(QNetworkReply *reply);
    void onHealthCheckFinished(QNetworkReply *reply);

private:
    QString generateId() const;
    qreal cosineSimilarity(const QVector<float> &a, const QVector<float> &b) const;
    QString getStoragePath() const;
    void requestEmbedding(const QString &text, std::function<void(const QVector<float>&)> callback);
    
    QNetworkAccessManager m_nam;
    QSettings m_settings;
    
    QMap<QString, VectorEntry> m_entries;
    QMap<QNetworkReply*, std::function<void(const QVector<float>&)>> m_pendingCallbacks;
    
    bool m_enabled = false;
    QString m_serverUrl = "http://localhost:5102";
    int m_topK = 5;
    qreal m_threshold = 0.7;
    bool m_serverAvailable = false;
    mutable QMutex m_mutex;
};
