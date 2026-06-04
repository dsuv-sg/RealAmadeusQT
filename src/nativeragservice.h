#pragma once
#include <QObject>
#include <QString>
#include <QVector>
#include <QMap>
#include <QJsonObject>

/// NativeRAGService - Pure C++ BM25 semantic memory (no external server)
class NativeRAGService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int topK READ topK WRITE setTopK NOTIFY topKChanged)
    Q_PROPERTY(qreal threshold READ threshold WRITE setThreshold NOTIFY thresholdChanged)

public:
    struct Document {
        QString id;
        QString content;
        QString category;
        QJsonObject metadata;
        QStringList tokens;
        QMap<QString, int> termFreqs;
    };

    struct SearchResult {
        QString id;
        QString content;
        qreal score;
        QJsonObject metadata;
    };

    explicit NativeRAGService(QObject *parent = nullptr);
    ~NativeRAGService();

    bool isEnabled() const;
    void setEnabled(bool enabled);

    int topK() const;
    void setTopK(int k);

    qreal threshold() const;
    void setThreshold(qreal thresh);

    Q_INVOKABLE void addDocument(const QString &content, const QString &category = "general",
                                  const QJsonObject &metadata = QJsonObject());
    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void removeDocument(const QString &id);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE int documentCount() const;
    Q_INVOKABLE QString getContextForPrompt(const QVariantList &results) const;

signals:
    void documentAdded(const QString &id);
    void searchComplete(const QVariantList &results);
    void searchError(const QString &error);
    void enabledChanged();
    void topKChanged();
    void thresholdChanged();

private:
    QString generateId() const;
    qreal computeBM25Score(const QStringList &qTerms, const Document &doc,
                           qreal avgDocLen, const QMap<QString, int> &docFreq) const;
    QMap<QString, int> termFrequency(const QString &text) const;
    QStringList tokenize(const QString &text) const;
    QString getStoragePath() const;
    void save();
    void load();

    QMap<QString, Document> m_documents;

    bool m_enabled = false;
    int m_topK = 5;
    qreal m_threshold = 0.3;

    static constexpr qreal K1 = 1.5;
    static constexpr qreal B = 0.75;
};