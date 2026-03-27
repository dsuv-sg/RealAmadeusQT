#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include "src/appsettings.h"
#include "src/memorymanager.h"
#include "src/aiservice.h"

int main(int argc, char *argv[])
{
    // ─── GPU acceleration: prefer hardware-accelerated backends ───
    // D3D11 is the default on Windows, Vulkan/OpenGL fallback.
    // Qt auto-selects the best available; set explicit preference here.
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Direct3D11);
    // Uncomment below to force OpenGL if D3D11 not available:
    // QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

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

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("RealAmadeusPC", "Main");

    return app.exec();
}
