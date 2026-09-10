// Eigenstaendiges Fenster. Portierung von shell/quickshell/shell.qml auf
// gewoehnliches Qt Quick:
//
//   ShellRoot/FloatingWindow  ->  Window
//   FileView (view.json)      ->  Settings aus QtCore (QSettings), portabel
//                                 und auch unter Android verfuegbar
//
// FeedState, FeedPanel, FeedCanvas sind unveraendert dieselben Dateien wie im
// DMS-Plugin -- sie liegen einmal unter ui/qml und werden hier nur zusaetzlich
// ins QML-Modul gepackt.
import QtQuick
import QtCore
import "strings.js" as Tr

Window {
    id: win

    width: 1100
    height: 800
    minimumWidth: 260
    minimumHeight: 160
    visible: true
    title: qsTr("OrangeDeck")

    // Deckkraft macht das Fenster selbst; ob geblurrt wird, entscheidet der
    // Compositor. Kacheln und Schrift bleiben deckend.
    //
    // **Die Vorgabe ist deckend.** Der milchige Eindruck entsteht erst, wenn
    // der Compositor hinter dem Fenster weichzeichnet -- niri tut das hier,
    // GNOME und die meisten anderen tun es nicht. Dort heisst 0,82 nur:
    // man liest das Fenster dahinter mit, quer durch die Graphen. In der
    // Pruef-VM am 04.09.2026 stand das Terminal mitten im Mempool. Wer den
    // milchigen Look will, holt ihn mit einem Zug am Regler oder mit `-`.
    color: Qt.rgba(0.043, 0.043, 0.071, win.bgOpacity)

    property string colorMode: "age"
    property string sizeMode: "value"
    property bool showInfo: true
    property bool showLegend: true
    property bool showRuler: true
    property bool frosted: true
    property real bgOpacity: 1.0
    property real density: 1.0
    // -1 heisst: die zuletzt benutzte Ansicht. Sonst faengt das Fenster
    // immer bei derselben an und merkt sich gar nichts mehr.
    property int startView: -1
    // "daemon" oder "direct" -- siehe FeedState.mode
    // **Den Dienst gibt es nur unter Linux.** `orangedeck` laeuft als
    // systemd-Benutzerdienst; auf einem Telefon, unter Windows und unter macOS
    // kann er nicht laufen, und 127.0.0.1:21021 antwortet dort nie. Wer die
    // App dort frisch startet, bekaeme "keine Verbindung zum Feed" und muesste
    // die Einstellung erst finden -- ein Fehlerbild als Willkommensgruss.
    //
    // Der Direktbezug ist ueberall sonst nicht die Ausnahme, sondern der
    // Regelfall. Am 04.09.2026 im Android-Emulator aufgefallen; **die Abfrage
    // stand danach erst auf "android" und haette Windows und macOS beim ersten
    // Bau genauso getroffen.** Richtig ist die Frage nach dem Dienst, nicht
    // nach dem Geraet.
    property string dataSource: Qt.platform.os === "linux" ? "daemon" : "direct"

    // **Kein Gerät mit Tastatur.** Die Abfrage stand schon beim Suchfeld des
    // Explorers; mit dem Tastaturhinweis wird sie zum zweiten Mal gebraucht,
    // und eine Bedingung, die zweimal dasteht, laeuft irgendwann auseinander.
    readonly property bool ohneTastatur: Qt.platform.os === "android"
                                      || Qt.platform.os === "ios"
    readonly property string effSource: win.forcedSource.length ? win.forcedSource
                                                                : win.dataSource
    // Vorgabe USD wie in FeedTabs, SettingsView, den DMS-Ansichten, dem
    // Dashtab und DeckWidget.waehrung(). Am 09.09.2026 wurden die fuenf dort
    // umgestellt und diese sechste Stelle vergessen: die Anwendung zeigte
    // ohne Einstellung EUR, das Widget daneben USD.
    property string currency: "usd"
    property string tileColorMode: "fee"
    property bool clockBars: true
    // Leere Liste heisst: alles zeigen
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string clockFieldsRaw: ""
    readonly property var clockFields: clockFieldsRaw.length ? clockFieldsRaw.split("|") : []
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string minerFieldsRaw: ""
    readonly property var minerFields: minerFieldsRaw.length ? minerFieldsRaw.split("|") : []

    // **Die Adressen der Miner, und zwar hier.** Bisher standen sie an drei
    // Stellen, von denen keine ein Handy erreicht: in
    // `~/.config/orangedeck/sources.json`, in `ORANGEDECK_MINER` und im
    // Ergebnis von `orangedeck --discover-miners`. Auf Android gibt es weder
    // eine Befehlszeile noch diese Datei -- und `--discover-miners` braucht
    // rohe Sockel, die QML nicht hat.
    //
    // Eine vierte Quelle daneben zu stellen waere genau die Vervielfachung,
    // an der dieses Projekt schon mehrfach hing (dieselbe Liste dreimal in
    // `views.js`, die Klemme auf 5 in `shell.qml`). Also wird diese hier die
    // **fuehrende**: sie liegt in den QSettings wie alles andere, damit hat
    // sie jedes Geraet. Der Daemon liest `sources.json` zusaetzlich weiter,
    // damit bestehende Einrichtungen nichts merken.
    //
    // Mehrere Adressen mit `|` getrennt, wie `minerFieldsRaw`.
    property string minerHostsRaw: ""
    readonly property var minerHosts: {
        var out = [];
        var teile = minerHostsRaw.split("|");
        for (var i = 0; i < teile.length; i++) {
            var t = teile[i].trim();
            if (t.length)
                out.push(t);
        }
        return out;
    }
    // Die Wallet-Ansicht ist **abgeschaltet, bis sie ausdruecklich
    // eingeschaltet wird**. Nicht wegen der Guthaben -- die sind watch-only
    // vollstaendig geschuetzt --, sondern wegen der Verkettung: es ist der
    // einzige Teil des Programms, bei dem der Benutzer etwas ueber sich
    // preisgibt. Der Reiter erscheint erst nach der Warnung in den
    // Einstellungen.
    property bool showHeader: true
    property bool showFooter: true
    property bool showBlock: true
    property bool clockSpark: true
    property bool clockTime: false
    property bool clockPrice: true
    property string priceSpan: "30d"
    // Markt-Reiter: Zeitraum, Darstellung, eigener Zeitraum in Sekunden
    property string marketRange: "24h"
    property string marketKind: "candles"
    // Volumenbalken oder CVD unter dem Kurs
    property string marketLower: "volume"
    // Unterreiter im Markt: Kurs oder Liquidationen
    property string marketSub: "price"
    property int marketSecs: 259200
    // Ausdrueckliches Fenster im Markt, 0 = keins
    property int marketVon: 0
    property int marketBis: 0
    property bool marketCross: true
    property bool marketTape: true
    property bool showFeed: true
    property bool showClock: true
    property bool showMiner: true
    property bool showExplorer: true
    property bool showMarket: true
    property bool minerChart: true
    property bool minerDomains: true
    property bool minerBoard: true
    property bool explorerLive: true
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string explorerPartsRaw: ""
    readonly property var explorerParts: explorerPartsRaw.length ? explorerPartsRaw.split("|") : []
    // Als Zeichenkette abgelegt, getrennt mit "|". Zwei Fallen von QSettings
    // stecken darin: eine **leere** Liste wird als `@Invalid()` geschrieben und
    // als ungueltiger Wert zurueckgelesen -- und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als **Listentrenner**, aus
    // "height,price" wurde stillschweigend wieder "height".
    property string explorerPanelsRaw: ""
    readonly property var explorerPanels: explorerPanelsRaw.length ? explorerPanelsRaw.split("|") : []
    // **Gewaehlt ist nur, was jemand waehlt.** Leer heisst: die Sprache des
    // Systems. Bis zum 10.09.2026 stand hier `lang` mit der Systemsprache als
    // Vorgabe -- und QML-Settings schreibt beim Beenden auch Vorgaben in die
    // ini. Danach war die Sprache festgeschrieben: das Telefon auf en_US
    // umgestellt, die Anwendung blieb deutsch. Gespeichert wird deshalb nur
    // noch die Wahl, unter neuem Schluessel; das alte `lang` stand bei jeder
    // Installation, auch ohne dass je jemand gewaehlt haette, und wird nicht
    // mehr gelesen. Die Widgets lesen denselben Schluessel (Texte.java).
    property string langWahl: ""
    readonly property string lang: win.langWahl.length ? win.langWahl : Tr.systemLang()
    // Grosse Anzeige der Uhr -- als Zeichenkette abgelegt, siehe
    // die uebrigen Listen.
    property string bigFieldsRaw: "height"
    readonly property var bigFields: bigFieldsRaw.length ? bigFieldsRaw.split("|") : ["height"]
    property int bigRotate: 0
    property bool walletEnabled: false
    // Die Reihenfolge der Reiter, vom Anwender festgelegt. Leer heisst: die
    // Grundreihenfolge aus `views.js`. Als Zeichenkette abgelegt, getrennt
    // mit "|" -- aus denselben zwei Gruenden wie die uebrigen Listen: eine
    // leere Liste schreibt QSettings als `@Invalid()`, und ein Komma in einer
    // INI-Zeichenkette gilt beim Lesen als Listentrenner.
    property string tabOrderRaw: ""
    readonly property var tabOrder: tabOrderRaw.length ? tabOrderRaw.split("|") : []
    // 0 = Feed, 1 = Uhr, 2 = Miner, 3 = Explorer, 4 = Wallet. Wird
    // gemerkt, damit ein Tablet nach dem Einschalten gleich wieder als
    // Uhr hochkommt.
    property int view: 0
    // Von der Befehlszeile gesetzt (`--view`, `--bare`) und **nicht**
    // gespeichert: ein Widget an der Wand soll seine Ansicht behalten, ohne
    // die zuletzt benutzte Ansicht des grossen Fensters umzuschreiben.
    property int forcedView: -1
    property bool bare: false
    // Von der Befehlszeile (`--source`), ebenfalls nicht gespeichert
    property string forcedSource: ""

    // **Vollbild als Blockuhr.** Ohne Systemleisten und ohne Reiterzeile,
    // und solange es an ist, bleibt der Bildschirm an (das setzt main.cpp,
    // QML kann das Fensterflag nicht). Gespeichert, damit ein altes Tablet
    // nach dem Einschalten gleich wieder als Uhr an der Wand steht -- wie
    // `view` darueber. Heraus geht es mit dem Knopf, der nach einem Tipp
    // erscheint, mit der Zurueck-Geste oder mit F11.
    property bool vollbild: false

    function vollbildAnwenden() {
        if (win.bare)
            return;
        win.visibility = win.vollbild ? Window.FullScreen : Window.Windowed;
    }

    onVollbildChanged: vollbildAnwenden()

    // Bleibt auf dem Geraet: QSettings schreibt nach
    // ~/.config/orangedeck/orangedeck.conf (Linux) bzw. in den App-Speicher (Android).
    Settings {
        id: prefs
        category: "view"
        property alias colorMode: win.colorMode
        property alias sizeMode: win.sizeMode
        property alias showInfo: win.showInfo
        property alias showLegend: win.showLegend
        property alias bgOpacity: win.bgOpacity
        property alias view: win.view
        property alias showRuler: win.showRuler
        property alias frosted: win.frosted
        property alias density: win.density
        property alias startView: win.startView
        property alias dataSource: win.dataSource
        property alias currency: win.currency
        property alias tileColorMode: win.tileColorMode
        property alias clockBars: win.clockBars
        property alias clockFieldsRaw: win.clockFieldsRaw
        property alias minerFieldsRaw: win.minerFieldsRaw
        property alias minerHostsRaw: win.minerHostsRaw
        property alias showHeader: win.showHeader
        property alias showFooter: win.showFooter
        property alias showBlock: win.showBlock
        property alias clockSpark: win.clockSpark
        property alias clockTime: win.clockTime
        property alias clockPrice: win.clockPrice
        property alias priceSpan: win.priceSpan
        property alias marketRange: win.marketRange
        property alias marketKind: win.marketKind
        property alias marketLower: win.marketLower
        property alias marketSub: win.marketSub
        property alias marketSecs: win.marketSecs
        property alias marketVon: win.marketVon
        property alias marketBis: win.marketBis
        property alias marketCross: win.marketCross
        property alias marketTape: win.marketTape
        property alias showFeed: win.showFeed
        property alias showClock: win.showClock
        property alias showMiner: win.showMiner
        property alias showExplorer: win.showExplorer
        property alias showMarket: win.showMarket
        property alias minerChart: win.minerChart
        property alias minerDomains: win.minerDomains
        property alias minerBoard: win.minerBoard
        property alias explorerLive: win.explorerLive
        property alias explorerPartsRaw: win.explorerPartsRaw
        property alias explorerPanelsRaw: win.explorerPanelsRaw
        property alias langWahl: win.langWahl
        property alias bigFieldsRaw: win.bigFieldsRaw
        property alias bigRotate: win.bigRotate
        property alias walletEnabled: win.walletEnabled
        property alias tabOrderRaw: win.tabOrderRaw
        property alias vollbild: win.vollbild
    }

    // Beim Start in die gemerkte Ansicht -- fuer ein Tablet an der Wand ist
    // das meist die Uhr. Der Reiter "Wallet" faellt weg, solange er
    // nicht eingeschaltet ist.
    Component.onCompleted: {
        if (win.vollbild)
            vollbildAnwenden();
        if (win.forcedView >= 0)
            win.view = win.forcedView;
        // **Keine Obergrenze mehr.** Hier stand `<= 3` -- aus der Zeit, als
        // die Startansicht Feed, Uhr, Miner und Explorer kannte. Markt und
        // Wallet kamen dazu, die Grenze wanderte nicht mit: wer sie einstellen
        // konnte, dessen Wunsch wurde beim Start stillschweigend verworfen.
        // Eine Ansicht, die es gerade nicht gibt, faengt der Rueckfall gleich
        // darunter ab -- dafuer braucht es hier keine Zahl.
        else if (win.startView >= 0)
            win.view = win.startView;
        // Ausgeschaltete Wallet-Ansicht darf nicht als leere Seite dastehen
        if (win.view === 4 && !win.walletEnabled)
            win.view = 0;

        // **Und jede andere Ansicht, die es gerade nicht gibt, genauso.**
        // Die Wallet war bisher der einzige geprüfte Fall; `--view 2` ohne
        // Bitaxe und `--view 6` im Direktbezug landeten auf einer
        // vollstaendig leeren Seite, bei der nicht einmal ein Reiter
        // hervorgehoben war. Am 05.09.2026 im Android-Emulator aufgefallen,
        // wo der Markt **nie** einen Reiter hat: die Verknuepfung dorthin
        // fuehrte ins Nichts, und der einzige Ausweg war zu wissen, wo man
        // hintippen muss.
        //
        // Hier und nicht in `FeedTabs`: dort haengt der Rueckfall an
        // Signalen, und beim Start aendert sich nichts, worauf sie warten
        // koennten -- der Wert ist von Anfang an falsch. Diese Zeile laeuft
        // genau einmal, gleich nachdem er gesetzt wurde.
        if (tabs.tabViews.length > 0 && tabs.tabViews.indexOf(win.view) < 0)
            win.view = tabs.tabViews[0];
    }

    // Welche Reiter es gibt, rechnet `FeedTabs` -- samt Rueckfall auf den
    // Feed, wenn die gemerkte Ansicht gerade keinen Reiter hat. Hier stand das
    // vorher ein zweites Mal.
    //
    // Zwei fallen im Direktbezug weg, und zwar nicht aus Bequemlichkeit: der
    // Miner steht im Heimnetz, die Wallet-Ableitung ist Rechenarbeit des
    // Dienstes, und der Markt wird dort verdichtet. Ein Reiter, hinter dem
    // nichts sein kann, ist schlimmer als keiner.

    // Eine Einstellung setzen. Alles laeuft hier durch, damit es nur eine
    // Stelle gibt, an der etwas geaendert wird.
    function setOpt(key, value) {
        if (key === "bgOpacity")
            win.bgOpacity = value;
        else if (key === "density")
            win.density = value;
        else if (key === "startView")
            win.startView = value;
        else if (key === "dataSource")
            win.dataSource = value;
        else if (key === "colorMode")
            win.colorMode = value;
        else if (key === "sizeMode")
            win.sizeMode = value;
        else if (key === "showInfo")
            win.showInfo = value;
        else if (key === "showLegend")
            win.showLegend = value;
        else if (key === "showRuler")
            win.showRuler = value;
        else if (key === "frosted")
            win.frosted = value;
        else if (key === "currency")
            win.currency = value;
        else if (key === "tileColorMode")
            win.tileColorMode = value;
        else if (key === "clockBars")
            win.clockBars = value;
        else if (key === "clockFields")
            win.clockFieldsRaw = (value || []).join("|");
        else if (key === "minerFields")
            win.minerFieldsRaw = (value || []).join("|");
        else if (key === "showHeader")
            win.showHeader = value;
        else if (key === "showFooter")
            win.showFooter = value;
        else if (key === "showBlock")
            win.showBlock = value;
        else if (key === "clockSpark")
            win.clockSpark = value;
        else if (key === "clockTime")
            win.clockTime = value;
        else if (key === "clockPrice")
            win.clockPrice = value;
        else if (key === "priceSpan")
            win.priceSpan = value;
        else if (key === "marketRange")
            win.marketRange = value;
        else if (key === "marketKind")
            win.marketKind = value;
        else if (key === "marketLower")
            win.marketLower = value;
        else if (key === "marketSub")
            win.marketSub = value;
        else if (key === "marketSecs")
            win.marketSecs = value;
        else if (key === "marketVon")
            win.marketVon = value;
        else if (key === "marketBis")
            win.marketBis = value;
        else if (key === "marketCross")
            win.marketCross = value;
        else if (key === "marketTape")
            win.marketTape = value;
        else if (key === "showFeed")
            win.showFeed = value;
        else if (key === "showClock")
            win.showClock = value;
        else if (key === "showMiner")
            win.showMiner = value;
        else if (key === "showExplorer")
            win.showExplorer = value;
        else if (key === "showMarket")
            win.showMarket = value;
        else if (key === "minerHostsRaw")
            win.minerHostsRaw = value;
        else if (key === "minerChart")
            win.minerChart = value;
        else if (key === "minerDomains")
            win.minerDomains = value;
        else if (key === "minerBoard")
            win.minerBoard = value;
        else if (key === "explorerLive")
            win.explorerLive = value;
        else if (key === "explorerParts")
            win.explorerPartsRaw = (value || []).join("|");
        else if (key === "explorerPanels")
            win.explorerPanelsRaw = (value || []).join("|");
        else if (key === "lang")
            win.langWahl = value || "";
        else if (key === "bigFields")
            win.bigFieldsRaw = (value || []).join("|");
        else if (key === "bigRotate")
            win.bigRotate = value;
        else if (key === "tabOrder")
            win.tabOrderRaw = (value || []).join("|");
        else if (key === "walletEnabled") {
            win.walletEnabled = value;
            // Ausgeschaltet, waehrend die Ansicht offen war -> zurueck
            if (!value && win.view === 4)
                win.view = 5;
        }
    }

    readonly property var opts: ({
        "bgOpacity": win.bgOpacity,
        "density": win.density,
        "startView": win.startView,
        "dataSource": win.dataSource,
        "colorMode": win.colorMode,
        "sizeMode": win.sizeMode,
        "showInfo": win.showInfo,
        "showLegend": win.showLegend,
        "showRuler": win.showRuler,
        "frosted": win.frosted,
        "currency": win.currency,
        "tileColorMode": win.tileColorMode,
        "clockBars": win.clockBars,
        "clockFields": win.clockFields,
        "minerFields": win.minerFields,
        "showHeader": win.showHeader,
        "showFooter": win.showFooter,
        "showBlock": win.showBlock,
        "clockSpark": win.clockSpark,
        "clockTime": win.clockTime,
        "clockPrice": win.clockPrice,
        "priceSpan": win.priceSpan,
        "marketRange": win.marketRange,
        "marketKind": win.marketKind,
        "marketLower": win.marketLower,
        "marketSub": win.marketSub,
        "marketSecs": win.marketSecs,
        "marketVon": win.marketVon,
        "marketBis": win.marketBis,
        "marketCross": win.marketCross,
        "marketTape": win.marketTape,
        "showFeed": win.showFeed,
        "showClock": win.showClock,
        "showMiner": win.showMiner,
        "showExplorer": win.showExplorer,
        "showMarket": win.showMarket,
        "minerHostsRaw": win.minerHostsRaw,
        "minerChart": win.minerChart,
        "minerDomains": win.minerDomains,
        "minerBoard": win.minerBoard,
        "explorerLive": win.explorerLive,
        "explorerParts": win.explorerParts,
        "explorerPanels": win.explorerPanels,
        "lang": win.lang,
        "langWahl": win.langWahl,
        "bigFields": win.bigFields,
        "bigRotate": win.bigRotate,
        "walletEnabled": win.walletEnabled,
        "tabOrder": win.tabOrder
    })

    FeedState {
        id: feedState

        mode: win.effSource
        // Die Adressen der Miner. Im Daemon-Betrieb ungenutzt -- dort liest
        // der Dienst `sources.json`.
        minerHosts: win.minerHosts
    }

    // **Der Rand, den sich das System nimmt.** Ab Android 15 (API 35)
    // zeichnet das System jede Anwendung randlos, und sie muss die Raender
    // der Systemleisten selbst anwenden. Tut sie es nicht, liegt die
    // Reiterzeile unter der Statusleiste -- am 08.09.2026 auf einem Galaxy
    // A55 (Android 16, targetSdk 36) gemessen: `mAppBounds` ist der ganze
    // Schirm, der obere Rand 89 px. "Feed" und die Uhrzeit standen
    // uebereinander gedruckt, und **die Reiter waren nicht antippbar**: die
    // Statusleiste ist ein eigenes Fenster darueber und nimmt die
    // Beruehrung. Vom Feed-Reiter kam man per Finger nicht weg.
    //
    // `SafeArea` haengt hier an einem Behaelter und **nicht an `tabs`
    // selbst**: die Raender richten sich nach der Lage des Elements, und ein
    // Element, das seine eigene Lage aus ihnen ableitet, ist eine
    // Bindungsschleife.
    //
    // Keine Plattformabfrage. Auf dem Schreibtisch sind diese Raender 0 --
    // was nichts beansprucht, kostet auch nichts, und eine Abfrage waere
    // eine zweite Stelle, an der dieselbe Entscheidung steht.
    Item {
        id: flaeche

        anchors.fill: parent

        // **Alle Ansichten stehen in `FeedTabs`** -- dasselbe Bauteil wie im
        // Dashboard, im Popout und auf dem Desktop. Vorher verdrahtete dieses
        // Fenster sie selbst, und genau daran fehlte der Wallet-Ansicht ihre
        // Sprache und der Uhr der Kursverlauf: was hier dazukam, kam
        // dort nicht an, und umgekehrt.
        FeedTabs {
            id: tabs

            anchors.fill: parent
            anchors.leftMargin: 14 + flaeche.SafeArea.margins.left
            anchors.rightMargin: 14 + flaeche.SafeArea.margins.right
            anchors.bottomMargin: 14 + flaeche.SafeArea.margins.bottom
            anchors.topMargin: 8 + flaeche.SafeArea.margins.top
            feed: feedState
            opts: win.opts
            view: win.view
            // Im nackten Widget bleibt die Reiterzeile weg -- und mit ihr der
            // Platz, den sie braucht.
            tabsVisible: !win.bare && !win.vollbild
            finger: win.ohneTastatur
            // Deckkraft und Startansicht gehoeren dem Fenster, also stehen sie
            // hier auch in den Einstellungen.
            windowedSettings: true
            minerActions: !win.bare
            gap: 6
            tabFont: 13
            baseFont: 13
            onOptRequested: function (key, value) {
                win.setOpt(key, value);
            }
            onViewRequested: function (v) {
                win.view = v;
            }
            // Das Suchfeld des Explorers nimmt den Fokus, solange es zu sehen ist.
            // Beim Verlassen gehoert er wieder hierher -- sonst sind die
            // Tastenkuerzel nach einem Besuch im Explorer tot.
            onSearchFocusReleased: keys.forceActiveFocus()

            // **Auf dem Telefon holt sich das Suchfeld den Fokus nicht.** Dort
            // haengt am Fokus die Bildschirmtastatur, und die deckt die halbe
            // Ansicht zu: wer den Explorer oeffnet, sieht zuerst eine Tastatur
            // und muss sie wegwischen, bevor er die Bloecke sieht. Am 05.09.2026
            // im Emulator aufgefallen -- auf dem Schreibtisch kostet der Fokus
            // nichts und spart einen Klick, deshalb bleibt er dort.
            searchFocus: !win.ohneTastatur
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_C:
                // Drei Lesarten im Kreis: Alter, Gebuehr, Art
                win.colorMode = win.colorMode === "age" ? "fee"
                    : (win.colorMode === "fee" ? "type" : "age");
                hint.flash();
                break;
            case Qt.Key_S:
                win.sizeMode = win.sizeMode === "value" ? "vbytes" : "value";
                hint.flash();
                break;
            case Qt.Key_L:
                win.showLegend = !win.showLegend;
                hint.flash();
                break;
            case Qt.Key_Plus:
            case Qt.Key_Equal:
                win.bgOpacity = Math.min(1, win.bgOpacity + 0.05);
                hint.flash();
                break;
            case Qt.Key_Minus:
                win.bgOpacity = Math.max(0.15, win.bgOpacity - 0.05);
                hint.flash();
                break;
            case Qt.Key_B:
                tabs.triggerBlockAnimation();
                break;
            case Qt.Key_I:
                win.showInfo = !win.showInfo;
                hint.flash();
                break;
            case Qt.Key_1:
            case Qt.Key_2:
            case Qt.Key_3:
            case Qt.Key_4:
            case Qt.Key_5:
            case Qt.Key_6:
                // Die Ziffer zaehlt die **sichtbaren** Reiter ab -- ist die
                // Wallet-Ansicht aus, ruecken die dahinter auf.
                var n = event.key - Qt.Key_1;
                if (n < tabs.tabViews.length) {
                    win.view = tabs.tabViews[n];
                    hint.flash();
                }
                break;
            case Qt.Key_F11:
                win.vollbild = !win.vollbild;
                break;
            case Qt.Key_Back:
                // Die Zurueck-Geste verlaesst zuerst das Vollbild und erst
                // beim zweiten Mal die Anwendung. Nicht angenommen, geht sie
                // an Android weiter.
                if (!win.vollbild)
                    return;
                win.vollbild = false;
                break;
            case Qt.Key_Q:
                Qt.quit();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    Text {
        id: hint

        // **Nicht auf dem Telefon.** Er zaehlt Tastenkuerzel auf, und dort
        // gibt es keine Tastatur -- gedeckt hat er dafuer die Fusszeile, quer
        // ueber "naechster Block ... median ... BTC" und rechts
        // abgeschnitten. Am 08.09.2026 beim Kaltstart gesehen. `flash()`
        // darf weiter gerufen werden (eine angesteckte Tastatur waere ja
        // moeglich), es wird nur nichts sichtbar.
        visible: !win.ohneTastatur

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Auch dieser sitzt sonst hinter der Navigationsleiste.
        anchors.bottomMargin: 16 + flaeche.SafeArea.margins.bottom
        color: "#9a94a6"
        font.pixelSize: 11
        text: "1–6 Ansicht   ·   c Farbe · s Größe · i Blockangaben · l Legende · + − Deckkraft · F11 Vollbild"
        opacity: 0

        function flash() {
            opacity = 1;
            fade.restart();
        }

        Component.onCompleted: hint.flash()

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        Timer {
            id: fade

            interval: 2600
            onTriggered: hint.opacity = 0
        }
    }

    // **Im Vollbild zeigt ein Tipp den Knopf zum Verlassen.** Die Ansicht
    // bekommt den Tipp trotzdem: der Druck wird hier nur bemerkt und nicht
    // angenommen, er geht an das Element darunter weiter. Ein Knopf, der
    // immer da waere, laege auf der Uhr quer ueber "im Mempool" oder dem
    // Kurs -- genau dort, wo man an der Wand hinschaut.
    MouseArea {
        anchors.fill: parent
        z: 40
        enabled: win.vollbild
        onPressed: mouse => {
            vollKnopf.zeigen();
            mouse.accepted = false;
        }
    }

    Item {
        id: vollKnopf

        property bool gezeigt: false

        function zeigen() {
            gezeigt = true;
            ausblenden.restart();
        }

        visible: !win.bare
        z: 50
        width: 44
        height: 44
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: (win.vollbild ? 6 : 0) + flaeche.SafeArea.margins.top
        anchors.rightMargin: 6 + flaeche.SafeArea.margins.right
        opacity: win.vollbild ? (gezeigt ? 0.85 : 0) : 1
        enabled: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Timer {
            id: ausblenden

            interval: 3000
            onTriggered: vollKnopf.gezeigt = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: 18
            color: win.vollbild ? "#16131f" : "transparent"
        }

        // Vier Ecken, gezeichnet statt als Schriftzeichen: fuer U+26F6 hat
        // nicht jede Schrift eine Glyphe, und ein leeres Kaestchen stand
        // hier schon einmal statt des Bitcoin-Zeichens. Nach aussen weisend
        // heisst "hinein ins Vollbild", nach innen "heraus".
        Item {
            id: zeichen

            anchors.centerIn: parent
            width: 16
            height: 16

            Repeater {
                model: 4

                Item {
                    required property int index

                    width: 6
                    height: 6
                    x: index % 2 ? zeichen.width - width : 0
                    y: index >= 2 ? zeichen.height - height : 0
                    rotation: [0, 90, 270, 180][index] + (win.vollbild ? 180 : 0)

                    Rectangle {
                        width: parent.width
                        height: 2
                        color: "#9a94a6"
                    }

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: "#9a94a6"
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: win.vollbild = !win.vollbild
        }
    }
}
