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
    title: qsTr("Bitcoin Feed")

    // Deckkraft macht das Fenster selbst; ob geblurrt wird, entscheidet der
    // Compositor. Kacheln und Schrift bleiben deckend.
    color: Qt.rgba(0.043, 0.043, 0.071, win.bgOpacity)

    property string colorMode: "age"
    property string sizeMode: "value"
    property bool showInfo: true
    property bool showLegend: true
    property bool showRuler: true
    property bool frosted: true
    property real bgOpacity: 0.82
    property real density: 1.0
    // -1 heisst: die zuletzt benutzte Ansicht. Sonst faengt das Fenster
    // immer bei derselben an und merkt sich gar nichts mehr.
    property int startView: -1
    property string currency: "eur"
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
    property string lang: "de"
    // Grosse Anzeige der BlockClock -- als Zeichenkette abgelegt, siehe
    // die uebrigen Listen.
    property string bigFieldsRaw: "height"
    readonly property var bigFields: bigFieldsRaw.length ? bigFieldsRaw.split("|") : ["height"]
    property int bigRotate: 0
    property bool walletEnabled: false
    // 0 = Feed, 1 = BlockClock, 2 = Miner, 3 = Explorer, 4 = Wallet. Wird
    // gemerkt, damit ein Tablet nach dem Einschalten gleich wieder als
    // BlockClock hochkommt.
    property int view: 0

    // Bleibt auf dem Geraet: QSettings schreibt nach
    // ~/.config/btcfeed/btcfeed.conf (Linux) bzw. in den App-Speicher (Android).
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
        property alias currency: win.currency
        property alias tileColorMode: win.tileColorMode
        property alias clockBars: win.clockBars
        property alias clockFieldsRaw: win.clockFieldsRaw
        property alias minerFieldsRaw: win.minerFieldsRaw
        property alias showHeader: win.showHeader
        property alias showFooter: win.showFooter
        property alias showBlock: win.showBlock
        property alias clockSpark: win.clockSpark
        property alias clockTime: win.clockTime
        property alias minerChart: win.minerChart
        property alias minerDomains: win.minerDomains
        property alias minerBoard: win.minerBoard
        property alias explorerLive: win.explorerLive
        property alias explorerPartsRaw: win.explorerPartsRaw
        property alias explorerPanelsRaw: win.explorerPanelsRaw
        property alias lang: win.lang
        property alias bigFieldsRaw: win.bigFieldsRaw
        property alias bigRotate: win.bigRotate
        property alias walletEnabled: win.walletEnabled
    }

    // Beim Start in die gemerkte Ansicht -- fuer ein Tablet an der Wand ist
    // das meist die BlockClock. Der Reiter "Wallet" faellt weg, solange er
    // nicht eingeschaltet ist.
    Component.onCompleted: {
        if (win.startView >= 0 && win.startView <= 3)
            win.view = win.startView;
        // Ausgeschaltete Wallet-Ansicht darf nicht als leere Seite dastehen
        if (win.view === 4 && !win.walletEnabled)
            win.view = 0;
    }

    // Welche Reiter es gibt und welche Ansicht dahinter steckt
    readonly property var tabViews: win.walletEnabled ? [0, 1, 2, 3, 4, 5] : [0, 1, 2, 3, 5]
    readonly property var tabLabels: {
        var l = [Tr.t("tab.feed", win.lang), Tr.t("tab.clock", win.lang),
                 Tr.t("tab.miner", win.lang), Tr.t("tab.explorer", win.lang)];
        if (win.walletEnabled)
            l.push(Tr.t("tab.wallet", win.lang));
        l.push(Tr.t("tab.settings", win.lang));
        return l;
    }

    // Eine Einstellung setzen. Alles laeuft hier durch, damit es nur eine
    // Stelle gibt, an der etwas geaendert wird.
    function setOpt(key, value) {
        if (key === "bgOpacity")
            win.bgOpacity = value;
        else if (key === "density")
            win.density = value;
        else if (key === "startView")
            win.startView = value;
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
            win.lang = value;
        else if (key === "bigFields")
            win.bigFieldsRaw = (value || []).join("|");
        else if (key === "bigRotate")
            win.bigRotate = value;
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
        "minerChart": win.minerChart,
        "minerDomains": win.minerDomains,
        "minerBoard": win.minerBoard,
        "explorerLive": win.explorerLive,
        "explorerParts": win.explorerParts,
        "explorerPanels": win.explorerPanels,
        "lang": win.lang,
        "bigFields": win.bigFields,
        "bigRotate": win.bigRotate,
        "walletEnabled": win.walletEnabled
    })

    FeedState {
        id: feedState
    }

    // Umschalten auch mit der Maus, nicht nur mit 1/2/3
    ViewTabs {
        id: tabs

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        labels: win.tabLabels
        current: win.tabViews.indexOf(win.view)
        fontSize: 13
        z: 30
        onPicked: function (i) {
            win.view = win.tabViews[i];
        }
    }

    FeedPanel {
        id: panel

        visible: win.view === 0
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        feed: feedState
        lang: win.lang
        baseFont: 13
        // Klick auf eine Kachel fuehrt in den Explorer
        onTxActivated: function (txid) {
            win.view = 3;
            explorer.go("tx", txid);
        }
        colorMode: win.colorMode
        onColorModeRequested: function (m) {
            win.colorMode = m;
        }
        sizeMode: win.sizeMode
        headerVisible: win.showHeader
        footerVisible: win.showFooter
        blockVisible: win.showBlock
        currency: win.currency
        infoVisible: win.showInfo
        legendVisible: win.showLegend
        rulerVisible: win.showRuler
        frostedInfo: win.frosted
        frostedBlur: win.frosted
        density: win.density
    }

    ClockView {
        visible: win.view === 1
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        feed: feedState
        lang: win.lang
        fields: win.clockFields
        currency: win.currency
        showBars: win.clockBars
        showSpark: win.clockSpark
        showTime: win.clockTime
        bigFields: win.bigFields
        bigRotate: win.bigRotate
    }

    ExplorerView {
        id: explorer

        visible: win.view === 3
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        feed: feedState
        lang: win.lang
        tileColorMode: win.tileColorMode
        currency: win.currency
        homeParts: win.explorerParts
        homePanels: win.explorerPanels
        trackProjected: win.explorerLive
        onTileColorModeRequested: function (m) {
            win.tileColorMode = m;
        }
    }

    MinerView {
        visible: win.view === 2
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        feed: feedState
        lang: win.lang
        metricKeys: win.minerFields
        showChart: win.minerChart
        showDomains: win.minerDomains
        showBoard: win.minerBoard
    }

    SettingsView {
        visible: win.view === 5
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        opts: win.opts
        lang: win.lang
        onChanged: function (key, value) {
            win.setOpt(key, value);
        }
    }

    WatchView {
        visible: win.view === 4 && win.walletEnabled
        // Nur nachfragen, solange die Ansicht auch zu sehen ist
        live: visible
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: tabs.height + 14
        feed: feedState
        onTxPicked: function (txid) {
            win.view = 3;
            explorer.go("tx", txid);
        }
        currency: win.currency
        onAddressPicked: function (adr) {
            win.view = 3;
            explorer.go("address", adr);
        }
    }

    Item {
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
                panel.triggerBlockAnimation();
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
                if (n < win.tabViews.length) {
                    win.view = win.tabViews[n];
                    hint.flash();
                }
                break;
            case Qt.Key_F11:
                win.visibility = win.visibility === Window.FullScreen
                    ? Window.Windowed : Window.FullScreen;
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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
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
}
