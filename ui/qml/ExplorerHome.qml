// Startseite des Explorers: Kennzahlen, die geplanten Bloecke aus dem Mempool,
// die Kette der bestaetigten Bloecke und die zuletzt gesehenen Transaktionen.
// Von hier fuehrt jeder Klick weiter hinein.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    // Sieht jemand auf die Startseite? Nur dann wird der geplante Block
    // mitverfolgt -- er kostet 7,8 kB/s, solange er laeuft.
    property bool live: true
    property string colorMode: "fee"
    property string currency: "eur"
    // Welche Abschnitte die Startseite zeigt. Leer heisst alle.
    property var parts: []
    property var panelIds: []

    function zeigt(id) {
        var f = root.parts;
        if (!f || !f.length || typeof f.indexOf !== "function")
            return true;
        return f.indexOf(id) >= 0;
    }
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property string lang: "de"

    signal blockPicked(string hash)
    signal txPicked(string txid)
    signal projectedPicked(int rank, var data)
    signal colorModeRequested(string mode)
    signal historyPicked()

    spacing: uiFont * 1.4

    // Tausendertrennung in der Schreibweise der Sprache -- Deutsch nimmt den
    // Punkt, Englisch das Komma. Das ist keine Kosmetik: "1.234" heisst je
    // nach Sprache tausendzweihundert oder eins Komma zwei.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    // ------------------------------------------------------- Kennzahlen
    Flow {
        width: parent.width
        visible: root.zeigt("stats")
        spacing: root.uiFont * 1.8

        Repeater {
            model: [
                { "k": Tr.t("blockHeight", root.lang), "v": root.feed ? root.grp(root.feed.tipHeight) : "–" },
                { "k": Tr.t("explorer.inMempool", root.lang), "v": root.feed ? root.grp(root.feed.mempoolCount) : "–" },
                { "k": Tr.t("fee", root.lang), "v": root.feed && root.feed.feeFastest
                    ? Tr.fixed(root.feed.feeFastest, 1, root.lang) + " sat/vB" : "–" },
                { "k": Tr.t("hashrate", root.lang), "v": (root.feed && root.feed.hashrate.current)
                    ? Math.round(root.feed.hashrate.current / 1e18) + " EH/s" : "–" },
                { "k": Tr.t("difficulty", root.lang), "v": (root.feed && root.feed.difficulty.change !== undefined)
                    ? (root.feed.difficulty.change >= 0 ? "+" : "")
                      + Tr.fixed(root.feed.difficulty.change, 2, root.lang) + " %" : "–" },
                { "k": Tr.t("price", root.lang), "v": root.feed
                    ? Tr.price1(Money.rate(root.feed.price, root.currency),
                                Money.symbol(Money.actual(root.feed.price, root.currency)),
                                root.lang) : "–" }
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
        visible: root.zeigt("chain")
        feed: root.feed
        lang: root.lang
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

    // Weiter zurueck als die Leiste reicht
    Text {
        id: historieLink

        visible: root.zeigt("chain")
        text: Tr.t("explorer.browseAll", root.lang)
        color: historieMaus.containsMouse ? root.accentColor : root.dimColor
        font.pixelSize: root.uiFont * 0.85

        MouseArea {
            id: historieMaus

            anchors.fill: parent
            anchors.margins: -root.uiFont * 0.3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.historyPicked()
        }
    }

    // ------------------------- der naechste Block, laufend mitgefuehrt
    ProjectedBlock {
        width: parent.width
        visible: root.zeigt("next")
        feed: root.feed
        live: root.live && root.zeigt("next")
        colorMode: root.colorMode
        lang: root.lang
        onColorModeRequested: function (m) {
            root.colorModeRequested(m);
        }
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
        visible: root.zeigt("panels")
        panels: root.panelIds
        lang: root.lang
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
        visible: root.zeigt("recent") && root.feed
                 && (root.feed.snap.recent || []).length > 0

        Text {
            text: Tr.t("explorer.recent", root.lang)
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
                            ? Tr.fixed(trow.modelData.r, 2, root.lang) + " sat/vB" : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }

                    Text {
                        // `a` ist der Betrag in sat, `v` die virtuelle Groesse
                        text: trow.modelData.a !== undefined
                            ? "₿ " + Tr.fixed(trow.modelData.a / 1e8, 8, root.lang) : ""
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
