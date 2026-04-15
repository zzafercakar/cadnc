/**
 * @file main.cpp
 * @brief Application entry point for CADNC — a FreeCAD-backed CAD-CAM desktop application.
 *
 * Initializes the FreeCAD backend via CadEngine, then starts the Qt6 QML UI.
 */

#include <QDir>
#include <QGuiApplication>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTranslator>
#include <QLocale>

#include "AppVersion.h"
#include "CadEngine.h"

// ── Crash-backtrace signal handler ──────────────────────────────────
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

    // ── Initialize FreeCAD backend ──────────────────────────────────
    CADNC::CadEngine engine;
    if (!engine.init(argc, argv)) {
        qCritical("Failed to initialize FreeCAD backend");
        return 1;
    }

    // Create default document
    engine.newDocument("Untitled");

    // Load translations
    QTranslator translator;
    if (translator.load(QLocale(), "cadnc", "_", ":/translations")) {
        app.installTranslator(&translator);
    }

    // Load the QML UI with CadEngine exposed as context property
    QQmlApplicationEngine qmlEngine;
    qmlEngine.rootContext()->setContextProperty("appVersion", app.applicationVersion());
    qmlEngine.rootContext()->setContextProperty("cadEngine", &engine);

    QObject::connect(&qmlEngine, &QQmlEngine::quit, &app, &QGuiApplication::quit);

    qmlEngine.load(QUrl("qrc:/qml/Main.qml"));

    if (qmlEngine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
