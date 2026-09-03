// Der Markt: Kerzen aus den Trades mehrerer Boersen, Volumen darunter.
//
// Vorbild ist aggr.trade. Uebernommen ist davon der **Gedanke**, kein Code --
// aggr steht unter GPL-3.0, dieses Repo unter MIT. Die Schnittstellen der
// Boersen gehoeren niemandem.
//
// Verdichtet wird im Dienst: er haelt Sekundenfaecher und fasst sie beim
// Abfragen zum gewuenschten Raster zusammen. Hier kommen hoechstens 400
// fertige Kerzen an, nie einzelne Trades -- ein reger Markt schickt hunderte
// je Sekunde, und das ist genau die Groessenordnung, an der in diesem Programm
// schon zweimal die CPU-Zeit hochgegangen ist.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "money.js" as Money
import "strings.js" as Tr

Item {
    id: root

    property var feed: null
    property string lang: "de"
    property string currency: "usd"
    // Raster in Sekunden -- der Wirt haelt es
    property int timeframe: 5
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12

    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    signal timeframeRequested(int tf)

    readonly property var rasters: [
        { "k": "1", "l": Tr.t("market.1s", root.lang) },
        { "k": "5", "l": Tr.t("market.5s", root.lang) },
        { "k": "15", "l": Tr.t("market.15s", root.lang) },
        { "k": "60", "l": Tr.t("market.1m", root.lang) },
        { "k": "300", "l": Tr.t("market.5m", root.lang) }
    ]

    property var kerzen: []
    property var quellen: []
    property int tradeZahl: 0
    property string fehler: ""

    readonly property real hoch: {
        var m = -Infinity;
        for (var i = 0; i < root.kerzen.length; i++)
            m = Math.max(m, root.kerzen[i][2]);
        return m === -Infinity ? 0 : m;
    }
    readonly property real tief: {
        var m = Infinity;
        for (var i = 0; i < root.kerzen.length; i++)
            m = Math.min(m, root.kerzen[i][3]);
        return m === Infinity ? 0 : m;
    }
    readonly property real maxVol: {
        var m = 0;
        for (var i = 0; i < root.kerzen.length; i++)
            m = Math.max(m, root.kerzen[i][5] + root.kerzen[i][6]);
        return m;
    }
    readonly property real letzterPreis: root.kerzen.length
                                         ? root.kerzen[root.kerzen.length - 1][4] : 0

    function holen() {
        if (!root.feed || !root.live)
            return;
        root.feed.getJson("/market?tf=" + root.timeframe + "&n=180", function (d, err) {
            if (err || !d) {
                root.fehler = err || "nicht erreichbar";
                return;
            }
            root.fehler = "";
            root.kerzen = d.candles || [];
            root.quellen = d.sources || [];
            root.tradeZahl = d.trades || 0;
            leinwand.requestPaint();
        });
    }

    onTimeframeChanged: root.holen()
    onLiveChanged: if (root.live) root.holen()
    Component.onCompleted: root.holen()

    // Jede Abfrage haelt die Boersenstroeme im Dienst am Leben -- bleibt sie
    // zwei Minuten aus, trennt er sie von selbst. Sieht niemand hin, fragt
    // hier auch niemand.
    Timer {
        interval: 1000
        repeat: true
        running: root.live && root.visible
        onTriggered: root.holen()
    }

    // ------------------------------------------------------------ Kopfzeile
    Row {
        id: kopf

        anchors.left: parent.left
        anchors.top: parent.top
        spacing: root.baseFont

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.letzterPreis
                  ? Tr.price1(root.letzterPreis, "$", root.lang) : "–"
            color: root.textColor
            font.pixelSize: root.baseFont * 1.5
            font.weight: Font.DemiBold
        }

        // Wie viel schon durchgelaufen ist. **Nicht unten rechts** -- dort
        // stand es genau auf der Uhrzeit der Zeitachse ("14:19:5553 Trades").
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.tradeZahl > 0
            text: Tr.t("market.trades", root.lang, Tr.group(root.tradeZahl, root.lang))
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }

        // Welche Boerse gerade haengt -- ohne das sieht man einer flachen
        // Kurve nicht an, ob der Markt ruhig ist oder die Verbindung weg.
        Repeater {
            model: root.quellen

            Row {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: parent.modelData.online ? root.upColor : root.downColor
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.name
                    color: root.dimColor
                    font.pixelSize: root.baseFont - 2
                }
            }
        }
    }

    TileGoggles {
        id: wahl

        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.min(parent.width, root.baseFont * 19)
        alignRight: true
        labelKey: ""
        modes: root.rasters
        mode: String(root.timeframe)
        counts: []
        total: 0
        lang: root.lang
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        uiFont: root.baseFont
        onPicked: function (m) {
            root.timeframeRequested(parseInt(m, 10));
        }
    }

    // --------------------------------------------------------------- Kerzen
    Canvas {
        id: leinwand

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Math.max(kopf.height, wahl.height) + root.baseFont * 0.6
        antialiasing: false

        readonly property real padR: mass.implicitWidth + 8
        readonly property real padB: root.baseFont * 1.4
        // Das untere Drittel gehoert dem Volumen
        readonly property real volHoehe: (height - padB) * 0.26

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var n = root.kerzen.length;
            if (n < 1)
                return;

            var breiteGesamt = width - padR;
            var kerzeBreite = Math.max(1, breiteGesamt / n);
            var koerper = Math.max(1, Math.min(kerzeBreite * 0.7, kerzeBreite - 1));
            var preisHoehe = height - padB - volHoehe - root.baseFont * 0.4;
            var lo = root.tief, hi = root.hoch;
            var spanne = hi - lo;
            if (spanne <= 0)
                spanne = Math.max(1, hi * 0.0002);

            function yPreis(v) {
                return root.baseFont * 0.2 + preisHoehe * (1 - (v - lo) / spanne);
            }

            // Waagerechte Hilfslinien und die Preisachse rechts
            ctx.strokeStyle = root.lineColor;
            ctx.fillStyle = root.dimColor;
            ctx.font = (root.baseFont - 2) + "px sans-serif";
            ctx.textAlign = "left";
            ctx.lineWidth = 1;
            for (var g = 0; g <= 4; g++) {
                var wert = lo + spanne * g / 4;
                var y = Math.round(yPreis(wert)) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(breiteGesamt, y);
                ctx.stroke();
                ctx.fillText(Tr.group(wert, root.lang), breiteGesamt + 6, y + 4);
            }

            // Kerzen
            for (var i = 0; i < n; i++) {
                var k = root.kerzen[i];
                var x = i * kerzeBreite + (kerzeBreite - koerper) / 2;
                var mitte = i * kerzeBreite + kerzeBreite / 2;
                var steigt = k[4] >= k[1];
                var farbe = steigt ? root.upColor : root.downColor;

                // Docht
                ctx.strokeStyle = farbe;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(Math.round(mitte) + 0.5, yPreis(k[2]));
                ctx.lineTo(Math.round(mitte) + 0.5, yPreis(k[3]));
                ctx.stroke();

                // Koerper -- mindestens ein Bildpunkt, sonst verschwindet eine
                // Kerze ohne Bewegung ganz
                var yO = yPreis(Math.max(k[1], k[4]));
                var yC = yPreis(Math.min(k[1], k[4]));
                ctx.fillStyle = farbe;
                ctx.fillRect(x, yO, koerper, Math.max(1, yC - yO));

                // Volumen darunter, Kauf und Verkauf gestapelt
                if (root.maxVol > 0) {
                    var basis = height - padB;
                    var hKauf = volHoehe * (k[5] / root.maxVol);
                    var hVerk = volHoehe * (k[6] / root.maxVol);
                    ctx.fillStyle = root.upColor;
                    ctx.fillRect(x, basis - hKauf, koerper, hKauf);
                    ctx.fillStyle = root.downColor;
                    ctx.fillRect(x, basis - hKauf - hVerk, koerper, hVerk);
                }
            }

            // Zeitachse: Anfang und Ende
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "left";
            ctx.fillText(root.uhrzeit(root.kerzen[0][0]), 0, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.uhrzeit(root.kerzen[n - 1][0]), breiteGesamt, height - 2);
        }
    }

    function uhrzeit(ts) {
        return Qt.formatDateTime(new Date(ts * 1000),
                                 root.timeframe >= 60 ? "HH:mm" : "HH:mm:ss");
    }

    // Nur zum Messen der Preisachse
    Text {
        id: mass

        visible: false
        text: Tr.group(root.hoch || 88888, root.lang)
        font.pixelSize: root.baseFont - 2
    }

    Connections {
        target: root
        function onKerzenChanged() {
            leinwand.requestPaint();
        }
    }

    // ------------------------------------------------------------ Hinweise
    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.kerzen.length
        text: root.fehler !== "" ? Tr.t("market.failed", root.lang, root.fehler)
                                 : Tr.t("market.waiting", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont
    }


}
