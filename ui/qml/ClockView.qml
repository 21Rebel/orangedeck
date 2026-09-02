// BlockClock: gross, ruhig, ohne Bedienung. Gedacht fuer ein Tablet an der
// Wand oder den Vollbildmodus am Rechner.
//
// Vorbild ist der unveroeffentlichte Zweig `display-mode` aus dem Fork
// (upstream/bitfeed, 03.04.2023): ein Schalter, der die Oberflaeche dauerhaft
// in eine reduzierte, bedienungsfreie Ansicht zwingt.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "money.js" as Money

// Der Repeater unten greift auf `root` zu. Ohne diese Zeile warnt qmllint,
// dass IDs aus dem umgebenden Bauteil in geschachtelten Bauteilen nicht
// gebunden sind -- mit ihr sind sie es ausdruecklich.
pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    // Welche Kennzahlen erscheinen. Leere Liste heisst: alle. So bleibt eine
    // spaeter hinzukommende sichtbar, statt stillschweigend zu fehlen.
    property var fields: []
    property string currency: "eur"
    property bool showBars: true
    property bool showSpark: true
    property bool showTime: false

    readonly property real kurs: Money.rate(price, currency)
    readonly property string waehrung: Money.symbol(Money.actual(price, currency))

    // Robust gegen alles, was kein Feld-Array ist: leer, undefiniert oder ein
    // ungueltiger Wert aus der Ablage heissen "alles zeigen".
    function zeigt(id) {
        var f = root.fields;
        if (!f || !f.length || typeof f.indexOf !== "function")
            return true;
        return f.indexOf(id) >= 0;
    }

    readonly property var tip: feed ? feed.tip : ({})
    readonly property var fees: (feed && feed.snap.fees) || ({})
    readonly property var price: feed ? feed.price : ({})
    readonly property var diff: feed ? feed.difficulty : ({})
    readonly property var hr: feed ? feed.hashrate : ({})

    // Halving: alle 210.000 Bloecke
    readonly property int halvingHeight: {
        var h = feed ? feed.tipHeight : 0;
        return h > 0 ? (Math.floor(h / 210000) + 1) * 210000 : 0;
    }
    readonly property int halvingLeft: halvingHeight > 0 ? halvingHeight - feed.tipHeight : 0

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

    function comma(v, digits) {
        if (v === undefined || v === null)
            return "–";
        return v.toFixed(digits === undefined ? 1 : digits).replace(".", ",");
    }

    // "noch 3 Tage 4 Std" -- ohne Sekunden, das flackert nur
    function span(ms) {
        if (!ms || ms < 0)
            return "–";
        var min = Math.floor(ms / 60000);
        var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60), m = min % 60;
        if (d > 0)
            return d + (d === 1 ? " Tag " : " Tage ") + h + " Std";
        if (h > 0)
            return h + " Std " + m + " Min";
        return m + " Min";
    }

    // Auch hier kann es eng werden -- im Dashboard-Tab und auf einem hochkant
    // gehaltenen Tablet.
    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body

        width: parent.width * 0.86
        x: (flick.width - width) / 2
        y: Math.max(0, (flick.height - implicitHeight) / 2)
        spacing: root.scaleUnit * 0.5

        // -------------------------------------------------------- Uhrzeit
        // Fuer ein Tablet an der Wand: dann ist es auch eine Uhr. Der
        // Zeitgeber laeuft nur, wenn die Zeit auch gezeigt wird -- eine Anzeige
        // im Minutentakt braucht keinen Sekundentakt.
        Text {
            id: uhr

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showTime
            color: root.textColor
            font.pixelSize: root.scaleUnit * 2.2
            font.letterSpacing: root.scaleUnit * 0.04

            function stellen() {
                uhr.text = Qt.formatDateTime(new Date(), "HH:mm");
            }

            Component.onCompleted: stellen()

            Timer {
                interval: 10000
                repeat: true
                running: root.showTime && root.visible
                triggeredOnStart: true
                onTriggered: uhr.stellen()
            }
        }

        // ---------------------------------------------------- Blockhoehe
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Blockhöhe"
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.8
            font.letterSpacing: root.scaleUnit * 0.08
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.grp(root.feed ? root.feed.tipHeight : 0)
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 3.4
            font.bold: true
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.6
        }

        // ------------------------------------------------------ Kennzahlen
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.scaleUnit * 1.6

            Repeater {
                model: {
                    var alle = [
                        {
                            "id": "fee",
                            "k": "Gebühr",
                            "v": root.comma(root.fees.fastest) + " sat/vB"
                        },
                        {
                            "id": "price",
                            "k": "Kurs",
                            "v": root.kurs ? root.grp(root.kurs) + " " + root.waehrung : "–"
                        },
                        {
                            // Wie viele Satoshi es fuer eine Einheit der
                            // Waehrung gibt. Die Zahl steigt, wenn der Kurs
                            // faellt -- sie misst Bitcoin in Geld statt Geld
                            // in Bitcoin, und genau darum geht es dabei.
                            "id": "moscow",
                            "k": "Moscow Time",
                            "v": root.kurs ? root.grp(1e8 / root.kurs) + " sat" : "–"
                        },
                        {
                            "id": "mempool",
                            "k": "Mempool",
                            "v": root.feed ? root.grp(root.feed.mempoolCount) : "–"
                        },
                        {
                            "id": "hashrate",
                            "k": "Hashrate",
                            "v": root.hr.current ? root.comma(root.hr.current / 1e18, 0) + " EH/s" : "–"
                        }
                    ];
                    return alle.filter(function (x) {
                        return root.zeigt(x.id);
                    });
                }

                Column {
                    // Mit `pragma ComponentBehavior: Bound` muss modelData
                    // ausdruecklich angefordert werden.
                    required property var modelData

                    spacing: root.scaleUnit * 0.12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.k
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.62
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.v
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 1.0
                    }
                }
            }
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.6
        }

        // ------------------------------------ Schwierigkeit und Halving
        Column {
            width: parent.width
            spacing: root.scaleUnit * 0.25
            visible: root.showBars

            Row {
                width: parent.width

                Text {
                    text: "Schwierigkeit " + (root.diff.change !== undefined
                        ? (root.diff.change >= 0 ? "+" : "") + root.comma(root.diff.change, 2) + " %" : "")
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Item {
                    width: parent.width - 2 * root.scaleUnit * 8
                    height: 1
                }

                Text {
                    text: root.diff.remainingBlocks !== undefined
                        ? "noch " + root.grp(root.diff.remainingBlocks) + " Blöcke · " + root.span(root.diff.remainingTime)
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(3, root.scaleUnit * 0.16)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.diff.progress || 0) / 100))
                    height: parent.height
                    radius: height / 2
                    color: root.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 600
                        }
                    }
                }
            }

            Text {
                text: root.halvingLeft > 0
                    ? "Halving bei " + root.grp(root.halvingHeight) + " · noch "
                      + root.grp(root.halvingLeft) + " Blöcke · rund "
                      + root.span(root.halvingLeft * 600000)
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }
        }

        // -------------------------------------------- Hashrate-Kurve
        Canvas {
            id: spark

            width: parent.width
            height: root.scaleUnit * 1.8
            visible: root.showSpark && (root.hr.series || []).length > 1

            Connections {
                target: root
                function onHrChanged() {
                    spark.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var s = root.hr.series || [];
                if (s.length < 2)
                    return;
                var lo = Math.min.apply(null, s), hi = Math.max.apply(null, s);
                if (hi <= lo)
                    return;
                var pad = 2;
                ctx.beginPath();
                for (var i = 0; i < s.length; i++) {
                    var x = pad + (width - 2 * pad) * i / (s.length - 1);
                    var y = height - pad - (height - 2 * pad) * (s[i] - lo) / (hi - lo);
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.strokeStyle = root.accentColor;
                ctx.lineWidth = Math.max(1.5, root.scaleUnit * 0.09);
                ctx.stroke();
            }
        }
    }

    }

    // Bei fehlender Verbindung nicht luegen, sondern es sagen
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.scaleUnit * 0.6
        visible: root.feed && !root.feed.online
        text: "keine Verbindung"
        color: "#d9534f"
        font.pixelSize: root.scaleUnit * 0.62
    }
}
