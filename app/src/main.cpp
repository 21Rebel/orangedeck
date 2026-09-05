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

#ifdef ORANGEDECK_LAYERSHELL
#include <LayerShellQt/Window>
#endif

#ifdef Q_OS_ANDROID
#include <QHash>
#include <QJniObject>
#endif

namespace {

#ifdef Q_OS_ANDROID
// **Die Ansicht steckt in der Aktion, nicht in einem Extra.** Ein statisches
// `<intent>` in `res/xml/shortcuts.xml` traegt keine `<extra>`-Kinder --
// Android dokumentiert dort nur `action`, `targetPackage` und `targetClass`.
// Also bekommt jede Verknuepfung ihre eigene Aktion, und hier wird sie beim
// Start ausgelesen. Auf dem Schreibtisch macht `--view` dasselbe.
//
// **Nur beim Start.** Die Activity laeuft `singleTop`: tippt jemand eine
// zweite Verknuepfung an, waehrend die Anwendung schon offen ist, kommt das
// als `onNewIntent` -- das reicht hier nicht durch, die Ansicht bleibt dann
// stehen. Wer wechseln will, nimmt die Reiter. Aufgeschrieben, damit es
// niemand fuer einen Fehler haelt.
int ansichtAusAbsicht()
{
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid())
        return -1;
    QJniObject absicht = activity.callObjectMethod(
        "getIntent", "()Landroid/content/Intent;");
    if (!absicht.isValid())
        return -1;
    QJniObject aktion = absicht.callObjectMethod(
        "getAction", "()Ljava/lang/String;");
    if (!aktion.isValid())
        return -1;

    // Dieselben Zahlen wie bei `--view`; sie muessen zu den Aktionen in
    // `android/res/xml/shortcuts.xml` passen.
    static const QHash<QString, int> karte{
        {QStringLiteral("store.rebel.orangedeck.VIEW_FEED"), 0},
        {QStringLiteral("store.rebel.orangedeck.VIEW_CLOCK"), 1},
        {QStringLiteral("store.rebel.orangedeck.VIEW_EXPLORER"), 3},
        {QStringLiteral("store.rebel.orangedeck.VIEW_MARKET"), 6},
    };
    return karte.value(aktion.toString(), -1);
}
#endif

#ifdef ORANGEDECK_LAYERSHELL
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
    app.setOrganizationName("orangedeck");
    app.setOrganizationDomain("21rebel.dev");
    app.setApplicationName("orangedeck");
    app.setApplicationVersion(QStringLiteral(ORANGEDECK_VERSION));
    app.setApplicationDisplayName(QStringLiteral("OrangeDeck"));
    // Ausdruecklich gesetzt: sonst leitet Qt die Wayland-app_id aus der
    // umgedrehten Domain und dem Programmnamen ab ("dev.21rebel.orangedeck-app"),
    // und der Fensterverwalter findet das Symbol nicht, weil die
    // .desktop-Datei anders heisst. Der Unterstrich gehoert dazu -- ein
    // Segment einer solchen Kennung darf nicht mit einer Ziffer beginnen.
    app.setDesktopFileName(QStringLiteral("store._21rebel.orangedeck"));

    QCommandLineParser p;
    p.setApplicationDescription(QStringLiteral(
        "OrangeDeck -- Mempool, Uhr, Miner, Explorer.\n"
        "Ohne Schalter ein gewoehnliches Fenster; mit --layer ein Widget "
        "oder eine Leiste auf dem Desktop."));
    p.addHelpOption();
    p.addVersionOption();
    // Kein kurzes "-v": das ist schon von --version belegt, und
    // QCommandLineParser lehnt dann die **ganze** Option ab -- "--view" waere
    // stillschweigend unbekannt.
    const QCommandLineOption oAnsicht(QStringLiteral("view"),
        QStringLiteral("Ansicht: 0 Feed, 1 Uhr, 2 Miner, 3 Explorer, "
                       "4 Wallet, 5 Einstellungen, 6 Markt. "
                       "Ohne Angabe die zuletzt benutzte."),
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
    const QCommandLineOption oQuelle(QStringLiteral("source"),
        QStringLiteral("Datenquelle: daemon (eigener Dienst, Vorgabe) oder "
                       "direct (selbst zu mempool.space)."),
        QStringLiteral("name"));
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
    p.addOption(oQuelle);
    p.addOption(oKennung);
    p.process(app);

    // Muss **vor** dem Laden des QML stehen: die Settings-Gruppe darin holt
    // sich den Namen beim Erzeugen, spaeter wirkt eine Aenderung nicht mehr.
    if (p.isSet(oKennung) && !p.value(oKennung).isEmpty())
        app.setApplicationName(QStringLiteral("orangedeck-") + p.value(oKennung));

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
#ifdef Q_OS_ANDROID
    // Auf Android gibt es keine Befehlszeile; dieselbe Angabe kommt von der
    // angetippten Verknuepfung. `--view` behaelt trotzdem den Vorrang: es
    // wird nur gesetzt, wenn es ueberhaupt gesetzt werden kann, und beim
    // Pruefen ueber `adb shell am` ist es der kuerzere Weg.
    else {
        const int nr = ansichtAusAbsicht();
        if (nr >= 0)
            start.insert(QStringLiteral("forcedView"), nr);
    }
#endif
    if (p.isSet(oNackt))
        start.insert(QStringLiteral("bare"), true);
    if (p.isSet(oQuelle))
        start.insert(QStringLiteral("forcedSource"), p.value(oQuelle));
    engine.setInitialProperties(start);
    engine.loadFromModule("OrangeDeck", "Main");

    const auto wurzeln = engine.rootObjects();
    if (wurzeln.isEmpty())
        return 1;
    auto *fenster = qobject_cast<QQuickWindow *>(wurzeln.first());
    if (!fenster)
        return 1;

#ifdef ORANGEDECK_LAYERSHELL
    if (p.isSet(oLayer)) {
        if (LSWindow *ls = LSWindow::get(fenster)) {
            ls->setLayer(ebeneAus(p.value(oLayer)));
            ls->setScope(QStringLiteral("orangedeck"));
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
