// Eigenstaendige Fassung des Bitcoin-Feeds: dieselbe QML-Grafik wie in der
// Shell, nur in einem gewoehnlichen Qt-Fenster. Laeuft damit auf jedem
// Linux-Desktop und ist zugleich die Grundlage fuer die Android-Fassung.
//
// Zweite Betriebsart: `--layer`. Dann wird aus dem Fenster eine
// Layer-Shell-Flaeche -- also ein Desktop-Widget oder eine Leiste, ohne
// Rahmen, an eine Kante geheftet und unter (oder ueber) den gewoehnlichen
// Fenstern. Das ist der Weg fuer alle Wayland-Compositoren ausser DMS:
// niri, sway, Hyprland, river, labwc. Ohne die Bibliothek
// (`layer-shell-qt`, Qt6) baut alles wie zuvor, nur `--layer` fehlt dann.
#include <QGuiApplication>
#include <QCommandLineParser>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QMargins>

#ifdef BTCFEED_LAYERSHELL
#include <LayerShellQt/Window>
#endif

namespace {

#ifdef BTCFEED_LAYERSHELL
using LSWindow = LayerShellQt::Window;

LSWindow::Layer ebeneAus(const QString &s)
{
    if (s == QLatin1String("background"))
        return LSWindow::LayerBackground;
    if (s == QLatin1String("top"))
        return LSWindow::LayerTop;
    if (s == QLatin1String("overlay"))
        return LSWindow::LayerOverlay;
    return LSWindow::LayerBottom;
}

LSWindow::Anchors kantenAus(const QString &s)
{
    LSWindow::Anchors a;
    const auto teile = s.split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &t : teile) {
        const QString k = t.trimmed().toLower();
        if (k == QLatin1String("top"))
            a |= LSWindow::AnchorTop;
        else if (k == QLatin1String("bottom"))
            a |= LSWindow::AnchorBottom;
        else if (k == QLatin1String("left"))
            a |= LSWindow::AnchorLeft;
        else if (k == QLatin1String("right"))
            a |= LSWindow::AnchorRight;
    }
    return a;
}
#endif

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("btcfeed");
    app.setOrganizationDomain("21rebel.dev");
    app.setApplicationName("btcfeed");
    app.setApplicationVersion("0.1");
    app.setApplicationDisplayName(QStringLiteral("Bitcoin Feed"));
    // Ausdruecklich gesetzt: sonst leitet Qt die Wayland-app_id aus der
    // umgedrehten Domain und dem Programmnamen ab ("dev.21rebel.btcfeed-app"),
    // und der Fensterverwalter findet das Symbol nicht, weil die
    // .desktop-Datei anders heisst. Der Unterstrich gehoert dazu -- ein
    // Segment einer solchen Kennung darf nicht mit einer Ziffer beginnen.
    app.setDesktopFileName(QStringLiteral("store._21rebel.btcfeed"));

    QCommandLineParser p;
    p.setApplicationDescription(QStringLiteral(
        "Bitcoin Feed -- Mempool, Blockclock, Miner, Explorer.\n"
        "Ohne Schalter ein gewoehnliches Fenster; mit --layer ein Widget "
        "oder eine Leiste auf dem Desktop."));
    p.addHelpOption();
    p.addVersionOption();
    // Kein kurzes "-v": das ist schon von --version belegt, und
    // QCommandLineParser lehnt dann die **ganze** Option ab -- "--view" waere
    // stillschweigend unbekannt.
    const QCommandLineOption oAnsicht(QStringLiteral("view"),
        QStringLiteral("Ansicht: 0 Feed, 1 Blockclock, 2 Miner, 3 Explorer, "
                       "4 Wallet, 5 Einstellungen. Ohne Angabe die zuletzt benutzte."),
        QStringLiteral("nr"));
    const QCommandLineOption oLayer(QStringLiteral("layer"),
        QStringLiteral("Als Layer-Shell-Flaeche: background, bottom (Vorgabe), top, overlay."),
        QStringLiteral("ebene"), QStringLiteral("bottom"));
    const QCommandLineOption oKante(QStringLiteral("anchor"),
        QStringLiteral("Kanten, mit Komma: top,bottom,left,right. "
                       "Zwei gegenueberliegende dehnen die Flaeche."),
        QStringLiteral("kanten"));
    const QCommandLineOption oBreite(QStringLiteral("width"),
        QStringLiteral("Breite in Pixeln (nur mit --layer)."), QStringLiteral("px"));
    const QCommandLineOption oHoehe(QStringLiteral("height"),
        QStringLiteral("Hoehe in Pixeln (nur mit --layer)."), QStringLiteral("px"));
    const QCommandLineOption oRand(QStringLiteral("margin"),
        QStringLiteral("Abstand zur Kante: eine Zahl oder oben,rechts,unten,links."),
        QStringLiteral("px"));
    const QCommandLineOption oPlatz(QStringLiteral("exclusive"),
        QStringLiteral("Platz, den andere Fenster freilassen. 0 keiner (Vorgabe), "
                       "-1 sich selbst ueberlappen lassen."),
        QStringLiteral("px"), QStringLiteral("0"));
    const QCommandLineOption oTasten(QStringLiteral("keyboard"),
        QStringLiteral("Tastatur annehmen (nur mit --layer)."));
    const QCommandLineOption oNackt(QStringLiteral("bare"),
        QStringLiteral("Ohne Reiter, Kopf- und Fusszeile -- fuer ein Widget."));
    const QCommandLineOption oKennung(QStringLiteral("id"),
        QStringLiteral("Eigener Einstellungsspeicher unter diesem Namen. "
                       "Mehrere Widgets koennen so verschiedene Ansichten "
                       "behalten, ohne sich gegenseitig zu ueberschreiben."),
        QStringLiteral("name"));
    p.addOption(oAnsicht);
    p.addOption(oLayer);
    p.addOption(oKante);
    p.addOption(oBreite);
    p.addOption(oHoehe);
    p.addOption(oRand);
    p.addOption(oPlatz);
    p.addOption(oTasten);
    p.addOption(oNackt);
    p.addOption(oKennung);
    p.process(app);

    // Muss **vor** dem Laden des QML stehen: die Settings-Gruppe darin holt
    // sich den Namen beim Erzeugen, spaeter wirkt eine Aenderung nicht mehr.
    if (p.isSet(oKennung) && !p.value(oKennung).isEmpty())
        app.setApplicationName(QStringLiteral("btcfeed-") + p.value(oKennung));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);

    // Das Fenster entsteht unsichtbar und wird erst unten gezeigt. Sonst
    // haengt die Wayland-Flaeche schon, bevor sie zur Layer-Flaeche erklaert
    // werden kann -- und `--layer` bliebe wirkungslos.
    QVariantMap start{{QStringLiteral("visible"), false}};
    if (p.isSet(oAnsicht)) {
        bool ok = false;
        const int nr = p.value(oAnsicht).toInt(&ok);
        if (ok)
            start.insert(QStringLiteral("forcedView"), nr);
    }
    if (p.isSet(oNackt))
        start.insert(QStringLiteral("bare"), true);
    engine.setInitialProperties(start);
    engine.loadFromModule("BtcFeed", "Main");

    const auto wurzeln = engine.rootObjects();
    if (wurzeln.isEmpty())
        return 1;
    auto *fenster = qobject_cast<QQuickWindow *>(wurzeln.first());
    if (!fenster)
        return 1;

#ifdef BTCFEED_LAYERSHELL
    if (p.isSet(oLayer)) {
        if (LSWindow *ls = LSWindow::get(fenster)) {
            ls->setLayer(ebeneAus(p.value(oLayer)));
            ls->setScope(QStringLiteral("btcfeed"));
            if (p.isSet(oKante))
                ls->setAnchors(kantenAus(p.value(oKante)));
            if (p.isSet(oRand)) {
                const auto t = p.value(oRand).split(QLatin1Char(','), Qt::SkipEmptyParts);
                if (t.size() == 4)
                    ls->setMargins({t[3].toInt(), t[0].toInt(), t[1].toInt(), t[2].toInt()});
                else if (t.size() == 1)
                    ls->setMargins(QMargins(t[0].toInt(), t[0].toInt(),
                                            t[0].toInt(), t[0].toInt()));
            }
            ls->setExclusiveZone(p.value(oPlatz).toInt());
            ls->setKeyboardInteractivity(p.isSet(oTasten)
                ? LSWindow::KeyboardInteractivityOnDemand
                : LSWindow::KeyboardInteractivityNone);
            // Gewuenschte Groesse: was nicht angegeben ist, bleibt die
            // Groesse aus dem QML -- an zwei gegenueberliegenden Kanten
            // bestimmt ohnehin der Compositor.
            const int b = p.isSet(oBreite) ? p.value(oBreite).toInt() : fenster->width();
            const int h = p.isSet(oHoehe) ? p.value(oHoehe).toInt() : fenster->height();
            ls->setDesiredSize(QSize(b, h));
            fenster->resize(b, h);
        }
    }
#else
    if (p.isSet(oLayer)) {
        qWarning("--layer ist nicht einkompiliert: layer-shell-qt (Qt6) fehlte beim Bauen.");
    }
#endif

    fenster->setVisible(true);
    return app.exec();
}
