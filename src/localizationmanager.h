#pragma once
#include <QObject>
#include <QVariantMap>
#include <QStringList>
#include "appsettings.h"

class LocalizationManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap translations READ translations NOTIFY translationsChanged)
    Q_PROPERTY(int language READ language WRITE setLanguage NOTIFY languageChanged)

public:
    explicit LocalizationManager(AppSettings *settings, QObject *parent = nullptr);

    QVariantMap translations() const;
    int language() const;
    void setLanguage(int langIndex);

    Q_INVOKABLE QString t(const QString &key, const QString &defaultValue = QString()) const;

signals:
    void translationsChanged();
    void languageChanged(int langIndex);

private:
    void loadTranslations();

    AppSettings *m_settings;
    int m_languageIndex;
    QVariantMap m_translations;
    QStringList m_languages;
};
