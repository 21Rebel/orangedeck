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
    property real bgOpacity: 0.82
    // 0 = Feed, 1 = BlockClock, 2 = Miner. Wird gemerkt, damit ein Tablet
    // nach dem Einschalten gleich wieder als BlockClock hochkommt.
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
    }

    FeedState {
        id: feedState
    }

    // Umschalten auch mit der Maus, nicht nur mit 1/2/3
    ViewTabs {
        id: tabs

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        labels: ["Feed", "BlockClock", "Miner"]
        current: win.view
        fontSize: 13
        z: 30
        onPicked: function (i) {
            win.view = i;
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
        sizeMode: win.sizeMode
        infoVisible: win.showInfo
        legendVisible: win.showLegend
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

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_C:
                win.colorMode = win.colorMode === "age" ? "fee" : "age";
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
                win.view = event.key - Qt.Key_1;
                hint.flash();
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
        text: "1 Feed · 2 BlockClock · 3 Miner   ·   c Farbe · s Größe · i Blockangaben · l Legende · + − Deckkraft · F11 Vollbild"
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
