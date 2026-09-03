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
    // Zeitraum: 1h | 12h | 24h | 7d | 30d | 1y | all | custom -- der Wirt haelt
    // ihn, ebenso die Darstellung und den selbst gewaehlten Zeitraum.
    property string range: "24h"
    property string kind: "candles"      // candles | line
    property int customSecs: 259200      // drei Tage als Vorgabe
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property color panelColor: "#16161f"
    property real baseFont: 12

    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    signal rangeRequested(string r)
    signal kindRequested(string k)
    signal customSecsRequested(int secs)

    readonly property var zeitraeume: [
        { "k": "1h", "l": Tr.t("market.1h", root.lang) },
        { "k": "12h", "l": Tr.t("market.12h", root.lang) },
        { "k": "24h", "l": Tr.t("market.24h", root.lang) },
        { "k": "7d", "l": Tr.t("market.7d", root.lang) },
        { "k": "30d", "l": Tr.t("market.30d", root.lang) },
        { "k": "1y", "l": Tr.t("market.1y", root.lang) },
        { "k": "all", "l": Tr.t("market.all", root.lang) },
        { "k": "custom", "l": Tr.t("market.custom", root.lang) }
    ]

    readonly property var darstellungen: [
        { "k": "candles", "l": Tr.t("market.candles", root.lang) },
        { "k": "line", "l": Tr.t("market.line", root.lang) }
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
    // Die Kerzen der Boerse tragen **ein** Volumen, die Live-Faecher des
    // Dienstes zwei (Kauf und Verkauf getrennt). Beide Formen kommen hier an.
    function volumen(k) {
        return k.length > 6 ? k[5] + k[6] : (k[5] || 0);
    }

    readonly property real maxVol: {
        var m = 0;
        for (var i = 0; i < root.kerzen.length; i++)
            m = Math.max(m, root.volumen(root.kerzen[i]));
        return m;
    }
    readonly property real letzterPreis: root.kerzen.length
                                         ? root.kerzen[root.kerzen.length - 1][4] : 0

    function holen() {
        if (!root.feed || !root.live)
            return;
        var pfad = "/market?range=" + root.range
                 + (root.range === "custom" ? "&secs=" + root.customSecs : "");
        root.feed.getJson(pfad, function (d, err) {
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

    onRangeChanged: root.holen()
    onCustomSecsChanged: if (root.range === "custom") root.holen()
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

    Row {
        id: wahl

        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.5
        z: 50

        // Kerze oder Kurve. **Nur hier** -- der Kursverlauf in der BlockClock
        // kann keine Kerzen zeigen: die Reihe von mempool.space kennt nur
        // Schlusskurse, kein Hoch und Tief.
        TileGoggles {
            anchors.verticalCenter: parent.verticalCenter
            width: root.baseFont * 9.5
            alignRight: true
            labelKey: ""
            modes: root.darstellungen
            mode: root.kind
            counts: []
            total: 0
            lang: root.lang
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            uiFont: root.baseFont
            onPicked: function (m) {
                root.kindRequested(m);
            }
        }

        // Eigener Zeitraum: eine Zahl mit Einheit, etwa "72h" oder "90d".
        // Ein Kalender mit Von und Bis waere ein eigenes Bauteil; hierfuer
        // genuegt, was man ohnehin tippen wuerde.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.range === "custom"
            width: root.baseFont * 5
            height: Math.round(root.baseFont * 2.0)
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: eingabe.activeFocus ? root.accentColor : root.lineColor

            TextInput {
                id: eingabe

                anchors.fill: parent
                anchors.leftMargin: root.baseFont * 0.7
                verticalAlignment: TextInput.AlignVCenter
                color: root.textColor
                font.pixelSize: root.baseFont
                selectByMouse: true
                text: root.eigenText(root.customSecs)
                onAccepted: {
                    var sek = root.eigenSekunden(text);
                    if (sek > 0)
                        root.customSecsRequested(sek);
                }
            }
        }

        DropDown {
            anchors.verticalCenter: parent.verticalCenter
            // **Der Rahmen ist die Ansicht, nicht die Reihe.** Ohne das haelt
            // sich die Liste an die Reihe, in der sie steht, und zeichnet
            // ungehindert darueber hinaus -- im Dashboard-Tab landete sie
            // dadurch neben der Flaeche.
            bounds: root
            flaecheColor: root.panelColor
            model: root.zeitraeume
            current: root.range
            uiFont: root.baseFont
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            lineColor: root.lineColor
            onPicked: function (k) {
                root.rangeRequested(k);
            }
        }
    }

    // "72h" -> 259200. Einheiten: m Minuten, h Stunden, d Tage, w Wochen,
    // y Jahre. Ohne Einheit gelten Tage.
    function eigenSekunden(text) {
        var m = String(text).trim().toLowerCase().match(/^([0-9]+(?:[.,][0-9]+)?)\s*([mhdwy]?)$/);
        if (!m)
            return 0;
        var zahl = parseFloat(m[1].replace(",", "."));
        var faktor = { "m": 60, "h": 3600, "d": 86400, "w": 604800, "y": 31536000 };
        return Math.round(zahl * (faktor[m[2]] || 86400));
    }

    function eigenText(sek) {
        if (sek % 31536000 === 0)
            return (sek / 31536000) + "y";
        if (sek % 604800 === 0)
            return (sek / 604800) + "w";
        if (sek % 86400 === 0)
            return (sek / 86400) + "d";
        if (sek % 3600 === 0)
            return (sek / 3600) + "h";
        return Math.round(sek / 60) + "m";
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

            var i, k, x, farbe, steigt;

            // ---- Kurve statt Kerzen ---------------------------------------
            // Bei neun Jahren in einem Bild ist eine Kerze ein Strich; dann
            // sagt die Linie mehr. Bei einer Stunde ist es umgekehrt.
            if (root.kind === "line") {
                var g = ctx.createLinearGradient(0, root.baseFont * 0.2, 0,
                                                 root.baseFont * 0.2 + preisHoehe);
                g.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0.28));
                g.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo(kerzeBreite / 2, root.baseFont * 0.2 + preisHoehe);
                for (i = 0; i < n; i++)
                    ctx.lineTo(i * kerzeBreite + kerzeBreite / 2, yPreis(root.kerzen[i][4]));
                ctx.lineTo((n - 1) * kerzeBreite + kerzeBreite / 2,
                           root.baseFont * 0.2 + preisHoehe);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = root.accentColor;
                ctx.lineWidth = 1.6;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (i = 0; i < n; i++) {
                    var xl = i * kerzeBreite + kerzeBreite / 2;
                    if (i === 0)
                        ctx.moveTo(xl, yPreis(root.kerzen[i][4]));
                    else
                        ctx.lineTo(xl, yPreis(root.kerzen[i][4]));
                }
                ctx.stroke();
            }

            // ---- Kerzen ----------------------------------------------------
            for (i = 0; i < n; i++) {
                k = root.kerzen[i];
                x = i * kerzeBreite + (kerzeBreite - koerper) / 2;
                steigt = k[4] >= k[1];
                farbe = steigt ? root.upColor : root.downColor;

                if (root.kind === "candles") {
                    var mitte = i * kerzeBreite + kerzeBreite / 2;

                    // Docht
                    ctx.strokeStyle = farbe;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(Math.round(mitte) + 0.5, yPreis(k[2]));
                    ctx.lineTo(Math.round(mitte) + 0.5, yPreis(k[3]));
                    ctx.stroke();

                    // Koerper -- mindestens ein Bildpunkt, sonst verschwindet
                    // eine Kerze ohne Bewegung ganz
                    var yO = yPreis(Math.max(k[1], k[4]));
                    var yC = yPreis(Math.min(k[1], k[4]));
                    ctx.fillStyle = farbe;
                    ctx.fillRect(x, yO, koerper, Math.max(1, yC - yO));
                }

                // ---- Volumen darunter -------------------------------------
                if (root.maxVol > 0) {
                    var basis = height - padB;
                    if (k.length > 6) {
                        // Live-Faecher: Kauf und Verkauf gestapelt
                        var hKauf = volHoehe * (k[5] / root.maxVol);
                        var hVerk = volHoehe * (k[6] / root.maxVol);
                        ctx.fillStyle = root.upColor;
                        ctx.fillRect(x, basis - hKauf, koerper, hKauf);
                        ctx.fillStyle = root.downColor;
                        ctx.fillRect(x, basis - hKauf - hVerk, koerper, hVerk);
                    } else {
                        // Boersenkerze: ein Volumen, eingefaerbt nach Richtung
                        var hVol = volHoehe * (root.volumen(k) / root.maxVol);
                        ctx.fillStyle = farbe;
                        ctx.fillRect(x, basis - hVol, koerper, hVol);
                    }
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

    // Bei einem Tag sagt ein Datum nichts, bei neun Jahren eine Uhrzeit nichts.
    function uhrzeit(ts) {
        var kurz = (root.range === "1h" || root.range === "12h" || root.range === "24h");
        var lang = (root.range === "1y" || root.range === "all");
        return Qt.formatDateTime(new Date(ts * 1000),
                                 kurz ? "HH:mm" : (lang ? "MM.yyyy" : "dd.MM."));
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
