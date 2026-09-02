// Die Kette in einer Leiste: links die geplanten Bloecke aus dem Mempool,
// rechts die bestaetigten -- dazwischen die Grenze zwischen "steht noch aus"
// und "steht fest". So sieht man unmittelbar, welcher Block als naechster
// bestaetigt wuerde.
//
// Reihenfolge wie im Original: die geplanten laufen von weit draussen nach
// innen, der naechste steht direkt an der Grenze; rechts davon der neueste
// bestaetigte, dann aelter werdend.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    // Die Farbe trennt den Zustand: gruen steht aus, violett steht fest.
    property color pendingColor: "#2f9e63"
    property color minedColor: "#7b5cd6"
    property real uiFont: 13
    property string lang: "de"

    property var blocks: []
    // Rueckfallweg: die geplanten Bloecke ueber REST. Gebraucht wird er nur,
    // solange der Zustand sie noch nicht mitfuehrt.
    property var projected: []
    property string error: ""

    // Bevorzugt aus dem Zustand -- die kommen ueber den WebSocket herein und
    // aendern sich damit im Takt des Feeds, ohne eigene Abfrage.
    readonly property var projectedNow: (root.feed && root.feed.projected
                                         && root.feed.projected.length)
        ? root.feed.projected : root.projected

    signal blockPicked(string hash)
    // Ein geplanter Block hat keinen Hash -- er wird ueber seinen Rang
    // gemeldet (0 = der naechste).
    signal projectedPicked(int rank, var data)

    // Wie lange es voraussichtlich bis zu diesem geplanten Block dauert.
    // Grundlage ist die **gemessene** durchschnittliche Blockzeit aus der
    // Schwierigkeitsanpassung, nicht die nominellen zehn Minuten.
    function etaFor(rank) {
        var avg = (root.feed && root.feed.difficulty.timeAvg) || 600000;
        var min = Math.round((rank + 1) * avg / 60000);
        if (min < 60)
            return Tr.t("in.min", root.lang, min);
        var h = Math.floor(min / 60);
        return Tr.t("in.hourMin", root.lang, h, min % 60);
    }

    implicitHeight: uiFont * 13.5

    // Die Kacheln sind **quadratisch**. Vorher fuellten sie den Streifen und
    // wurden dabei hochkant -- ein Block ist aber keine Saeule. Die Kantenlaenge
    // ist das Kleinere aus Spaltenbreite und dem, was unter der Beschriftung
    // uebrig bleibt.
    readonly property real cellWidth: uiFont * 9
    readonly property real cardSide: Math.max(uiFont * 4,
        Math.min(cellWidth, implicitHeight - uiFont * 3.2))

    // Tausendertrennung in der Schreibweise der Sprache -- Deutsch nimmt den
    // Punkt, Englisch das Komma. Das ist keine Kosmetik: "1.234" heisst je
    // nach Sprache tausendzweihundert oder eins Komma zwei.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    // Gebuehren unter 10 sat/vB brauchen eine Nachkommastelle. Gerundet steht
    // sonst bei jedem Block "~0 sat/vB" und als Spanne "0 – 0" -- genau in den
    // ruhigen Zeiten, in denen die Zahl interessant waere.
    function fee(n) {
        if (n === undefined || n === null)
            return "–";
        return n >= 10 ? String(Math.round(n)) : Tr.fixed(n, 1, root.lang);
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        var m = Math.floor(s / 60);
        if (m < 1)
            return Tr.t("ago.now", root.lang);
        if (m < 60)
            return Tr.t("ago.min", root.lang, m);
        var h = Math.floor(m / 60);
        if (h < 48)
            return Tr.t("ago.hour", root.lang, h);
        return Tr.t("ago.day", root.lang, Math.floor(h / 24));
    }

    // Abgestuft nach Gebuehr, im selben Gruen -- der naechste Block traegt die
    // hoechsten Gebuehren und leuchtet am staerksten.
    function feeShade(medianFee) {
        var f = Math.max(0, Math.min(1, (medianFee || 0) / 12));
        return Qt.hsva(root.pendingColor.hsvHue, 0.45 + 0.3 * f, 0.34 + 0.30 * f, 1);
    }

    function reload() {
        if (!root.feed)
            return;
        root.feed.lookup("blocks", "recent", function (d, err) {
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.blocks = d || [];
        });
        // Nur fragen, wenn der Zustand nichts liefert -- sonst ist die Abfrage
        // eine Doppelung dessen, was ohnehin schon da ist.
        if (!(root.feed.projected && root.feed.projected.length))
            root.feed.lookup("mempoolblocks", "now", function (d, err) {
                if (!err)
                    root.projected = d || [];
            });
    }

    Component.onCompleted: reload()

    Connections {
        target: root.feed
        enabled: root.feed !== null
        function onBlockMined() {
            reloadTimer.restart();
        }
    }

    Timer {
        id: reloadTimer

        interval: 4000
        onTriggered: root.reload()
    }

    // Der naechste Block steht rechts an der Grenze, die ferneren links davon
    readonly property var projectedShown: {
        var p = (root.projectedNow || []).slice(0, 8);
        var out = [];
        // Umgedreht, damit der naechste rechts an der Grenze steht -- der
        // urspruengliche Rang wird dabei mitgefuehrt.
        for (var i = p.length - 1; i >= 0; i--) {
            var e = {};
            for (var k in p[i])
                e[k] = p[i][k];
            e.rank = i;
            out.push(e);
        }
        return out;
    }

    Text {
        id: label

        anchors.left: parent.left
        anchors.top: parent.top
        text: Tr.t("chain.label", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }

    Flickable {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: label.bottom
        anchors.topMargin: root.uiFont * 0.5
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        // Beim ersten Aufbau an die Grenze rollen -- dort spielt die Musik
        onContentWidthChanged: {
            if (contentWidth > width && contentX === 0)
                contentX = Math.max(0, pending.width - width * 0.45);
        }

        Row {
            id: row

            spacing: root.uiFont * 0.55

            // ------------------------------------------------ geplant
            Row {
                id: pending

                spacing: root.uiFont * 0.55

                Repeater {
                    model: root.projectedShown

                    Item {
                        id: pcell

                        required property var modelData

                        width: root.cellWidth
                        height: strip.height

                        Text {
                            id: etaLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.etaFor(pcell.modelData.rank)
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.85
                        }

                        BlockCard {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: etaLabel.bottom
                            anchors.topMargin: root.uiFont * 0.3
                            width: root.cardSide
                            height: root.cardSide
                            tone: root.feeShade(pcell.modelData.medianFee)
                            hovered: parea.containsMouse
                            cornerRadius: root.uiFont * 0.3

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - root.uiFont
                                spacing: root.uiFont * 0.18

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "~" + root.fee(pcell.modelData.medianFee) + " sat/vB"
                                    color: "#ffffff"
                                    font.pixelSize: root.uiFont
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (pcell.modelData.feeRange && pcell.modelData.feeRange.length)
                                        ? root.fee(pcell.modelData.feeRange[0]) + " – "
                                          + root.fee(pcell.modelData.feeRange[pcell.modelData.feeRange.length - 1])
                                        : ""
                                    color: Qt.rgba(1, 1, 1, 0.72)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.t("txlist.count", root.lang, root.grp(pcell.modelData.nTx))
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.fixed((pcell.modelData.blockSize / 1e6), 2, root.lang) + " MB"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Tr.fixed((pcell.modelData.totalFees / 1e8), 3, root.lang) + " BTC"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }
                            }

                            // Fuellstand. Er ist das Einzige an der Kachel, das
                            // sich sichtbar bewegt, und zeigt, dass die Reihe
                            // lebt -- der letzte Block ist der Sammelposten und
                            // deshalb immer randvoll.
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: root.uiFont * 0.4
                                height: root.uiFont * 0.28
                                // Nur zeigen, wenn er etwas zu sagen hat: ein
                                // randvoller Block ist der Normalfall, und ein
                                // immer voller Balken ist eine Zierlinie.
                                visible: pcell.modelData.blockVSize !== undefined
                                         && pcell.modelData.blockVSize < 0.99e6

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.28)
                                }

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1,
                                        (pcell.modelData.blockVSize || 0) / 1e6))
                                    height: parent.height
                                    radius: height / 2
                                    color: Qt.rgba(1, 1, 1, 0.7)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: parea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.projectedPicked(pcell.modelData.rank, pcell.modelData)
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------- die Grenze
            Item {
                width: root.uiFont * 1.6
                height: strip.height
                visible: root.projectedShown.length > 0 && root.blocks.length > 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: root.uiFont * 1.8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.uiFont * 0.4
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.18)
                }
            }

            // --------------------------------------------- bestaetigt
            Repeater {
                model: root.blocks

                Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property var ex: cell.modelData.extras || ({})

                    width: root.cellWidth
                    height: strip.height

                    Text {
                        id: heightLabel

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.grp(cell.modelData.height)
                        color: root.accentColor
                        font.pixelSize: root.uiFont * 0.95
                        font.bold: true
                    }

                    BlockCard {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: heightLabel.bottom
                        anchors.topMargin: root.uiFont * 0.3
                        width: root.cardSide
                        height: root.cardSide
                        tone: root.minedColor
                        highlighted: cell.index === 0
                        hovered: area.containsMouse
                        cornerRadius: root.uiFont * 0.3

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - root.uiFont
                            spacing: root.uiFont * 0.18

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.medianFee !== undefined
                                    ? "~" + root.fee(cell.ex.medianFee) + " sat/vB" : ""
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: root.uiFont * 0.75
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.reward
                                    ? Tr.fixed((cell.ex.reward / 1e8), 3, root.lang) + " BTC" : ""
                                color: "#ffffff"
                                font.pixelSize: root.uiFont * 0.95
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tr.t("txlist.count", root.lang, root.grp(cell.modelData.tx_count))
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tr.fixed((cell.modelData.size / 1024 / 1024), 2, root.lang) + " MB"
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.ago(cell.modelData.timestamp)
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: (cell.ex.pool && cell.ex.pool.name) || ""
                                color: Qt.rgba(1, 1, 1, 0.92)
                                font.pixelSize: root.uiFont * 0.72
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.blockPicked(cell.modelData.id)
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.blocks.length === 0
        text: root.error.length ? root.error : Tr.t("loading", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }
}
