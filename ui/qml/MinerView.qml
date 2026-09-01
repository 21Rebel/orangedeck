// Eigene Miner. Zeigt, was die Geraete melden, und stellt die erreichte
// Schwierigkeit der des Netzes gegenueber -- das ist die Zahl, um die es beim
// Solomining eigentlich geht.
//
// Bewusst **nicht** auf ein Geraet festgelegt: der Daemon spricht AxeOS
// (Bitaxe, NerdAxe und die uebrigen ESP-Miner-Abkoemmlinge) und die
// cgminer-Schnittstelle (Antminer, Avalon, Whatsminer und Nachbauten) und
// liefert beides normalisiert, Hashrate in H/s. Mehrere Geraete zugleich sind
// vorgesehen.
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
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))

    readonly property var miners: feed ? feed.miners : []
    readonly property var total: feed ? feed.minerTotal : ({})
    readonly property bool configured: feed ? feed.minerConfigured : false
    readonly property bool anyOnline: feed ? feed.minerOnline : false
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0
    readonly property real bestShare: (netDiff > 0 && total.bestDiff)
        ? total.bestDiff / netDiff : 0
    // Bei genau einem Geraet ist Platz fuer die Einzelheiten
    readonly property var one: (miners.length === 1 && miners[0].online) ? miners[0] : null
    readonly property var oneHist: (one && feed) ? (feed.minerHistory[one.id] || ({})) : ({})
    // Platz ist knapp im Dashboard-Tab -- dort bleiben Kurve und Bestenliste weg
    readonly property bool roomForChart: height > 330
    readonly property bool roomForBoard: height > 460

    function big(n, unit) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return (n >= 100 ? n.toFixed(0) : n.toFixed(2)).replace(".", ",")
             + " " + u[i] + (unit || "");
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600),
            m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return d + (d === 1 ? " Tag " : " Tage ") + h + " Std";
        if (h > 0)
            return h + " Std " + m + " Min";
        return m + " Min";
    }

    // Zu den Einstellungen geht es in AxeOS -- die bleiben dort, hier wird nur
    // angezeigt. Der Knopf oeffnet die Weboberflaeche des Geraets.
    Rectangle {
        id: openBtn

        anchors.top: parent.top
        anchors.right: parent.right
        visible: root.one !== null && root.one.type === "axeos"
        width: openLabel.width + root.scaleUnit * 0.9
        height: openLabel.height + root.scaleUnit * 0.45
        radius: height / 2
        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        z: 20

        Text {
            id: openLabel

            anchors.centerIn: parent
            text: "AxeOS öffnen ↗"
            color: root.textColor
            font.pixelSize: root.scaleUnit * 0.58
        }

        MouseArea {
            id: openArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.one)
                    Qt.openUrlExternally(root.one.id);
            }
        }
    }

    // ---------------------------------------------------- kein Geraet bekannt
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.86
        spacing: root.scaleUnit * 0.45
        visible: !root.configured

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Kein Miner eingetragen"
            color: root.textColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Die Geräte hängen meist im WLAN und bekommen ihre Adresse "
                  + "per DHCP. Deshalb suchen statt eintragen:"
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "btcfeed --discover-miners --write\nsystemctl --user restart btcfeed"
            horizontalAlignment: Text.AlignHCenter
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 0.62
            font.family: "monospace"
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Erkannt werden AxeOS-Geräte (Bitaxe, NerdAxe …) und alles, "
                  + "was die cgminer-Schnittstelle spricht (Antminer, Avalon, "
                  + "Whatsminer …)."
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.55
        }
    }

    // ------------------------------------------- eingetragen, aber alle aus
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.35
        visible: root.configured && !root.anyOnline

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.miners.length === 1 ? "Miner nicht erreichbar"
                                           : "Kein Miner erreichbar"
            color: root.badColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Die Geräte sind vermutlich aus."
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }
    }

    // ------------------------------------------------------------- im Betrieb
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.9
        spacing: root.scaleUnit * 0.45
        visible: root.anyOnline

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.total.online > 1
                ? root.total.online + " Geräte" : (root.miners[0] ? root.miners[0].name : "Miner")
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.72
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.big(root.total.hashRate, "H/s")
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 2.6
            font.bold: true
        }

        // Die Momentanrate schwankt um rund zehn Prozent -- oben steht deshalb
        // der geglaettete Zehnminutenwert, hier der Vergleich mit dem, was das
        // Geraet bei seiner Taktung erwarten laesst.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.one && root.one.expected
            text: root.one && root.one.expected
                ? "geglättet über 10 min · erwartet " + root.big(root.one.expected, "H/s")
                : ""
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.55
        }

        // Der Grund, warum man das ueberhaupt macht
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.one && root.one.blockFound > 0
            width: blockText.width + root.scaleUnit
            height: blockText.height + root.scaleUnit * 0.4
            radius: height / 2
            color: root.goodColor

            Text {
                id: blockText

                anchors.centerIn: parent
                text: root.one && root.one.blockFound > 0
                    ? (root.one.blockFound === 1 ? "1 Block gefunden"
                                                 : root.one.blockFound + " Blöcke gefunden")
                    : ""
                color: "#0b0b12"
                font.pixelSize: root.scaleUnit * 0.62
                font.bold: true
            }
        }

        // Die eigentliche Zahl beim Solomining
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.15

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Beste Freigabe gegen Netzschwierigkeit"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.total.bestDiff
                    ? root.big(root.total.bestDiff) + " von " + root.big(root.netDiff)
                    : "–"
                color: root.textColor
                font.pixelSize: root.scaleUnit * 0.95
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.bestShare > 0
                // Winzige Anteile -- "1 zu N" liest sich besser als eine
                // Prozentzahl mit acht Nullen.
                text: root.bestShare >= 1
                    ? "das reicht für einen Block"
                    : "das ist 1 zu " + root.big(1 / root.bestShare)
                color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.3
        }

        // --------------------------------------- Einzelheiten, ein Geraet
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.2
            visible: root.one !== null

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.scaleUnit * 1.1

                Repeater {
                    model: root.one ? [
                        { "k": "Temperatur", "v": root.one.temp !== undefined && root.one.temp !== null
                            ? Math.round(root.one.temp) + " °C" : "–" },
                        { "k": "Leistung", "v": root.one.power ? root.one.power.toFixed(1).replace(".", ",") + " W" : "–" },
                        { "k": "Lüfter", "v": root.one.fanRpm ? root.one.fanRpm + " U/min" : "–" },
                        { "k": "Fehlerquote", "v": root.one.errorPct !== undefined && root.one.errorPct !== null
                            ? root.one.errorPct.toFixed(1).replace(".", ",") + " %" : "–" },
                        { "k": "Freigaben", "v": root.one.shares !== undefined
                            ? String(root.one.shares) + (root.one.rejected ? " (" + root.one.rejected + " abgelehnt)" : "") : "–" },
                        { "k": "Laufzeit", "v": root.span(root.one.uptime) }
                    ] : []

                    Column {
                        id: cell

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.8
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // Nur der Wirt des Pools -- der Benutzername enthaelt beim
                // Solomining die Auszahlungsadresse und wird nirgends angezeigt.
                text: root.one
                    ? [root.one.model, root.one.version, root.one.pool].filter(function (x) {
                          return !!x;
                      }).join(" · ")
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }
        }

        // ------------------------------------------------------- Verlauf
        MinerChart {
            width: parent.width
            height: root.scaleUnit * 4.2
            visible: root.one !== null && root.roomForChart
                     && (root.oneHist.hr || []).length > 1
            hist: root.oneHist
            lineColor: root.accentColor
            dimColor: root.dimColor
            labelSize: root.scaleUnit * 0.5
        }

        // ------------------------------------------ Rechenwerke einzeln
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.15
            visible: root.one !== null && (root.one.domains || []).length > 0
                     && root.roomForChart

            Text {
                text: "Rechenwerke"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            Row {
                width: parent.width
                spacing: root.scaleUnit * 0.25

                Repeater {
                    model: root.one ? root.one.domains : []

                    Rectangle {
                        id: dom

                        required property var modelData
                        required property int index

                        width: (root.width * 0.9 - root.scaleUnit * 0.75) / Math.max(1, (root.one.domains || []).length)
                        height: root.scaleUnit * 0.95
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.06)

                        Rectangle {
                            // Anteil am staerksten Rechenwerk -- so sieht man
                            // sofort, wenn eines abfaellt.
                            width: parent.width * Math.max(0.05, Math.min(1,
                                dom.modelData / Math.max.apply(null, root.one.domains)))
                            height: parent.height
                            radius: parent.radius
                            color: root.accentColor
                            opacity: 0.75
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Math.round(dom.modelData) + " GH/s"
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.5
                        }
                    }
                }
            }
        }

        // -------------------------------------------------- Bestenliste
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.12
            visible: root.one !== null && root.roomForBoard
                     && (root.one.scoreboard || []).length > 0

            Text {
                text: "Beste Freigaben"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            Repeater {
                model: root.one ? (root.one.scoreboard || []).slice(0, 5) : []

                Row {
                    id: sbRow

                    required property var modelData
                    required property int index

                    width: parent.width
                    spacing: root.scaleUnit * 0.5

                    Text {
                        width: root.scaleUnit * 1.2
                        text: (sbRow.index + 1) + "."
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.58
                    }

                    Text {
                        width: root.scaleUnit * 4
                        text: root.big(sbRow.modelData.diff)
                        color: sbRow.index === 0 ? root.accentColor : root.textColor
                        font.pixelSize: root.scaleUnit * 0.58
                    }

                    Text {
                        text: root.netDiff > 0
                            ? "1 zu " + root.big(root.netDiff / sbRow.modelData.diff)
                            : ""
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.58
                    }

                    Text {
                        text: sbRow.modelData.time
                            ? new Date(sbRow.modelData.time * 1000).toLocaleDateString(Qt.locale("de_DE"))
                            : ""
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.58
                    }
                }
            }
        }

        // ------------------------------------------------ Geraete einzeln
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.2

            visible: root.one === null

            Repeater {
                model: root.miners

                Row {
                    id: line

                    required property var modelData

                    width: parent.width
                    spacing: root.scaleUnit * 0.5

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.scaleUnit * 0.32
                        height: width
                        radius: width / 2
                        color: line.modelData.online ? root.goodColor : root.badColor
                    }

                    Text {
                        width: root.scaleUnit * 7
                        elide: Text.ElideRight
                        text: line.modelData.name || line.modelData.id
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }

                    Text {
                        width: root.scaleUnit * 4
                        text: line.modelData.online ? root.big(line.modelData.hashRate, "H/s") : "aus"
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }

                    Text {
                        visible: line.modelData.online && line.modelData.temp !== undefined
                                 && line.modelData.temp !== null
                        width: root.scaleUnit * 2.4
                        text: line.modelData.temp !== undefined && line.modelData.temp !== null
                            ? Math.round(line.modelData.temp) + " °C" : ""
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }

                    Text {
                        visible: line.modelData.online
                        text: root.span(line.modelData.uptime)
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }
                }
            }
        }
    }
}
