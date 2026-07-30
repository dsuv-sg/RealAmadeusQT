// Touch main.cpp to trigger post-build resource copy
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QSurfaceFormat>
#include <QFontDatabase>
#include "src/appsettings.h"
#include "src/memorymanager.h"
#include "src/aiservice.h"
#include "src/live2ditem.h"
#include "src/notificationservice.h"
#include "src/updatemanager.h"
#include "src/localizationmanager.h"
#include "src/achievementmanager.h"
#include "src/conversationio.h"
#include "src/randomeventservice.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <QTimer>

bool downloadFile(const QString &urlStr, const QString &destPath) {
    QUrl url(urlStr);
    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = manager.get(request);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    timer.start(8000); // 8 seconds timeout

    loop.exec();

    if (timer.isActive()) {
        timer.stop();
    } else {
        reply->abort();
        reply->deleteLater();
        return false;
    }

    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return false;
    }

    QFile file(destPath);
    if (!file.open(QIODevice::WriteOnly)) {
        reply->deleteLater();
        return false;
    }

    file.write(reply->readAll());
    file.close();
    reply->deleteLater();
    return true;
}

// ── Force discrete GPU on hybrid systems (NVIDIA Optimus / AMD PowerXpress) ──
#ifdef _WIN32
extern "C" {
    __declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
    __declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}
#endif

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QSurfaceFormat format;
    format.setVersion(3, 1);
    format.setProfile(QSurfaceFormat::CompatibilityProfile);
    format.setOption(QSurfaceFormat::DeprecatedFunctions, true);
    QSurfaceFormat::setDefaultFormat(format);

    QApplication app(argc, argv);
    QString appDir = QCoreApplication::applicationDirPath();
    const QStringList fontFiles = {
        "/resources/fonts/NotoSerifCJKkr-Regular.otf",
        "/resources/fonts/NotoSerifCJKsc-Regular.otf",
        "/resources/fonts/NotoSerifCJKtc-Regular.otf",
        "/resources/fonts/NotoSerifCJKhk-Regular.otf",
        "/resources/fonts/NotoSerifCJK-Regular.ttc",
        "/resources/fonts/NotoSerifCJK-ExtraLight.ttc",
        "/resources/fonts/NotoSerifCJK-Light.ttc",
        "/resources/fonts/NotoSerif-Regular.ttf",
        "/resources/fonts/NotoSerif-ExtraLight.ttf",
        "/resources/fonts/NotoSerif-Light.ttf"
    };
    for (const QString &f : fontFiles) {
        int id = QFontDatabase::addApplicationFont(appDir + f);
        if (id < 0)
            qWarning() << "[Font] Failed to load:" << f;
    }
    // Check if MS Mincho is already in the system
    bool hasMSMincho = false;
    {
        QFontDatabase db;
        QStringList families = db.families();
        for (const QString &family : families) {
            if (family.compare("MS Mincho", Qt::CaseInsensitive) == 0 ||
                family.compare("ＭＳ 明朝", Qt::CaseInsensitive) == 0 ||
                family.compare("MS-Mincho", Qt::CaseInsensitive) == 0) {
                hasMSMincho = true;
                break;
            }
        }
    }

    if (!hasMSMincho) {
        QString localTtc = appDir + "/resources/fonts/msmincho.ttc";
        QString localTtf = appDir + "/resources/fonts/msmincho.ttf";
        QString localTtfCaps = appDir + "/resources/fonts/MSMINCHO.TTF";
        
        if (QFile::exists(localTtc)) {
            QFontDatabase::addApplicationFont(localTtc);
            hasMSMincho = true;
        } else if (QFile::exists(localTtf)) {
            QFontDatabase::addApplicationFont(localTtf);
            hasMSMincho = true;
        } else if (QFile::exists(localTtfCaps)) {
            QFontDatabase::addApplicationFont(localTtfCaps);
            hasMSMincho = true;
        } else {
            // Try to download it dynamically (fallback repository raw link)
            QString url = "https://raw.githubusercontent.com/vslabs/winfonts/master/msmincho.ttc";
            QDir().mkpath(appDir + "/resources/fonts");
            if (downloadFile(url, localTtc)) {
                QFontDatabase::addApplicationFont(localTtc);
                hasMSMincho = true;
            }
        }
    }

    QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Hangul, "Noto Serif CJK KR");
    app.setApplicationName("RealAmadeus");
    app.setOrganizationName("RealAmadeus");
    app.setApplicationVersion(REALAMADEUS_VERSION);
    app.setWindowIcon(QIcon(":/qt/qml/RealAmadeusPC/resources/images/amadeus_logo_v3.png"));

    // ─── Register C++ backend instances ───
    AppSettings  settings;
    MemoryManager memory;
    AIService     aiService;
    NotificationService notificationService;
    UpdateManager updateManager;
    LocalizationManager localization(&settings);
    AchievementManager achievementManager(&localization);
    ConversationIO conversationIO;
    RandomEventService randomEventService;
    randomEventService.setLocalizationManager(&localization);

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("AppSettings",    &settings);
    engine.rootContext()->setContextProperty("MemoryManager",  &memory);
    engine.rootContext()->setContextProperty("AIService",      &aiService);
    engine.rootContext()->setContextProperty("NotificationService", &notificationService);
    engine.rootContext()->setContextProperty("UpdateManager",  &updateManager);
    engine.rootContext()->setContextProperty("Localization",   &localization);
    engine.rootContext()->setContextProperty("AchievementManager", &achievementManager);
    engine.rootContext()->setContextProperty("ConversationIO", &conversationIO);
    engine.rootContext()->setContextProperty("RandomEventService", &randomEventService);
    engine.rootContext()->setContextProperty("appDirPath",     QCoreApplication::applicationDirPath());
    qmlRegisterType<Live2DItem>("Amadeus.Live2D", 1, 0, "Live2DItem");

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("RealAmadeusPC", "Main");

    return app.exec();
}
