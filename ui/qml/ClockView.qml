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
import "strings.js" as Tr

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
    // Der Kursverlauf unter den Kennzahlen. Der Wirt haelt den Zeitraum,
    // damit er ueber Sitzungen bleibt.
    property bool showPrice: true
    property string priceSpan: "30d"

    signal priceSpanRequested(string s)
    property bool showTime: false
    property string lang: "de"
    // Was gross in der Mitte steht. Mehrere Eintraege wechseln sich ab --
    // fuer ein Tablet an der Wand ist das der eigentliche Reiz: dieselbe
    // Flaeche zeigt nacheinander Hoehe, Kurs und Moscow Time.
    property var bigFields: ["height"]
    property int bigRotate: 0        // Sekunden, 0 = nicht wechseln
    property int bigIndex: 0

    readonly property var bigList: (bigFields && bigFields.length) ? bigFields : ["height"]
    readonly property string bigNow: bigList[bigIndex % bigList.length]

    // Beschriftung und Wert der grossen Anzeige. Eine Stelle, damit die
    // Reihenfolge unten nicht auseinanderlaeuft.
    function bigLabel(id) {
        if (id === "price")
            return Tr.t("price", root.lang);
        if (id === "moscow")
            return Tr.t("clock.moscow", root.lang);
        if (id === "fee")
            return Tr.t("fee", root.lang);
        if (id === "hashrate")
            return Tr.t("hashrate", root.lang);
        if (id === "mempool")
            return Tr.t("mempool", root.lang);
        if (id === "time")
            return Tr.t("set.clockTime", root.lang);
        return Tr.t("blockHeight", root.lang);
    }

    function bigValue(id) {
        if (id === "price")
            return root.kurs ? root.grp(root.kurs) + " " + root.waehrung : "–";
        if (id === "moscow")
            return root.kurs ? root.grp(1e8 / root.kurs) : "–";
        if (id === "fee")
            return root.comma(root.fees.fastest);
        if (id === "hashrate")
            return root.hr.current ? root.comma(root.hr.current / 1e18, 0) + " EH/s" : "–";
        if (id === "mempool")
            return root.feed ? root.grp(root.feed.mempoolCount) : "–";
        if (id === "time")
            return Qt.formatDateTime(root.jetzt, "HH:mm");
        return root.grp(root.feed ? root.feed.tipHeight : 0);
    }

    // Fuer die Uhrzeit als grosse Anzeige -- sonst bliebe sie stehen
    property date jetzt: new Date()

    Timer {
        interval: 10000
        repeat: true
        running: root.visible && (root.showTime || root.bigNow === "time")
        triggeredOnStart: true
        onTriggered: root.jetzt = new Date()
    }

    // Der Wechsel. Laeuft nur, wenn es etwas zu wechseln gibt und jemand
    // hinsieht -- ein Zeitgeber im Verborgenen kostet nur Strom.
    Timer {
        interval: Math.max(2, root.bigRotate) * 1000
        repeat: true
        running: root.visible && root.bigRotate > 0 && root.bigList.length > 1
        onTriggered: root.bigIndex = (root.bigIndex + 1) % root.bigList.length
    }

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

    // Tausendertrennung in der Schreibweise der Sprache -- Deutsch nimmt den
    // Punkt, Englisch das Komma. Das ist keine Kosmetik: "1.234" heisst je
    // nach Sprache tausendzweihundert oder eins Komma zwei.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function comma(v, digits) {
        if (v === undefined || v === null)
            return "–";
        return Tr.fixed(v, digits === undefined ? 1 : digits, root.lang);
    }

    // "noch 3 Tage 4 Std" -- ohne Sekunden, das flackert nur
    function span(ms) {
        if (!ms || ms < 0)
            return "–";
        var min = Math.floor(ms / 60000);
        var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60), m = min % 60;
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
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
        // Enger, sobald die Kurve dazukommt -- sie ist der grosse Posten in
        // dieser Spalte, und die Zeitachse unter ihr darf nicht abgeschnitten
        // werden. Sechs Fugen mal sechs Punkte sind genau die Zeile.
        spacing: root.scaleUnit * (kurve.visible ? 0.35 : 0.5)

        // -------------------------------------------------------- Uhrzeit
        // Fuer ein Tablet an der Wand: dann ist es auch eine Uhr. Der
        // Zeitgeber laeuft nur, wenn die Zeit auch gezeigt wird -- eine Anzeige
        // im Minutentakt braucht keinen Sekundentakt.
        Text {
            id: uhr

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showTime && root.bigNow !== "time"
            color: root.textColor
            font.pixelSize: root.scaleUnit * 2.2
            font.letterSpacing: root.scaleUnit * 0.04

            text: Qt.formatDateTime(root.jetzt, "HH:mm")
        }

        // ------------------------------------------------ Grosse Anzeige
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigLabel(root.bigNow)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.8
            font.letterSpacing: root.scaleUnit * 0.08
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigValue(root.bigNow)
            color: root.accentColor
            // **Die Kurve bekommt ihren Platz von hier.** Die Spalte fuellte
            // die Flaeche vorher genau aus; kommt der Kursverlauf dazu, lief
            // sie unten heraus und die Ansicht musste gerollt werden -- fuer
            // eine Uhr an der Wand der falsche Weg. Der grosse Wert gibt
            // stattdessen ein Viertel seiner Hoehe ab und bleibt auch dann
            // die groesste Zahl im Bild.
            font.pixelSize: root.scaleUnit * (kurve.visible ? 2.3 : 3.4)
            font.bold: true
        }

        Item {
            width: 1
            height: root.scaleUnit * 0.6
        }

        // ------------------------------------------------------ Kennzahlen
        Row {
            id: kennzahlen

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.scaleUnit * 1.6
            // **Die Reihe kann breiter werden als die Flaeche.** Sie ist nur
            // mittig gesetzt, ihre Breite ist die Summe ihrer Kinder -- bei
            // 1400 Punkten und fuenf Kennzahlen stand "914 EH/s" halb
            // ausserhalb, links entsprechend die erste. Passt sie nicht, wird
            // sie als Ganzes verkleinert; das faellt bei 0,95 nicht auf und
            // ist allemal besser als eine abgeschnittene Zahl.
            scale: implicitWidth > parent.width && implicitWidth > 0
                   ? parent.width / implicitWidth : 1
            transformOrigin: Item.Center

            Repeater {
                model: {
                    var alle = [
                        {
                            "id": "fee",
                            "k": Tr.t("fee", root.lang),
                            "v": root.comma(root.fees.fastest) + " sat/vB"
                        },
                        {
                            "id": "price",
                            "k": Tr.t("price", root.lang),
                            "v": root.kurs ? root.grp(root.kurs) + " " + root.waehrung : "–"
                        },
                        {
                            // Wie viele Satoshi es fuer eine Einheit der
                            // Waehrung gibt. Die Zahl steigt, wenn der Kurs
                            // faellt -- sie misst Bitcoin in Geld statt Geld
                            // in Bitcoin, und genau darum geht es dabei.
                            "id": "moscow",
                            "k": Tr.t("clock.moscow", root.lang),
                            "v": root.kurs ? root.grp(1e8 / root.kurs) + " sat" : "–"
                        },
                        {
                            "id": "mempool",
                            "k": Tr.t("mempool", root.lang),
                            "v": root.feed ? root.grp(root.feed.mempoolCount) : "–"
                        },
                        {
                            "id": "hashrate",
                            "k": Tr.t("hashrate", root.lang),
                            "v": root.hr.current ? root.comma(root.hr.current / 1e18, 0) + " EH/s" : "–"
                        }
                    ];
                    return alle.filter(function (x) {
                        // Was oben gross steht, hier weglassen -- zweimal
                        // dieselbe Zahl liest sich wie ein Fehler.
                        return root.zeigt(x.id) && x.id !== root.bigNow;
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
                    text: Tr.t("clock.diffLine", root.lang,
                               root.diff.change !== undefined
                                   ? (root.diff.change >= 0 ? "+" : "")
                                     + root.comma(root.diff.change, 2) + " %" : "")
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Item {
                    width: parent.width - 2 * root.scaleUnit * 8
                    height: 1
                }

                Text {
                    text: root.diff.remainingBlocks !== undefined
                        ? Tr.t("clock.remaining", root.lang,
                               root.grp(root.diff.remainingBlocks),
                               root.span(root.diff.remainingTime))
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
                    ? Tr.t("clock.halving", root.lang, root.grp(root.halvingHeight),
                           root.grp(root.halvingLeft),
                           root.span(root.halvingLeft * 600000))
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
            // **Nur eine Kurve in dieser Ansicht.** Ist der Kursverlauf da,
            // tritt die Hashratekurve zurueck: zwei uebereinandergestapelte
            // Linien sind in einer Uhr Rauschen, und der Platz reicht ohnehin
            // nicht fuer beide. Die Hashrate steht ausserdem im Miner-Reiter,
            // der Kurs nirgends sonst. Wer sie hier will, schaltet den
            // Kursverlauf ab.
            visible: root.showSpark && !kurve.visible
                     && (root.hr.series || []).length > 1

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

        // ----------------------------------------------- Kursverlauf
        // Braucht Hoehe, sonst ist eine Kurve nicht zu lesen. In flachen
        // Flaechen -- Leistenpopout, kleines Desktop-Widget -- bleibt sie
        // deshalb weg, statt zu einem Strich zusammenzufallen.
        //
        // **Die Schwelle steht in Bildpunkten, nicht in `scaleUnit`.** Der
        // waechst selbst mit der Hoehe (`height / 16`); `height >= scaleUnit * 22`
        // heisst damit `height >= 1,375 * height` und ist nie erfuellt. Genau
        // daran war die Kurve zuerst unsichtbar.
        PriceChart {
            id: kurve

            width: parent.width
            height: Math.max(root.scaleUnit * 5.5, root.height * 0.28)
            visible: root.showPrice && root.height >= 420
            live: root.visible
            feed: root.feed
            lang: root.lang
            currency: root.currency
            span: root.priceSpan
            // Kleiner als die Kennzahlen darueber: die Beschriftung einer
            // Kurve ist Beiwerk, keine Aussage.
            baseFont: root.scaleUnit * 0.5
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            lineColor: Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.35)
            onSpanRequested: function (sp) {
                root.priceSpanRequested(sp);
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
        text: Tr.t("offline", root.lang)
        color: "#d9534f"
        font.pixelSize: root.scaleUnit * 0.62
    }
}
