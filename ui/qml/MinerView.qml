// Eigener Solo-Miner (Bitaxe). Zeigt, was das Geraet meldet, und stellt die
// erreichte Schwierigkeit der des Netzes gegenueber -- das ist die Zahl, um
// die es beim Solomining eigentlich geht.
//
// Die Adresse traegt der Daemon aus ~/.config/btcfeed/sources.json; ohne
// Eintrag bleibt diese Ansicht leer und sagt das auch.
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
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))

    readonly property var m: feed ? feed.miner : ({})
    readonly property bool online: feed ? feed.minerOnline : false
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0

    // Anteil an der Netzschwierigkeit -- die Zahl, die zaehlt
    readonly property real bestShare: (netDiff > 0 && m.bestDiff)
        ? root.parseDiff(m.bestDiff) / netDiff : 0

    // Der Bitaxe liefert die Bestleistung als Text mit Einheit ("1.23M")
    function parseDiff(v) {
        if (typeof v === "number")
            return v;
        if (!v)
            return 0;
        var t = String(v).trim();
        var mult = { "k": 1e3, "K": 1e3, "M": 1e6, "G": 1e9, "T": 1e12, "P": 1e15 };
        var last = t.charAt(t.length - 1);
        var f = mult[last] || 1;
        var n = parseFloat(f === 1 ? t : t.slice(0, -1));
        return isNaN(n) ? 0 : n * f;
    }

    function big(n) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return (n >= 100 ? n.toFixed(0) : n.toFixed(2)).replace(".", ",") + " " + u[i];
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m2 = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return d + (d === 1 ? " Tag " : " Tage ") + h + " Std";
        if (h > 0)
            return h + " Std " + m2 + " Min";
        return m2 + " Min";
    }

    // ---------------------------------------------------- nicht eingerichtet
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.8
        spacing: root.scaleUnit * 0.5
        visible: !root.feed || Object.keys(root.m).length === 0

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
            text: "Adresse in ~/.config/btcfeed/sources.json eintragen:\n"
                  + "{ \"bitaxe\": \"http://192.168.1.42\" }\n"
                  + "danach:  systemctl --user restart btcfeed"
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
            font.family: "monospace"
        }
    }

    // ------------------------------------------------------- nicht erreichbar
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.4
        visible: root.feed && Object.keys(root.m).length > 0 && !root.online

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Miner nicht erreichbar"
            color: "#d9534f"
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Das Geraet ist vermutlich aus."
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }
    }

    // ------------------------------------------------------------- im Betrieb
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.86
        spacing: root.scaleUnit * 0.5
        visible: root.online

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.m.model || "Solo-Miner"
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.72
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.m.hashRate ? root.big(root.m.hashRate * 1e9) + "H/s" : "–"
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 2.6
            font.bold: true
        }

        // Die eigentliche Zahl beim Solomining
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Beste Freigabe gegen Netzschwierigkeit"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.m.bestDiff
                    ? root.big(root.parseDiff(root.m.bestDiff)) + "  von  " + root.big(root.netDiff)
                    : "–"
                color: root.textColor
                font.pixelSize: root.scaleUnit * 0.95
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.bestShare > 0
                // Bei Solomining sind das winzige Anteile -- lieber "1 zu N"
                // als eine Prozentzahl mit acht Nullen.
                text: root.bestShare > 0 ? "das ist 1 zu " + root.big(1 / root.bestShare) : ""
                color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.4
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.scaleUnit * 1.4

            Repeater {
                model: [
                    {
                        "k": "Temperatur",
                        "v": root.m.temp !== undefined ? String(Math.round(root.m.temp)) + " °C" : "–"
                    },
                    {
                        "k": "Leistung",
                        "v": root.m.power !== undefined ? String(Math.round(root.m.power)) + " W" : "–"
                    },
                    {
                        "k": "Freigaben",
                        "v": root.m.shares !== undefined
                            ? String(root.m.shares) + (root.m.rejected ? " (" + root.m.rejected + " abgelehnt)" : "")
                            : "–"
                    },
                    {
                        "k": "Laufzeit",
                        "v": root.span(root.m.uptime)
                    }
                ]

                Column {
                    // Mit `pragma ComponentBehavior: Bound` muss modelData
                    // ausdruecklich angefordert werden.
                    required property var modelData

                    spacing: root.scaleUnit * 0.12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.k
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.v
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.9
                    }
                }
            }
        }
    }
}
