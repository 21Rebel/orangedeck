// Rahmen um die Ansicht: Kopfzeile, Blockangaben, Grafik, Legende, Fusszeile.
// Reines QtQuick -- die Farben werden von aussen gesetzt, damit derselbe
// Baustein im DMS-Plugin und im eigenen Fenster laufen kann.
import QtQuick
import "colors.js" as Palette
import "txtype.js" as TxType

Item {
    id: root

    property var feed: null
    property bool paused: false
    property real density: 1.0
    property bool headerVisible: true
    property bool infoVisible: true
    property bool legendVisible: true
    // Untergrund hinter den Textangaben. Ohne ihn gehen sie im Zoom unter,
    // wenn grosse helle Kachelflaechen direkt dahinter liegen.
    // Kachel angetippt -- wird von FeedCanvas durchgereicht
    signal txActivated(string txid)
    // Der Wirt haelt die Lesart -- er merkt sie sich auch ueber Sitzungen
    signal colorModeRequested(string mode)
    property bool frostedInfo: true
    property bool frostedBlur: true
    property string colorMode: "age"
    property string sizeMode: "value"

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#c9a227"
    property color lineColor: "#2a2a38"
    property int baseFont: 12

    readonly property bool showHeader: headerVisible && height >= 108
    readonly property bool showFooter: height >= 168
    readonly property bool showInfo: infoVisible && width >= 480 && height >= 300
    // In flachen Flaechen (Dashboard-Tab) nur das Noetigste, sonst laeuft die
    // Spalte in die Halde hinein
    readonly property bool infoCompact: height < 520
    readonly property bool showLegend: legendVisible && width >= 420 && height >= 420
    readonly property var tip: feed ? feed.tip : ({})
    readonly property var nextBlock: feed ? feed.nextBlock : ({})
    readonly property var block: feed ? feed.block : ({})

    function grp(n) {
        if (n === undefined || n === null || isNaN(n))
            return "–";
        var s = String(Math.round(n)), out = "", c = 0;
        for (var i = s.length - 1; i >= 0; i--) {
            out = s[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function dec(n, digits) {
        if (n === undefined || n === null || isNaN(n))
            return "–";
        var parts = n.toFixed(digits).split(".");
        return grp(parseInt(parts[0], 10)) + (parts.length > 1 ? "," + parts[1] : "");
    }

    function fee(v) {
        if (!v)
            return "–";
        return (v < 10 ? dec(v, 2) : grp(v)) + " sat/vB";
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.round(Date.now() / 1000 - ts));
        if (s < 60)
            return "vor " + s + " s";
        return "vor " + Math.floor(s / 60) + " min";
    }

    function stamp(ts) {
        if (!ts)
            return "";
        var d = new Date(ts * 1000);
        return Qt.formatDateTime(d, "dd.MM.yyyy  HH:mm");
    }

    function fiat(sats) {
        var eur = feed && feed.price ? feed.price.eur : 0;
        if (!sats || !eur)
            return "";
        var v = sats / 1e8 * eur;
        if (v >= 1e9)
            return "≈ " + dec(v / 1e9, 2) + " Mrd €";
        if (v >= 1e6)
            return "≈ " + dec(v / 1e6, 0) + " Mio €";
        return "≈ " + grp(v) + " €";
    }

    // Blockanimation von Hand ausloesen (Taste b im eigenen Fenster) -- zum
    // Pruefen, ohne zehn Minuten auf den naechsten Block zu warten
    function triggerBlockAnimation() {
        canvasView.startBlockAnimation();
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: agoLabel.text = root.ago(root.tip.time)
    }

    // ------------------------------------------------------------ Kopfzeile
    // ------------------------------------------------ Untergrund der Angaben
    FrostedPanel {
        content: header
        backdropSource: canvasView
        blurred: root.frostedBlur
        visible: root.frostedInfo && header.visible
        z: 4
    }

    FrostedPanel {
        content: info
        backdropSource: canvasView
        blurred: root.frostedBlur
        visible: root.frostedInfo && info.visible
        z: 4
    }

    FrostedPanel {
        content: legend
        backdropSource: canvasView
        blurred: root.frostedBlur
        visible: root.frostedInfo && legend.visible
        z: 4
    }

    Item {
        id: header

        z: 5

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showHeader ? Math.round(root.baseFont * 2.4) : 0
        visible: root.showHeader

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                spacing: 6

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.feed && root.feed.online ? "#5cb946" : "#d33f3f"
                }

                Text {
                    text: "Block " + root.grp(root.tip.height)
                    color: root.textColor
                    font.pixelSize: root.baseFont + 2
                    font.weight: Font.DemiBold
                }
            }

            Text {
                id: agoLabel

                text: root.ago(root.tip.time)
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                anchors.right: parent.right
                text: root.grp(root.feed ? root.feed.mempoolCount : 0) + " im Mempool"
                color: root.textColor
                font.pixelSize: root.baseFont
            }

            Text {
                anchors.right: parent.right
                text: root.fee(root.feed ? root.feed.feeFastest : 0)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    FeedCanvas {
        id: canvasView
        
        onTxActivated: function (txid) { root.txActivated(txid); }

        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.showHeader ? 4 : 0

        feed: root.feed
        paused: root.paused
        density: root.density
        colorMode: root.colorMode
        sizeMode: root.sizeMode
        showBlock: height > 130
        gridColor: root.lineColor
        rulerColor: root.dimColor
        labelFont: root.baseFont - 1
    }

    // -------------------------------------------------- Angaben zum Block
    Column {
        id: info

        z: 5

        anchors.left: canvasView.left
        anchors.top: canvasView.top
        anchors.topMargin: Math.round(canvasView.height * (root.infoCompact ? 0.03 : 0.10))
        width: Math.min(160, root.width * 0.22)
        spacing: 2
        visible: root.showInfo && root.block.height !== undefined

        Text {
            text: "Letzter Block"
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: root.grp(root.block.height)
            color: root.textColor
            font.pixelSize: root.baseFont + 6
            font.weight: Font.DemiBold
        }

        Text {
            text: root.stamp(root.block.time)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        // Ohne Beschriftung war nicht zu erkennen, was die Zahl meint. Sie ist
        // die Summe **aller Ausgaenge dieses Blocks**, nicht der Mempool und
        // nicht "was den Besitzer gewechselt hat": Wechselgeld an den Absender
        // zaehlt mit, deshalb liegt sie regelmaessig ueber dem, was tatsaechlich
        // geflossen ist.
        Text {
            visible: !root.infoCompact
            text: "Bewegter Wert"
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: "₿ " + root.dec((root.block.totalValue || 0) / 1e8, 4)
            color: root.textColor
            font.pixelSize: root.baseFont
        }

        Text {
            visible: !root.infoCompact
            text: root.fiat(root.block.totalValue)
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: root.grp(root.block.size) + " Bytes"
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            text: root.grp(root.block.nTx) + " Transaktionen"
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
            bottomPadding: 6
        }

        Text {
            visible: !root.infoCompact
            text: "Ø Gebühr"
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Text {
            text: (root.infoCompact ? "Ø " : "") + root.dec(root.block.avgFeeRate, 2) + " sat/vByte"
            color: root.textColor
            font.pixelSize: root.baseFont - 1
        }

        Text {
            visible: !root.infoCompact
            text: root.block.pool || ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 6
        }
    }

    // ------------------------------------------------------------- Legende
    Column {
        id: legend

        z: 5

        anchors.right: canvasView.right
        anchors.top: canvasView.top
        anchors.topMargin: Math.round(canvasView.height * 0.10)
        spacing: 4
        visible: root.showLegend

        Text {
            anchors.right: parent.right
            text: root.sizeMode === "vbytes" ? "Größe (vByte)" : "Ausgabewert"
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        Repeater {
            model: root.sizeMode === "vbytes" ? ["< 256", "< 1.024", "< 2.304", "< 4.096", "< 6.400"] : ["< ₿ 0,01", "< ₿ 0,1", "< ₿ 1", "< ₿ 10", "< ₿ 100"]

            Row {
                spacing: 6
                anchors.right: parent.right

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                    font.family: "monospace"
                }

                Item {
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3 + index * 4
                        height: width
                        color: Palette.blockAgeColor()
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            text: root.colorMode === "type" ? "Art (nur im Block)"
                : (root.colorMode === "fee" ? "Gebühr sat/vB" : "Alter in Sekunden")
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
            topPadding: 4
        }

        // Farbtafel der Arten. Nur die, die im Block auch vorkommen.
        Repeater {
            model: {
                if (root.colorMode !== "type")
                    return [];
                var z = canvasView.blockTypeCounts || [];
                var out = [];
                for (var i = 0; i < z.length; i++) {
                    if (z[i] > 0)
                        out.push({ "i": i, "n": z[i] });
                }
                out.sort(function (a, b) {
                    return b.n - a.n;
                });
                return out;
            }

            Row {
                id: artZeile

                required property var modelData

                readonly property var meta: TxType.info(TxType.kindAt(artZeile.modelData.i))

                anchors.right: parent.right
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: artZeile.meta.label
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.baseFont - 3
                    height: width
                    radius: 2
                    color: artZeile.meta.color
                }
            }
        }

        Text {
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            visible: root.colorMode === "type"
            text: "Mempool: keine Art verfügbar\nDie Art ist gedeutet, nicht sicher"
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            topPadding: 2
        }

        Row {
            anchors.right: parent.right
            spacing: 4
            visible: root.colorMode !== "type"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "2" : "0"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }

            Rectangle {
                width: 90
                height: 8
                anchors.verticalCenter: parent.verticalCenter

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(2) : Palette.ageColor(0)
                    }

                    GradientStop {
                        position: 0.5
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(16) : Palette.ageColor(30000)
                    }

                    GradientStop {
                        position: 1
                        color: root.colorMode === "fee" ? Palette.feeColorForRate(128) : Palette.ageColor(60000)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorMode === "fee" ? "128+" : "60+"
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }
        }
    }

    // Umschalter fuer die Kachelfarbe. Dieselben Knoepfe wie im Explorer,
    // hier mit drei Lesarten: Alter, Gebuehr, Art.
    TileGoggles {
        id: goggles

        z: 6
        anchors.left: canvasView.left
        anchors.bottom: canvasView.bottom
        anchors.bottomMargin: root.baseFont * 0.5
        width: Math.min(canvasView.width * 0.6, root.baseFont * 26)
        visible: root.showLegend && root.width >= 420
        mode: root.colorMode
        modes: [
            { "k": "age", "l": "Alter" },
            { "k": "fee", "l": "Gebühr" },
            { "k": "type", "l": "Art" }
        ]
        // Die Farbtafel steht schon in der Legende rechts -- zweimal dasselbe
        // waere nur Rauschen. Hier bleibt der blosse Umschalter.
        counts: []
        total: 0
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.baseFont
        onPicked: function (m) {
            root.colorModeRequested(m);
        }
    }

    // ------------------------------------------------------------ Fusszeile
    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showFooter ? Math.round(root.baseFont * 1.9) : 0
        visible: root.showFooter

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: root.lineColor
            opacity: 0.6
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: "nächster Block ~" + root.grp(root.nextBlock.nTx) + " tx"
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: "· median " + root.fee(root.nextBlock.medianFee)
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.feed && root.feed.price && root.feed.price.eur ? "₿ " + root.grp(root.feed.price.eur) + " €" : ""
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }
    }

    // ---------------------------------------------------------- Tooltip
    // Zeigt beim Ueberfahren die Angaben zur Transaktion, wie auf bitfeed.live.
    // Ein- und Ausgaenge stehen nicht im Datenstrom und werden bei Bedarf
    // einzeln nachgeladen.
    property var inOutCache: ({})
    property string inOutKey: ""
    property string inOutText: ""

    function loadInOut(txid) {
        if (!txid)
            return;
        if (root.inOutCache[txid] !== undefined) {
            root.inOutText = root.inOutCache[txid];
            root.inOutKey = txid;
            return;
        }
        root.inOutKey = txid;
        root.inOutText = "";
        var req = new XMLHttpRequest();
        req.open("GET", "https://mempool.space/api/tx/" + txid);
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            var out = "";
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText);
                    var ni = (d.vin || []).length, no = (d.vout || []).length;
                    out = ni + (ni === 1 ? " Eingang" : " Eingänge") + "  ⟶  " + no + (no === 1 ? " Ausgang" : " Ausgänge");
                } catch (e) {}
            }
            root.inOutCache[txid] = out;
            if (root.inOutKey === txid)
                root.inOutText = out;
        };
        req.send();
    }

    Timer {
        id: inOutDelay

        interval: 350
        onTriggered: {
            var t = canvasView.hoveredTx;
            if (t && t.t)
                root.loadInOut(t.t);
        }
    }

    Connections {
        target: canvasView

        function onHoveredTxChanged() {
            var t = canvasView.hoveredTx;
            if (!t || !t.t) {
                inOutDelay.stop();
                root.inOutText = "";
                root.inOutKey = "";
                return;
            }
            if (root.inOutCache[t.t] !== undefined) {
                root.inOutKey = t.t;
                root.inOutText = root.inOutCache[t.t];
            } else {
                root.inOutText = "";
                inOutDelay.restart();
            }
        }
    }

    Rectangle {
        id: tip

        readonly property var tx: canvasView.hoveredTx

        visible: tx !== null && root.width > 300
        // Groesse aus dem Inhalt, aber ueber childrenRect statt ueber die
        // Spalte: waere die Spalte im Rechteck zentriert, haenge die Groesse
        // des Rechtecks an der Spalte und umgekehrt -- QML bricht diese
        // Abhaengigkeit auf und laesst beides bei null.
        width: tipCol.width + 20
        height: tipCol.height + 16
        radius: 6
        color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.97)
        border.width: 1
        border.color: Qt.lighter(root.lineColor, 1.6)
        z: 200

        x: Math.max(0, Math.min(root.width - width, canvasView.x + canvasView.hoverX + 14))
        y: Math.max(0, Math.min(root.height - height, canvasView.y + canvasView.hoverY - height - 12))

        Column {
            id: tipCol

            x: 10
            y: 8
            width: childrenRect.width
            height: childrenRect.height
            spacing: 3

            Text {
                text: tip.tx && tip.tx.t ? "TxID: " + String(tip.tx.t).substring(0, 20) + "…" : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 1
                font.family: "monospace"
            }

            // Gehoert die Transaktion zu einer beobachteten Wallet, ist das
            // die wichtigste Angabe an ihr -- also nach oben.
            Text {
                visible: tip.tx && tip.tx.m === 1
                text: "● gehört zu einer beobachteten Wallet"
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                visible: root.inOutText.length > 0
                text: root.inOutText
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? "Größe: " + root.dec(tip.tx.v, 2) + " vBytes" : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? "Gebührenrate: " + root.dec(tip.tx.r, 2) + " sat/vByte" : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? "Gebühr: " + root.grp(tip.tx.f) + " sats" : ""
                color: root.dimColor
                font.pixelSize: root.baseFont - 2
            }

            Text {
                text: tip.tx ? "Gesamtwert: ₿ " + (tip.tx.a / 1e8).toFixed(8).replace(".", ",") + "  " + root.fiat(tip.tx.a) : ""
                color: root.textColor
                font.pixelSize: root.baseFont - 2
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.feed !== null && !root.feed.online
        text: "keine Verbindung zum Feed"
        color: root.dimColor
        font.pixelSize: root.baseFont
    }
}
