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

        // ------------------------------------------------ Geraete einzeln
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.2

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
