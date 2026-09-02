// Startseite des Explorers: Kennzahlen, die geplanten Bloecke aus dem Mempool,
// die Kette der bestaetigten Bloecke und die zuletzt gesehenen Transaktionen.
// Von hier fuehrt jeder Klick weiter hinein.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    // Sieht jemand auf die Startseite? Nur dann wird der geplante Block
    // mitverfolgt -- er kostet 7,8 kB/s, solange er laeuft.
    property bool live: true
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13

    signal blockPicked(string hash)
    signal txPicked(string txid)
    signal projectedPicked(int rank, var data)

    spacing: uiFont * 1.4

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

    // ------------------------------------------------------- Kennzahlen
    Flow {
        width: parent.width
        spacing: root.uiFont * 1.8

        Repeater {
            model: [
                { "k": "Blockhöhe", "v": root.feed ? root.grp(root.feed.tipHeight) : "–" },
                { "k": "Im Mempool", "v": root.feed ? root.grp(root.feed.mempoolCount) : "–" },
                { "k": "Gebühr", "v": root.feed && root.feed.feeFastest
                    ? root.feed.feeFastest.toFixed(1).replace(".", ",") + " sat/vB" : "–" },
                { "k": "Hashrate", "v": (root.feed && root.feed.hashrate.current)
                    ? Math.round(root.feed.hashrate.current / 1e18) + " EH/s" : "–" },
                { "k": "Schwierigkeit", "v": (root.feed && root.feed.difficulty.change !== undefined)
                    ? (root.feed.difficulty.change >= 0 ? "+" : "")
                      + root.feed.difficulty.change.toFixed(2).replace(".", ",") + " %" : "–" },
                { "k": "Kurs", "v": (root.feed && root.feed.price.eur)
                    ? root.grp(root.feed.price.eur) + " €" : "–" }
            ]

            Column {
                id: stat

                required property var modelData

                spacing: root.uiFont * 0.1

                Text {
                    text: stat.modelData.k
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                Text {
                    text: stat.modelData.v
                    color: root.textColor
                    font.pixelSize: root.uiFont * 1.25
                }
            }
        }
    }

    // Geplante und bestaetigte Bloecke in einer Leiste
    BlockChain {
        width: parent.width
        feed: root.feed
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onBlockPicked: function (hash) {
            root.blockPicked(hash);
        }
        onProjectedPicked: function (rank, data) {
            root.projectedPicked(rank, data);
        }
    }

    // ------------------------- der naechste Block, laufend mitgefuehrt
    ProjectedBlock {
        width: parent.width
        feed: root.feed
        live: root.live
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }

    // ------------------------------------------------------- Tafeln
    MainPanels {
        width: parent.width
        feed: root.feed
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.uiFont
        onTxPicked: function (txid) {
            root.txPicked(txid);
        }
    }

    // -------------------------------------- zuletzt gesehene Transaktionen
    Column {
        width: parent.width
        spacing: root.uiFont * 0.25
        visible: root.feed && (root.feed.snap.recent || []).length > 0

        Text {
            text: "Zuletzt im Mempool gesehen"
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.85
        }

        Repeater {
            model: {
                var r = (root.feed && root.feed.snap.recent) || [];
                return r.slice(-12).reverse();
            }

            Rectangle {
                id: trow

                required property var modelData

                width: parent.width
                height: root.uiFont * 2
                radius: 4
                color: tarea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: root.uiFont * 0.6
                    spacing: root.uiFont

                    Text {
                        width: root.uiFont * 14
                        elide: Text.ElideMiddle
                        text: trow.modelData.t || ""
                        color: root.textColor
                        font.pixelSize: root.uiFont * 0.85
                        font.family: "monospace"
                    }

                    Text {
                        width: root.uiFont * 6
                        text: trow.modelData.r !== undefined
                            ? trow.modelData.r.toFixed(2).replace(".", ",") + " sat/vB" : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }

                    Text {
                        // `a` ist der Betrag in sat, `v` die virtuelle Groesse
                        text: trow.modelData.a !== undefined
                            ? "₿ " + (trow.modelData.a / 1e8).toFixed(8).replace(".", ",") : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }
                }

                MouseArea {
                    id: tarea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: trow.modelData.t ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (trow.modelData.t)
                            root.txPicked(String(trow.modelData.t));
                    }
                }
            }
        }
    }
}
