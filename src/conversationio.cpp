#include "conversationio.h"
#include <QFile>
#include <QDir>
#include <QFileInfoList>
#include <QTextStream>
#include <QUrl>
#include <QFileDialog>

ConversationIO::ConversationIO(QObject *parent)
    : QObject(parent)
{}

bool ConversationIO::saveToFile(const QString &filePath, const QString &content)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream stream(&file);
    stream << content;
    file.close();
    return true;
}

QString ConversationIO::loadFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream stream(&file);
    QString content = stream.readAll();
    file.close();
    return content;
}

QString ConversationIO::findLatestExport(const QString &directory)
{
    QDir dir(directory);
    QStringList filters;
    filters << "chat_export_*.json";
    QFileInfoList files = dir.entryInfoList(filters, QDir::Files, QDir::Time);
    if (files.isEmpty())
        return {};
    return files.first().absoluteFilePath();
}

QString ConversationIO::urlToLocalPath(const QString &url)
{
    return QUrl(url).toLocalFile();
}

QString ConversationIO::getSaveFileName(const QString &title, const QString &defaultPath, const QString &filter)
{
    return QFileDialog::getSaveFileName(nullptr, title, defaultPath, filter);
}

QString ConversationIO::getOpenFileName(const QString &title, const QString &defaultPath, const QString &filter)
{
    return QFileDialog::getOpenFileName(nullptr, title, defaultPath, filter);
}
