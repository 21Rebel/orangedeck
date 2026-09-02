// Eigenstaendiges Fenster: qs -p ~/.config/quickshell/BitcoinFeedApp
// oder bequemer ueber ~/.local/bin/btcfeed-window
import QtQuick
import Quickshell
import Quickshell.Io

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
        property real bgOpacity: 0.82
        // 0 Feed, 1 BlockClock, 2 Miner, 3 Explorer, 4 Wallet
        property int view: 0

        function save() {
            viewFile.setText(JSON.stringify({
                "colorMode": colorMode,
                "sizeMode": sizeMode,
                "showInfo": showInfo,
                "showLegend": showLegend,
                "bgOpacity": bgOpacity,
                "view": view
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
                        win.view = Math.max(0, Math.min(4, v.view));
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
            labels: ["Feed", "BlockClock", "Miner", "Explorer", "Wallet"]
            current: win.view
            fontSize: 13
            z: 30
            onPicked: function (i) {
                win.view = i;
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
            baseFont: 13
            colorMode: win.colorMode
            onColorModeRequested: function (m) {
                win.colorMode = m;
                win.save();
            }
            sizeMode: win.sizeMode
            infoVisible: win.showInfo
            legendVisible: win.showLegend
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
        }

        MinerView {
            visible: win.view === 2
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: tabs.height + 14
            feed: feedState
        }

        ExplorerView {
            id: explorer

            visible: win.view === 3
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: tabs.height + 14
            feed: feedState
        }

        WatchView {
            visible: win.view === 4
            live: visible
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: tabs.height + 14
            feed: feedState
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
                    win.view = event.key - Qt.Key_1;
                    win.save();
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
            text: "1–5 Ansicht · c Farbe · s Größe · i Blockangaben · l Legende · + − Deckkraft"
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
