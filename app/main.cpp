/**
 * @file main.cpp
 * @brief Application entry point for CADNC — a FreeCAD-backed CAD-CAM desktop application.
 *
 * Handles:
 *  - OpenGL surface format configuration (GLX backend, Core Profile)
 *  - Single-instance enforcement via QLockFile
 *  - Qt Linguist translation loading
 *  - QML engine startup
 */

#include <QDir>
#include <QGuiApplication>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QtQml>
#include <QLocale>
#include <QQuickWindow>
#include <QQmlContext>
#include <QTranslator>

#include "AppVersion.h"
#include "CadEngine.h"
#include "OccViewport.h"

// ── Crash-backtrace signal handler ───────────────────────────────────────────
#include <csignal>
#include <cstring>
#include <cstdlib>
#include <execinfo.h>
#include <unistd.h>

static void crashHandler(int sig)
{
    const char *msg = (sig == SIGSEGV) ? "\n=== SIGSEGV crash ===\n"
                    : (sig == SIGABRT) ? "\n=== SIGABRT crash ===\n"
                    : (sig == SIGFPE)  ? "\n=== SIGFPE crash ===\n"
                    :                    "\n=== Unknown crash signal ===\n";
    (void)write(STDERR_FILENO, msg, strlen(msg));

    void *frames[64];
    int count = backtrace(frames, 64);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);

    raise(sig);
    _Exit(1);
}

static void installCrashHandler(int signum)
{
    struct sigaction sa{};
    sa.sa_handler = crashHandler;
    sa.sa_flags   = SA_RESETHAND;
    sigemptyset(&sa.sa_mask);
    sigaction(signum, &sa, nullptr);
}

int main(int argc, char *argv[])
{
    // Install crash signal handlers
    installCrashHandler(SIGSEGV);
    installCrashHandler(SIGABRT);
    installCrashHandler(SIGFPE);

    // Force GLX on Linux (OCCT is compiled with GLX, not EGL)
#ifdef Q_OS_LINUX
    if (!qEnvironmentVariableIsSet("QT_XCB_GL_INTEGRATION")) {
        qputenv("QT_XCB_GL_INTEGRATION", "xcb_glx");
    }
#endif

    // Configure OpenGL surface format
    QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL);

    QSurfaceFormat format;
    format.setDepthBufferSize(24);
    format.setStencilBufferSize(8);
    format.setProfile(QSurfaceFormat::CoreProfile);
    QSurfaceFormat::setDefaultFormat(format);

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    // Create application instance
    QGuiApplication app(argc, argv);
    app.setApplicationName("CADNC");
    app.setOrganizationName("SMB Engineering");
    app.setApplicationVersion(QStringLiteral(CADNC_APP_VERSION));

    // Single-instance lock
    QString lockPath = QDir::temp().absoluteFilePath("CADNC.lock");
    QLockFile lockFile(lockPath);
    if (!lockFile.tryLock()) {
        qWarning("CADNC is already running.");
        return 1;
    }

    // Load translations
    QTranslator translator;
    if (translator.load(QLocale(), "cadnc", "_", ":/translations")) {
        app.installTranslator(&translator);
    }

    // Initialize CAD backend engine (bridge between QML and FreeCAD)
    auto* cadEngine = new CADNC::CadEngine(&app);
    if (!cadEngine->init(argc, argv)) {
        qWarning("CADNC: Failed to initialize CAD backend");
        // Continue anyway — UI will show but backend operations will fail gracefully
    }

    // Register OCCT viewport type for QML
    qmlRegisterType<CADNC::OccViewport>("CADNC.Viewport", 1, 0, "OccViewport");

    // Load the QML UI
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appVersion", app.applicationVersion());
    engine.rootContext()->setContextProperty("cadEngine", cadEngine);

    QObject::connect(&engine, &QQmlEngine::quit, &app, &QGuiApplication::quit);

    engine.load(QUrl("qrc:/qml/Main.qml"));

    if (engine.rootObjects().isEmpty())
        return -1;

    // Wire CadEngine to the OCCT viewport (find it in the QML tree)
    auto* rootObj = engine.rootObjects().first();
    auto* viewport = rootObj->findChild<CADNC::OccViewport*>("occViewport");
    if (viewport) {
        cadEngine->setViewport(viewport);
    }

    return app.exec();
}
