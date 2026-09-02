// Der geplante Block, lebendig: die Kachelgrafik dessen, was gerade als
// naechstes in einen Block passen wuerde -- und was sich daran aendert.
//
// Zwei Quellen, beide ueber den Daemon:
//
//   die Kennzahlen  aus dem Zustand (`feed.projected`). Sie kommen ueber den
//                   WebSocket herein und stehen damit ohne eigene Abfrage
//                   bereit, im Takt des Zustands.
//   die Kacheln     ueber `/lookup/projectedtiles/<rang>`. Erst die Abfrage
//                   laesst den Daemon `track-mempool-block` abonnieren; hoert
//                   sie auf, meldet er sich nach zwanzig Sekunden von selbst
//                   wieder ab. Deshalb wird **nur gefragt, solange jemand
//                   hinsieht** -- der Strom kostet 7,8 kB/s.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    property int rank: 0
    // Sieht jemand hin? Ohne das laeuft die Abfrage im Verborgenen weiter --
    // genau der Fehler, der den Dashboard-Tab 7,4 % CPU gekostet hat.
    property bool live: true
    property int refreshMs: 2000
    property bool showHeader: true
    property real tileHeight: 0

    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13

    signal txPicked(string txid)

    // Die Kennzahlen kommen aus dem Zustand und aendern sich damit laufend.
    readonly property var info: (feed && feed.projected && feed.projected.length > rank)
        ? feed.projected[rank] : null
    // Der letzte geplante Block ist ein Sammelposten: dort steckt der ganze
    // Rest des Mempools, oft ein Vielfaches einer Blockgroesse.
    readonly property bool sammelposten: info && info.blockVSize > 1.05e6

    property var tiles: null
    // Der Stand, auf den sich die naechste Abfrage bezieht. Der Daemon
    // schickt dann nur die Aenderungen seitdem.
    property int seq: 0
    property string error: ""
    property bool busy: false
    property bool unveraendert: false
    property bool __pending: false

    spacing: uiFont * 0.5

    function grp(n) {
        if (n === undefined || n === null)
            return "–";
        var t = String(Math.round(n)), out = "", c = 0;
        for (var i = t.length - 1; i >= 0; i--) {
            out = t[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function refresh() {
        if (!root.feed || root.__pending || !root.live)
            return;
        root.__pending = true;
        if (root.tiles === null)
            root.busy = true;
        var r = root.rank;
        // Beim ersten Mal die Vollform, danach nur noch die Aenderungen.
        var frage = String(r) + ((root.tiles && root.seq > 0) ? "-" + root.seq : "");
        root.feed.lookup("projectedtiles", frage, function (d, err) {
            root.__pending = false;
            root.busy = false;
            if (r !== root.rank)
                return;
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.seq = d.seq || 0;
            if (d.full || !root.tiles) {
                root.unveraendert = false;
                root.tiles = d;
                return;
            }
            // Nichts passiert -- dann auch nichts neu rechnen und nichts neu
            // zeichnen.
            if (!(d.txs && d.txs.length) && !(d.removed && d.removed.length)) {
                root.unveraendert = true;
                return;
            }
            root.unveraendert = false;
            // Schlaegt das Einarbeiten fehl (etwa weil noch keine Packung
            // steht), beim naechsten Mal die Vollform holen.
            if (!tileView.applyDelta(d))
                root.seq = 0;
        });
    }

    onRankChanged: {
        root.tiles = null;
        root.seq = 0;
        root.error = "";
        refresh();
    }

    onLiveChanged: {
        if (root.live)
            refresh();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: root.refreshMs
        repeat: true
        running: root.live && root.feed !== null
        onTriggered: root.refresh()
    }

    // ----------------------------------------------------------- Kopfzeile
    Item {
        width: parent.width
        height: root.showHeader ? headRow.height : 0
        visible: root.showHeader

        Row {
            id: headRow

            spacing: root.uiFont * 0.5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.rank === 0 ? "Der nächste Block" : (root.rank + 1) + ". Block voraus"
                color: root.textColor
                font.pixelSize: root.uiFont * 1.05
            }

            // Der Punkt zeigt, dass mitgehoert wird. Bewusst **ohne**
            // Pulsschlag: eine endlose Animation haelt die Bildwiederholung
            // bei sechzig Bildern je Sekunde -- nachgemessen 5 % CPU fuer
            // einen Punkt von sechs Pixeln Kantenlaenge.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.uiFont * 0.45
                height: width
                radius: width / 2
                color: root.tiles ? "#2f9e63" : root.dimColor
                opacity: root.tiles ? 1 : 0.4
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.info
                    ? root.grp(root.info.nTx) + " Transaktionen · ~"
                      + root.info.medianFee.toFixed(1).replace(".", ",") + " sat/vB"
                    : ""
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.85
            }
        }
    }

    Text {
        width: parent.width
        visible: root.sammelposten && root.info !== null
        text: root.info
            ? "Sammelposten: der ganze übrige Mempool, rund "
              + Math.round(root.info.blockVSize / 1e6) + " Blöcke voll"
            : ""
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.8
    }

    // Was sich seit der letzten Abfrage getan hat
    Text {
        width: parent.width
        text: {
            if (root.error.length)
                return root.error;
            if (root.busy)
                return "Transaktionen werden geholt …";
            if (!root.tiles)
                return "";
            if (root.unveraendert || (tileView.addedCount === 0 && tileView.removedCount === 0))
                return "unverändert";
            var s = [];
            if (tileView.addedCount > 0)
                s.push("+" + tileView.addedCount + " hinzugekommen");
            if (tileView.removedCount > 0)
                s.push("−" + tileView.removedCount + " verdrängt");
            return s.join("  ·  ");
        }
        color: root.error.length ? "#e06c6c" : root.dimColor
        font.pixelSize: root.uiFont * 0.8
    }

    BlockTiles {
        id: tileView

        width: parent.width
        height: root.tileHeight > 0 ? root.tileHeight : Math.min(parent.width, root.uiFont * 34)
        visible: root.tiles !== null
        live: true
        block: root.tiles
        dimColor: root.dimColor
        labelSize: root.uiFont * 0.85
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }
}
