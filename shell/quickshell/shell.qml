// Eigenstaendiges Fenster: qs -p ~/.config/quickshell/BitcoinFeedApp
// oder bequemer ueber ~/.local/bin/btcfeed-window
import QtQuick
import Quickshell
import Quickshell.Io
import "strings.js" as Tr

ShellRoot {
    FloatingWindow {
        id: win

        title: "Bitcoin Feed"
        implicitWidth: 1100
        implicitHeight: 800
        minimumSize.width: 260
        minimumSize.height: 160
        // Deckkraft macht das Fenster selbst, den Blur macht niri (Regel in
        // ~/.config/niri/config.kdl). Kacheln und Schrift bleiben deckend.
        color: Qt.rgba(0.043, 0.043, 0.071, win.bgOpacity)

        property string colorMode: "age"
        property string sizeMode: "value"
        property bool showInfo: true
        property bool showLegend: true
        property bool showRuler: true
        property bool frosted: true
        property real bgOpacity: 0.82
        property real density: 1.0
        property int startView: -1
        property string currency: "eur"
        property string tileColorMode: "fee"
        property bool clockBars: true
        property var clockFields: []
        property var minerFields: []
        property bool showHeader: true
        property bool showFooter: true
        property bool showBlock: true
        property bool clockSpark: true
        property bool clockTime: false
        property bool minerChart: true
        property bool minerDomains: true
        property bool minerBoard: true
        property bool explorerLive: true
        property var explorerParts: []
        property var explorerPanels: []
        property string lang: "de"
        property var bigFields: ["height"]
        property int bigRotate: 0
        // Aus, bis sie in den Einstellungen ausdruecklich eingeschaltet wird
        property bool walletEnabled: false
        // 0 Feed, 1 BlockClock, 2 Miner, 3 Explorer, 4 Wallet, 5 Einstellungen
        property int view: 0

        readonly property var tabViews: walletEnabled ? [0, 1, 2, 3, 4, 5] : [0, 1, 2, 3, 5]
        readonly property var tabLabels: {
            var l = [Tr.t("tab.feed", lang), Tr.t("tab.clock", lang),
                     Tr.t("tab.miner", lang), Tr.t("tab.explorer", lang)];
            if (walletEnabled)
                l.push(Tr.t("tab.wallet", lang));
            l.push(Tr.t("tab.settings", lang));
            return l;
        }

        readonly property var opts: ({
            "bgOpacity": bgOpacity,
            "density": density,
            "startView": startView,
            "colorMode": colorMode,
            "sizeMode": sizeMode,
            "showInfo": showInfo,
            "showLegend": showLegend,
            "showRuler": showRuler,
            "frosted": frosted,
            "currency": currency,
            "tileColorMode": tileColorMode,
            "clockBars": clockBars,
            "clockFields": clockFields,
            "minerFields": minerFields,
            "showHeader": showHeader,
            "showFooter": showFooter,
            "showBlock": showBlock,
            "clockSpark": clockSpark,
            "clockTime": clockTime,
            "minerChart": minerChart,
            "minerDomains": minerDomains,
            "minerBoard": minerBoard,
            "explorerLive": explorerLive,
            "explorerParts": explorerParts,
            "explorerPanels": explorerPanels,
            "lang": lang,
            "bigFields": bigFields,
            "bigRotate": bigRotate,
            "walletEnabled": walletEnabled
        })

        function setOpt(key, value) {
            if (key === "bgOpacity")
                bgOpacity = value;
            else if (key === "density")
                density = value;
            else if (key === "startView")
                startView = value;
            else if (key === "colorMode")
                colorMode = value;
            else if (key === "sizeMode")
                sizeMode = value;
            else if (key === "showInfo")
                showInfo = value;
            else if (key === "showLegend")
                showLegend = value;
            else if (key === "showRuler")
                showRuler = value;
            else if (key === "frosted")
                frosted = value;
            else if (key === "currency")
                currency = value;
            else if (key === "tileColorMode")
                tileColorMode = value;
            else if (key === "clockBars")
                clockBars = value;
            else if (key === "clockFields")
                clockFields = value;
            else if (key === "minerFields")
                minerFields = value;
            else if (key === "showHeader")
                showHeader = value;
            else if (key === "showFooter")
                showFooter = value;
            else if (key === "showBlock")
                showBlock = value;
            else if (key === "clockSpark")
                clockSpark = value;
            else if (key === "clockTime")
                clockTime = value;
            else if (key === "minerChart")
                minerChart = value;
            else if (key === "minerDomains")
                minerDomains = value;
            else if (key === "minerBoard")
                minerBoard = value;
            else if (key === "explorerLive")
                explorerLive = value;
            else if (key === "explorerParts")
                explorerParts = value;
            else if (key === "explorerPanels")
                explorerPanels = value;
            else if (key === "lang")
                lang = value;
            else if (key === "bigFields")
                bigFields = value;
            else if (key === "bigRotate")
                bigRotate = value;
            else if (key === "walletEnabled") {
                walletEnabled = value;
                if (!value && view === 4)
                    view = 5;
            }
            save();
        }

        function save() {
            viewFile.setText(JSON.stringify({
                "colorMode": colorMode,
                "sizeMode": sizeMode,
                "showInfo": showInfo,
                "showLegend": showLegend,
                "bgOpacity": bgOpacity,
                "view": view,
                "showRuler": showRuler,
                "frosted": frosted,
                "density": density,
                "startView": startView,
                "currency": currency,
                "tileColorMode": tileColorMode,
                "clockBars": clockBars,
                "clockFields": clockFields,
                "minerFields": minerFields,
                "showHeader": showHeader,
                "showFooter": showFooter,
                "showBlock": showBlock,
                "clockSpark": clockSpark,
                "clockTime": clockTime,
                "minerChart": minerChart,
                "minerDomains": minerDomains,
                "minerBoard": minerBoard,
                "explorerLive": explorerLive,
                "explorerParts": explorerParts,
                "explorerPanels": explorerPanels,
                "lang": lang,
                "bigFields": bigFields,
                "bigRotate": bigRotate,
                "walletEnabled": walletEnabled
            }));
            hint.flash();
        }

        FileView {
            id: viewFile

            path: Quickshell.env("HOME") + "/.local/state/btcfeed/view.json"
            blockLoading: false
            atomicWrites: true
            printErrors: false

            onLoaded: {
                try {
                    var v = JSON.parse(text());
                    win.colorMode = v.colorMode || "age";
                    win.sizeMode = v.sizeMode || "value";
                    win.showInfo = v.showInfo !== false;
                    win.showLegend = v.showLegend !== false;
                    if (typeof v.bgOpacity === "number")
                        win.bgOpacity = Math.max(0.15, Math.min(1, v.bgOpacity));
                    if (typeof v.view === "number")
                        win.view = Math.max(0, Math.min(5, v.view));
                    if (typeof v.showRuler === "boolean")
                        win.showRuler = v.showRuler;
                    if (typeof v.frosted === "boolean")
                        win.frosted = v.frosted;
                    if (typeof v.density === "number")
                        win.density = Math.max(0.6, Math.min(2, v.density));
                    if (typeof v.startView === "number")
                        win.startView = Math.max(-1, Math.min(3, v.startView));
                    if (v.currency)
                        win.currency = v.currency;
                    if (v.tileColorMode)
                        win.tileColorMode = v.tileColorMode;
                    if (typeof v.clockBars === "boolean")
                        win.clockBars = v.clockBars;
                    if (Array.isArray(v.clockFields))
                        win.clockFields = v.clockFields;
                    if (Array.isArray(v.minerFields))
                        win.minerFields = v.minerFields;
                    if (typeof v.showHeader === "boolean")
                        win.showHeader = v.showHeader;
                    if (typeof v.showFooter === "boolean")
                        win.showFooter = v.showFooter;
                    if (typeof v.showBlock === "boolean")
                        win.showBlock = v.showBlock;
                    if (typeof v.clockSpark === "boolean")
                        win.clockSpark = v.clockSpark;
                    if (typeof v.clockTime === "boolean")
                        win.clockTime = v.clockTime;
                    if (typeof v.minerChart === "boolean")
                        win.minerChart = v.minerChart;
                    if (typeof v.minerDomains === "boolean")
                        win.minerDomains = v.minerDomains;
                    if (typeof v.minerBoard === "boolean")
                        win.minerBoard = v.minerBoard;
                    if (typeof v.explorerLive === "boolean")
                        win.explorerLive = v.explorerLive;
                    if (Array.isArray(v.explorerParts))
                        win.explorerParts = v.explorerParts;
                    if (Array.isArray(v.explorerPanels))
                        win.explorerPanels = v.explorerPanels;
                    if (v.lang)
                        win.lang = v.lang;
                    if (Array.isArray(v.bigFields))
                        win.bigFields = v.bigFields;
                    if (typeof v.bigRotate === "number")
                        win.bigRotate = v.bigRotate;
                    if (typeof v.walletEnabled === "boolean")
                        win.walletEnabled = v.walletEnabled;
                    if (win.view === 4 && !win.walletEnabled)
                        win.view = 0;
                } catch (e) {}
            }
        }

        FeedState {
            id: feedState
        }

        // Dieselben fuenf Ansichten wie in der eigenstaendigen Anwendung.
        // Zwei Fenster mit verschiedenem Inhalt waren nur verwirrend -- die
        // geteilten Bausteine haengen an nichts ausser Qt Quick, also laufen
        // sie hier genauso.
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
                win.save();
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
            colorMode: win.colorMode
            onColorModeRequested: function (m) {
                win.colorMode = m;
                win.save();
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
            onTxActivated: function (txid) {
                win.view = 3;
                explorer.go("tx", txid);
            }
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
                win.save();
            }
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
            live: visible
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: tabs.height + 14
            feed: feedState
            lang: win.lang
            currency: win.currency
            onTxPicked: function (txid) {
                win.view = 3;
                explorer.go("tx", txid);
            }
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
                    win.colorMode = win.colorMode === "age" ? "fee"
                        : (win.colorMode === "fee" ? "type" : "age");
                    win.save();
                    break;
                case Qt.Key_S:
                    win.sizeMode = win.sizeMode === "value" ? "vbytes" : "value";
                    win.save();
                    break;
                case Qt.Key_L:
                    win.showLegend = !win.showLegend;
                    win.save();
                    break;
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    win.bgOpacity = Math.min(1, win.bgOpacity + 0.05);
                    win.save();
                    break;
                case Qt.Key_Minus:
                    win.bgOpacity = Math.max(0.15, win.bgOpacity - 0.05);
                    win.save();
                    break;
                case Qt.Key_B:
                    panel.triggerBlockAnimation();
                    break;
                case Qt.Key_I:
                    win.showInfo = !win.showInfo;
                    win.save();
                    break;
                case Qt.Key_1:
                case Qt.Key_2:
                case Qt.Key_3:
                case Qt.Key_4:
                case Qt.Key_5:
                case Qt.Key_6:
                    var n = event.key - Qt.Key_1;
                    if (n < win.tabViews.length) {
                        win.view = win.tabViews[n];
                        win.save();
                    }
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
            text: "1–6 Ansicht · c Farbe · s Größe · i Blockangaben · l Legende · + − Deckkraft"
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
}
