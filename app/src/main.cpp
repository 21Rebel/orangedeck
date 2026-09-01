// Eigenstaendige Fassung des Bitcoin-Feeds: dieselbe QML-Grafik wie in der
// Shell, nur in einem gewoehnlichen Qt-Fenster. Laeuft damit auf jedem
// Linux-Desktop und ist zugleich die Grundlage fuer die Android-Fassung.
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("btcfeed");
    app.setOrganizationDomain("21rebel.dev");
    app.setApplicationName("btcfeed");
    app.setApplicationDisplayName(QStringLiteral("Bitcoin Feed"));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("BtcFeed", "Main");
    return app.exec();
}
