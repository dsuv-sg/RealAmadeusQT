#pragma once
#include <QObject>
#include <QString>

class ConversationIO : public QObject
{
    Q_OBJECT
public:
    explicit ConversationIO(QObject *parent = nullptr);

    Q_INVOKABLE static bool saveToFile(const QString &filePath, const QString &content);
    Q_INVOKABLE static QString loadFromFile(const QString &filePath);
    Q_INVOKABLE static QString findLatestExport(const QString &directory);
    Q_INVOKABLE static QString urlToLocalPath(const QString &url);
    Q_INVOKABLE static QString getSaveFileName(const QString &title, const QString &defaultPath, const QString &filter);
    Q_INVOKABLE static QString getOpenFileName(const QString &title, const QString &defaultPath, const QString &filter);
};
