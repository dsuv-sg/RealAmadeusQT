#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QSurfaceFormat>
#include "src/appsettings.h"
#include "src/memorymanager.h"
#include "src/aiservice.h"
#include "src/live2ditem.h"

// ── Force discrete GPU on hybrid systems (NVIDIA Optimus / AMD PowerXpress) ──
#ifdef _WIN32
extern "C" {
    __declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
    __declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}
#endif

int main(int argc, char *argv[])
{
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QSurfaceFormat format;
    format.setVersion(3, 1);
    format.setProfile(QSurfaceFormat::CompatibilityProfile);
    format.setOption(QSurfaceFormat::DeprecatedFunctions, true);
    QSurfaceFormat::setDefaultFormat(format);

    QApplication app(argc, argv);
    app.setApplicationName("RealAmadeus");
    app.setOrganizationName("RealAmadeus");
    app.setWindowIcon(QIcon(":/qt/qml/RealAmadeusPC/resources/images/amadeus_logo_v3.png"));

    // ─── Register C++ backend instances ───
    AppSettings  settings;
    MemoryManager memory;
    AIService     aiService;

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("AppSettings",    &settings);
    engine.rootContext()->setContextProperty("MemoryManager",  &memory);
    engine.rootContext()->setContextProperty("AIService",      &aiService);
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
