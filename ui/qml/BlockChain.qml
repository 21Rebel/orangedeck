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

    property var blocks: []
    property var projected: []
    property string error: ""

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
            return "in ~" + min + " Min";
        var h = Math.floor(min / 60);
        return "in ~" + h + " Std " + (min % 60) + " Min";
    }

    implicitHeight: uiFont * 13.5

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

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        var m = Math.floor(s / 60);
        if (m < 1)
            return "gerade eben";
        if (m < 60)
            return "vor " + m + " Min";
        var h = Math.floor(m / 60);
        if (h < 48)
            return "vor " + h + " Std";
        return "vor " + Math.floor(h / 24) + " Tagen";
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
        var p = (root.projected || []).slice(0, 8);
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
        text: "Geplant  ·  bestätigt"
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

                        width: root.uiFont * 9
                        height: strip.height

                        Text {
                            id: etaLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.etaFor(pcell.modelData.rank)
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.85
                        }

                        BlockCard {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: etaLabel.bottom
                            anchors.topMargin: root.uiFont * 0.3
                            anchors.bottom: parent.bottom
                            tone: root.feeShade(pcell.modelData.medianFee)
                            hovered: parea.containsMouse
                            depth: root.uiFont * 0.45
                            cornerRadius: root.uiFont * 0.3

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - root.uiFont
                                spacing: root.uiFont * 0.18

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "~" + Math.round(pcell.modelData.medianFee) + " sat/vB"
                                    color: "#ffffff"
                                    font.pixelSize: root.uiFont
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (pcell.modelData.feeRange && pcell.modelData.feeRange.length)
                                        ? Math.round(pcell.modelData.feeRange[0]) + " – "
                                          + Math.round(pcell.modelData.feeRange[pcell.modelData.feeRange.length - 1])
                                        : ""
                                    color: Qt.rgba(1, 1, 1, 0.72)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.grp(pcell.modelData.nTx) + " Transaktionen"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (pcell.modelData.blockSize / 1e6).toFixed(2).replace(".", ",") + " MB"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (pcell.modelData.totalFees / 1e8).toFixed(3).replace(".", ",") + " BTC"
                                    color: Qt.rgba(1, 1, 1, 0.74)
                                    font.pixelSize: root.uiFont * 0.72
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

                    width: root.uiFont * 9
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
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: heightLabel.bottom
                        anchors.topMargin: root.uiFont * 0.3
                        anchors.bottom: parent.bottom
                        tone: root.minedColor
                        highlighted: cell.index === 0
                        hovered: area.containsMouse
                        depth: root.uiFont * 0.45
                        cornerRadius: root.uiFont * 0.3

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - root.uiFont
                            spacing: root.uiFont * 0.18

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.medianFee !== undefined
                                    ? "~" + Math.round(cell.ex.medianFee) + " sat/vB" : ""
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.pixelSize: root.uiFont * 0.75
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.reward
                                    ? (cell.ex.reward / 1e8).toFixed(3).replace(".", ",") + " BTC" : ""
                                color: "#ffffff"
                                font.pixelSize: root.uiFont * 0.95
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.grp(cell.modelData.tx_count) + " Transaktionen"
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (cell.modelData.size / 1024 / 1024).toFixed(2).replace(".", ",") + " MB"
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
        text: root.error.length ? root.error : "lädt …"
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }
}
