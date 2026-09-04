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
import "fonts.js" as Fonts

Item {
    id: root

    property var feed: null
    property string lang: "de"
    property string currency: "usd"
    // Zeitraum: 1h | 12h | 24h | 7d | 30d | 1y | all | custom -- der Wirt haelt
    // ihn, ebenso die Darstellung und den selbst gewaehlten Zeitraum.
    property string range: "24h"
    property string kind: "candles"      // candles | line
    // Was unter dem Kurs steht: die Volumenbalken oder der CVD.
    property string lower: "volume"      // volume | cvd
    property int customSecs: 259200      // drei Tage als Vorgabe
    // Fadenkreuz und laufendes Band -- beides einschaltbar
    property bool crosshair: true
    property bool showTape: true
    property bool live: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property color panelColor: "#16161f"
    property real baseFont: 12

    readonly property string zeichen: Money.symbol(root.currency)
    readonly property color upColor: "#5cb946"
    readonly property color downColor: "#d33f3f"

    signal rangeRequested(string r)
    signal kindRequested(string k)
    signal customSecsRequested(int secs)
    signal lowerRequested(string l)
    // Von und Bis gehen als Paar zurueck -- einzeln waeren sie zwischendurch
    // widerspruechlich (ein Von ohne Bis ist kein Fenster).
    signal vonBisRequested(int von, int bis)

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

    readonly property var unterarten: [
        { "k": "volume", "l": Tr.t("market.volume", root.lang) },
        { "k": "cvd", "l": Tr.t("market.cvd", root.lang) }
    ]

    property var kerzen: []
    property var quellen: []
    property int tradeZahl: 0
    // Wahr, wenn die Kerzen aus Dollar umgerechnet sind -- ueber Jahre ist
    // das eine Umrechnung zum heutigen Kurs, keine Wahrheit.
    property bool umgerechnet: false
    property string fehler: ""
    // Das Band: nur was seit `bandNr` dazukam wird geholt und angehaengt.
    property var band: []
    property int bandNr: 0
    // Juengster Trade oben. Einmal gedreht statt in jeder Zeile gerechnet.
    readonly property var bandUmgekehrt: root.band.slice().reverse()
    // Welche Kerze unter dem Zeiger liegt, und wo er steht
    property int zeiger: -1
    property real zeigerY: 0

    // ---------------------------------------------------------------- Zoom
    // **Sofort zeichnen, spaeter holen.** Jede Radrastung loeste vorher eine
    // Abfrage aus: der Dienst suchte ein neues Raster, holte womoeglich bei
    // der Boerse nach, und das Bild kam versetzt zur Bewegung zurueck -- es
    // ruckelte, und man traf nichts. Jetzt zoomt die Ansicht augenblicklich
    // in die Kerzen, die sie schon hat, und fragt erst nach, wenn die Hand
    // stillhaelt. Dann kommt das passende Raster und `zoomSekunden` faellt
    // wieder weg.
    property int zoomSekunden: 0
    property bool zoomAusstehend: false

    // ------------------------------------------------- Fenster in der Zeit
    // **0 heisst: bis jetzt.** Das ist der Regelfall und bleibt es; alles
    // andere ist ein Fenster in der Vergangenheit. Beim Ziehen und am
    // Schieber wandert es, die Laenge bleibt.
    property int fensterEnde: 0
    // Ausdrueckliches Fenster von ... bis. Ist es gesetzt, gilt weder
    // Zeitraum noch Fensterende.
    //
    // **Der Wirt haelt es**, wie Zeitraum und Darstellung -- ein getipptes
    // "01.01.2021..31.03.2021" ist eine Absicht und soll einen Neustart
    // ueberleben. Hier steht es deshalb nur zu lesen: geaendert wird es ueber
    // `vonBisRequested`, und es kommt vom Wirt zurueck. Das Fensterende aus
    // Schieber und Ziehen bleibt fluechtig -- wer neu startet, will in die
    // Gegenwart sehen.
    property int vonZeit: 0
    property int bisZeit: 0
    // Waehrend des Ziehens: um wie viele Bildpunkte das Bild verschoben ist
    property real ziehVersatz: 0

    // ------------------------------------------------------- Uebersicht
    // **Die ganze Geschichte als Tageskerzen, einmal geholt.** Der Grund ist
    // gemessen: ein frisches Fenster kostet 1,1 bis 1,5 Sekunden, weil der
    // Dienst dafuer bei Binance nachfragt (gepuffert 4 ms). Am Schieber sind
    // zehn Bildpunkte schnell hundert Tage -- beim Ziehen waere jede Stelle
    // ein eigenes Fenster und das Bild stuende still.
    //
    // Also wird waehrend des Ziehens aus diesen 3.300 Kerzen gezeichnet:
    // grob, aber sofort und an jeder Stelle seit 2017. Das genaue Fenster
    // kommt, wenn die Hand loslaesst.
    property var uebersicht: []
    property bool vorschau: false
    // Ein Tag traegt kein Fenster von 24 Stunden. Reicht der Zeitraum nicht
    // fuer ein Bild, zeigt die Vorschau die Umgebung -- lieber die Gegend als
    // eine leere Flaeche. Ab zwei Monaten Fensterbreite faellt das weg, dort
    // deckt sich die Vorschau mit dem, was danach kommt.
    readonly property int vorschauMindest: 60 * 86400

    // Binance hat BTCUSDT am 31.07.2017 aufgenommen -- frueher gibt es nichts.
    readonly property int beginn: 1501459200
    readonly property int jetzt: Math.round(Date.now() / 1000)
    readonly property int endeEffektiv: root.fensterEnde > 0 ? root.fensterEnde : root.jetzt
    readonly property bool inVergangenheit: root.fensterEnde > 0 || root.bisZeit > 0

    // Der Wert allein, ohne Nebenwirkung -- **0 heisst weiterhin: bis jetzt**.
    function fensterWert(ende) {
        var min = root.beginn + root.sichtSekunden;
        var max = root.jetzt;
        var e = Math.round(Math.max(min, Math.min(max, ende)));
        return (e >= max - 60) ? 0 : e;
    }

    function fensterSetzen(ende) {
        root.fensterEnde = root.fensterWert(ende);
        root.vonBisLoeschen();
        nachfassen.restart();
    }

    // Waehrend am Schieber gezogen wird: nur die Stelle merken, **nicht**
    // nachladen. Das Bild kommt so lange aus der Uebersicht und folgt der
    // Hand ohne Verzoegerung.
    function fensterSchieben(ende) {
        root.fensterEnde = root.fensterWert(ende);
    }

    // Nicht selbst nullen: das Fenster gehoert dem Wirt. Setzte es die Ansicht
    // selbst, stuende hier gleich ein anderer Wert als in den Einstellungen --
    // und der naechste Blick von dort holte das geloeschte Fenster zurueck.
    function vonBisLoeschen() {
        if (root.vonZeit || root.bisZeit)
            root.vonBisRequested(0, 0);
    }

    function zurueckZurGegenwart() {
        root.fensterEnde = 0;
        if (root.vonZeit || root.bisZeit) {
            // Kommt ueber den Wirt zurueck; die Aenderung holt dann selbst.
            root.vonBisRequested(0, 0);
            return;
        }
        root.holen();
    }

    readonly property int sichtSekunden: root.zoomSekunden > 0
        ? root.zoomSekunden
        : (root.range === "custom" ? root.customSecs : root.sekundenVon(root.range))

    // Die Kerzen, die gezeichnet werden. Beim Zoomen ein Ausschnitt der
    // geholten, sonst alle.
    // Der Ausschnitt der Tagesuebersicht, der zum gezogenen Ziel passt.
    readonly property var vorschauKerzen: {
        var u = root.uebersicht;
        if (!u.length)
            return root.kerzen;
        var ende = root.endeEffektiv;
        var spanne = Math.max(root.sichtSekunden, root.vorschauMindest);
        var von = ende - spanne;
        var aus = [];
        for (var i = 0; i < u.length; i++) {
            if (u[i][0] >= von && u[i][0] <= ende)
                aus.push(u[i]);
        }
        return aus.length >= 3 ? aus : root.kerzen;
    }

    readonly property var sicht: {
        // Am Schieber gezogen: aus der Uebersicht, ohne eine einzige Abfrage.
        if (root.vorschau)
            return root.vorschauKerzen;
        if (root.zoomSekunden <= 0 || !root.kerzen.length)
            return root.kerzen;
        var bis = root.kerzen[root.kerzen.length - 1][0];
        var ab = bis - root.zoomSekunden;
        var aus = [];
        for (var i = 0; i < root.kerzen.length; i++) {
            if (root.kerzen[i][0] >= ab)
                aus.push(root.kerzen[i]);
        }
        // Unter drei Kerzen ist nichts mehr zu sehen -- dann lieber warten,
        // bis das feinere Raster da ist.
        return aus.length >= 3 ? aus : root.kerzen;
    }

    function zoomen(faktor) {
        var jetzt = root.sichtSekunden;
        root.zoomSekunden = Math.round(Math.max(300, Math.min(400000000,
                                                              jetzt * faktor)));
        root.zoomAusstehend = true;
        nachfassen.restart();
        leinwand.requestPaint();
    }

    Timer {
        id: nachfassen

        interval: 250
        onTriggered: {
            if (root.zoomAusstehend) {
                root.zoomAusstehend = false;
                if (root.range !== "custom")
                    root.rangeRequested("custom");
                root.customSecsRequested(root.zoomSekunden);
            } else {
                root.holen();
            }
        }
    }

    readonly property real hoch: {
        var m = -Infinity;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.max(m, root.sicht[i][2]);
        return m === -Infinity ? 0 : m;
    }
    readonly property real tief: {
        var m = Infinity;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.min(m, root.sicht[i][3]);
        return m === Infinity ? 0 : m;
    }
    // Die Kerzen der Boerse tragen **ein** Volumen, die Live-Faecher des
    // Dienstes zwei (Kauf und Verkauf getrennt). Beide Formen kommen hier an.
    function volumen(k) {
        return k.length > 6 ? k[5] + k[6] : (k[5] || 0);
    }

    readonly property real maxVol: {
        var m = 0;
        for (var i = 0; i < root.sicht.length; i++)
            m = Math.max(m, root.volumen(root.sicht[i]));
        return m;
    }
    readonly property real letzterPreis: root.sicht.length
                                         ? root.sicht[root.sicht.length - 1][4] : 0

    // ------------------------------------------------------------- CVD
    // Kauf minus Verkauf, aufsummiert. Er beantwortet die Frage, die eine
    // Kerze offen laesst: **wer hat den Kurs bewegt**. Steigt der Kurs und
    // faellt der CVD, kauft niemand -- es wird nur nicht mehr verkauft.
    //
    // Aufsummiert wird ueber das **gezeigte Fenster**, beginnend bei null.
    // Ein absoluter Stand haette keine Bedeutung: die Reihe beginnt dort, wo
    // die Boerse ihre Kerzen beginnt, und niemand liest einen Wert von 2017
    // ab. Verglichen wird immer innerhalb des Bildes.
    readonly property var cvd: {
        var aus = [];
        var summe = 0;
        for (var i = 0; i < root.sicht.length; i++) {
            var k = root.sicht[i];
            summe += (k[5] || 0) - (k[6] || 0);
            aus.push(summe);
        }
        return aus;
    }

    // Die Null gehoert immer ins Bild -- ohne sie sieht eine fallende Reihe
    // im oberen Drittel wie ein Ueberschuss aus.
    readonly property real cvdTief: {
        var m = 0;
        for (var i = 0; i < root.cvd.length; i++)
            m = Math.min(m, root.cvd[i]);
        return m;
    }
    readonly property real cvdHoch: {
        var m = 0;
        for (var i = 0; i < root.cvd.length; i++)
            m = Math.max(m, root.cvd[i]);
        return m;
    }

    // ------------------------------------------------------------ Geometrie
    // **Einmal gerechnet, dreifach benutzt**: von der Leinwand, vom Fadenkreuz
    // und vom Ablesen am Zeiger. Lag die Rechnung im Zeichenblock, rechnete
    // das Fadenkreuz zwangslaeufig ein zweites Mal -- und irgendwann anders.
    readonly property real padR: mass.implicitWidth + 8
    readonly property real padB: root.baseFont * 1.4
    // **Kein Band, solange das Bild in der Vergangenheit steht.** Das Band ist
    // live; neben Kerzen von vor einem halben Jahr stuenden dort Preise von
    // heute, und die Kopfzeile zeigte den einen Wert, das Band den anderen.
    // Zwei Wahrheiten nebeneinander sind schlimmer als eine fehlende.
    readonly property bool bandDa: root.showTape && !root.inVergangenheit
    readonly property real bandHoehe: root.bandDa
                                      ? Math.min(root.height * 0.28, root.baseFont * 11)
                                      : 0
    // Der Schieber unter der Zeitachse. In sehr flachen Flaechen faellt er
    // weg -- dort ist die Kurve selbst schon knapp.
    readonly property bool schieberDa: root.height >= 260
    readonly property real schieberHoehe: root.schieberDa ? root.baseFont * 1.7 : 0
    readonly property real feldBreite: Math.max(1, leinwand.width - root.padR)
    readonly property real volHoehe: (leinwand.height - root.padB) * 0.26
    readonly property real preisHoehe: leinwand.height - root.padB - root.volHoehe
                                       - root.baseFont * 0.4
    readonly property real padT: root.baseFont * 0.2
    readonly property real spanne: {
        var d = root.hoch - root.tief;
        return d > 0 ? d : Math.max(1, root.hoch * 0.0002);
    }
    // **Was wirklich im Bild steht**, nicht was gewaehlt ist. In der Vorschau
    // sind das zwei Monate, obwohl das Fenster auf 24 Stunden steht -- und
    // die Zeitachse muss sich danach richten, sonst stehen Uhrzeiten unter
    // einem Bild von zwei Monaten.
    readonly property real gezeigteSekunden: root.sicht.length > 1
        ? Math.max(1, root.sicht[root.sicht.length - 1][0] - root.sicht[0][0])
        : root.sichtSekunden

    readonly property real kerzeBreite: root.sicht.length
                                        ? root.feldBreite / root.sicht.length : 1

    function yPreis(v) {
        return root.padT + root.preisHoehe * (1 - (v - root.tief) / root.spanne);
    }

    function preisBei(y) {
        return root.tief + root.spanne * (1 - (y - root.padT) / root.preisHoehe);
    }

    function indexBei(x) {
        if (!root.sicht.length)
            return -1;
        var i = Math.floor(x / root.kerzeBreite);
        return Math.max(0, Math.min(root.sicht.length - 1, i));
    }

    // Einmal je Waehrung. Der erste Abruf kostet den Dienst rund sechs
    // Sekunden (vier Seiten bei Binance), danach sind es Millisekunden -- er
    // haelt sie eine halbe Stunde. Bis sie da ist, verhaelt sich der Schieber
    // wie vorher.
    property string uebersichtFuer: ""

    function uebersichtHolen() {
        if (!root.feed || !root.live)
            return;
        if (root.uebersichtFuer === root.currency)
            return;
        var fuer = root.currency;
        root.uebersichtFuer = fuer;
        root.feed.getJson("/market/overview?cur=" + fuer, function (d, err) {
            if (err || !d || !(d.candles || []).length) {
                // Nicht gemerkt lassen -- beim naechsten Anlauf neu versuchen
                if (root.uebersichtFuer === fuer)
                    root.uebersichtFuer = "";
                return;
            }
            root.uebersicht = d.candles;
        });
    }

    function holen() {
        if (!root.feed || !root.live)
            return;
        var pfad = "/market?range=" + root.range
                 + (root.range === "custom" ? "&secs=" + root.customSecs : "")
                 + (root.vonZeit && root.bisZeit
                    ? "&from=" + root.vonZeit + "&to=" + root.bisZeit
                    : (root.fensterEnde ? "&to=" + root.fensterEnde : ""))
                 + "&tape=" + root.bandNr
                 + "&cur=" + root.currency;
        root.feed.getJson(pfad, function (d, err) {
            if (err || !d) {
                root.fehler = err || "nicht erreichbar";
                return;
            }
            root.fehler = "";
            root.kerzen = d.candles || [];
            // Die geholten Kerzen sind jetzt genau der gewuenschte Ausschnitt
            // -- weiter zuzuschneiden waere doppelt. Nur waehrend einer noch
            // laufenden Geste bleibt der oertliche Zoom stehen.
            if (!root.zoomAusstehend)
                root.zoomSekunden = 0;
            root.quellen = d.sources || [];
            root.tradeZahl = d.trades || 0;
            root.umgerechnet = d.converted === true;
            // Nur das Neue anhaengen und vorne abschneiden -- der Dienst
            // schickt seit `bandNr` ohnehin nur das, was dazukam.
            if ((d.tape || []).length) {
                var neu = root.band.concat(d.tape);
                root.band = neu.slice(-60);
                root.bandNr = d.tapeLast || root.bandNr;
            }
            leinwand.requestPaint();
        });
    }

    onRangeChanged: root.holen()
    onCurrencyChanged: {
        // Die Preise im Band sind in der alten Waehrung -- sie stehen sonst
        // neben den neuen Kerzen und niemand sieht, dass sie nicht passen.
        root.band = [];
        root.bandNr = 0;
        // Die Uebersicht traegt ebenfalls Preise: in einer anderen Waehrung
        // ist sie eine andere Reihe und wird neu geholt.
        root.uebersichtFuer = "";
        root.holen();
        root.uebersichtHolen();
    }
    onCustomSecsChanged: if (root.range === "custom") root.holen()
    // Von und Bis kommen als zwei Zuweisungen beim Wirt zurueck. `nachfassen`
    // fasst sie zu einer Abfrage zusammen -- sonst ginge zwischendurch eine
    // mit halbem Fenster raus.
    onVonZeitChanged: nachfassen.restart()
    onBisZeitChanged: nachfassen.restart()
    onLiveChanged: {
        if (root.live) {
            root.holen();
            root.uebersichtHolen();
        }
    }
    Component.onCompleted: {
        root.holen();
        root.uebersichtHolen();
    }

    // Jede Abfrage haelt die Boersenstroeme im Dienst am Leben -- bleibt sie
    // zwei Minuten aus, trennt er sie von selbst. Sieht niemand hin, fragt
    // hier auch niemand.
    Timer {
        interval: 1000
        repeat: true
        // Ein Fenster in der Vergangenheit aendert sich nicht mehr -- es
        // jede Sekunde neu zu holen waere Unfug. Das Band laeuft dann auch
        // nicht weiter; es zeigt die Gegenwart, das Bild die Vergangenheit.
        running: root.live && root.visible && !root.inVergangenheit
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
                  ? Tr.price1(root.letzterPreis, root.zeichen, root.lang) : "–"
            color: root.textColor
            font.pixelSize: root.baseFont * 1.5
            font.weight: Font.DemiBold
        }

        // Am Zeiger die Kerze, sonst wie viel durchgelaufen ist. **Nicht unten
        // rechts** -- dort stand es genau auf der Uhrzeit der Zeitachse
        // ("14:19:5553 Trades").
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.zeigerDa && root.tradeZahl > 0
            text: Tr.t("market.trades", root.lang, Tr.group(root.tradeZahl, root.lang))
            color: root.dimColor
            font.pixelSize: root.baseFont - 2
        }



        // Steht das Fenster in der Vergangenheit, fuehrt ein Klick zurueck.
        // Ohne den kaeme man vom Schieben nur muehsam wieder heim.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.inVergangenheit
            width: heimText.implicitWidth + root.baseFont
            height: Math.round(root.baseFont * 1.7)
            radius: height / 2
            color: heimMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.width: 1
            border.color: root.accentColor

            Text {
                id: heimText

                anchors.centerIn: parent
                text: Tr.t("market.now", root.lang)
                color: root.accentColor
                font.pixelSize: root.baseFont - 2
            }

            MouseArea {
                id: heimMaus

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zurueckZurGegenwart()
            }
        }

        // Steht die Kurve in einer anderen Waehrung als der der Boerse, sagt
        // sie es -- gerechnet wird mit dem heutigen Kurs, auch fuer Kerzen von
        // 2017. **Nicht unten links**: dort steht der Anfang der Zeitachse,
        // und der Hinweis lag genau darauf.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.umgerechnet && root.sicht.length > 0
            text: Tr.t("price.converted", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            opacity: 0.8
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

        // Kerze oder Kurve. **Nur hier** -- der Kursverlauf in der Uhr
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

        // Was unter dem Kurs steht. Ein eigener Umschalter statt beides
        // uebereinander: die Balken zaehlen von null nach oben, der CVD hat
        // eine Null in der Mitte. Zwei Massstaebe in einer Flaeche liest
        // niemand.
        TileGoggles {
            anchors.verticalCenter: parent.verticalCenter
            width: root.baseFont * 8
            alignRight: true
            labelKey: ""
            modes: root.unterarten
            mode: root.lower
            counts: []
            total: 0
            lang: root.lang
            textColor: root.textColor
            dimColor: root.dimColor
            accentColor: root.accentColor
            uiFont: root.baseFont
            onPicked: function (m) {
                root.lowerRequested(m);
            }
        }

        // Eigener Zeitraum: eine Zahl mit Einheit, etwa "72h" oder "90d".
        // Ein Kalender mit Von und Bis waere ein eigenes Bauteil; hierfuer
        // genuegt, was man ohnehin tippen wuerde.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.range === "custom"
            width: (root.vonZeit && root.bisZeit) ? root.baseFont * 15
                                                  : root.baseFont * 5
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
                text: (root.vonZeit && root.bisZeit)
                      ? Qt.formatDateTime(new Date(root.vonZeit * 1000), "dd.MM.yyyy")
                        + ".." + Qt.formatDateTime(new Date(root.bisZeit * 1000), "dd.MM.yyyy")
                      : root.eigenText(root.customSecs)
                onAccepted: {
                    // Zwei Punkte trennen ein ausdrueckliches Fenster:
                    // "01.01.2021..31.03.2021". Ohne sie ist es eine Laenge,
                    // die bis jetzt reicht.
                    if (text.indexOf("..") >= 0) {
                        var teile = text.split("..");
                        var a = root.datumSekunden(teile[0]);
                        var b = root.datumSekunden(teile[1]);
                        if (a > 0 && b > a) {
                            root.fensterEnde = 0;
                            root.vonBisRequested(a, b);
                        }
                        return;
                    }
                    var sek = root.eigenSekunden(text);
                    if (sek > 0) {
                        root.vonBisLoeschen();
                        root.customSecsRequested(sek);
                    }
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
                // Ein ausdrueckliches Fenster schlaegt den Zeitraum: bliebe es
                // stehen, sieht die Wahl hier folgenlos aus.
                root.vonBisLoeschen();
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

    // "31.03.2021" oder "2021-03-31" -> Sekunden. Ohne Uhrzeit gilt der
    // Tagesbeginn in der Zeitzone des Rechners.
    function datumSekunden(text) {
        var t = String(text).trim();
        var m = t.match(/^([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})$/);
        if (m)
            return Math.round(new Date(parseInt(m[3], 10), parseInt(m[2], 10) - 1,
                                       parseInt(m[1], 10)).getTime() / 1000);
        m = t.match(/^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$/);
        if (m)
            return Math.round(new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1,
                                       parseInt(m[3], 10)).getTime() / 1000);
        return 0;
    }

    // Was im Feld steht, muss man lesen koennen.
    //
    // Vorher entschied die **Teilbarkeit** ueber die Einheit: nur was glatt
    // durch ein Jahr, eine Woche, einen Tag oder eine Stunde ging, bekam die
    // passende: alles andere fiel auf Minuten durch. Beim Zoomen ist keine
    // Zahl glatt, und dann stand dort "12215m" -- richtig, und trotzdem
    // unbrauchbar; niemand rechnet das in achteinhalb Tage um.
    //
    // Jetzt entscheidet die **Groesse**: die groesste Einheit, in der noch
    // etwas Ganzes uebrigbleibt. 36 Stunden liest sich besser als 1,5 Tage.
    //
    // **Wochen kommen nicht vor**, obwohl das Feld sie als Eingabe annimmt:
    // die Zeitraeume der Ansicht heissen 1h, 12h, 24h, 7d, 30d und 1y -- in
    // dieser Sprache gibt es keine Wochen, und "26w" neben "30d" waeren zwei
    // Masseinheiten fuer dieselbe Groessenordnung. Getipptes "12w" wird
    // angenommen und als "84d" zurueckgegeben.
    //
    // Die erste Schwelle liegt knapp unter der Stunde, nicht auf ihr: sonst
    // rundet eine Spanne von 3599 Sekunden auf "60m" statt auf "1h".
    function eigenText(sek) {
        if (sek < 3570)
            return root.rundText(sek / 60) + "m";
        if (sek < 86400 * 2)
            return root.rundText(sek / 3600) + "h";
        if (sek < 31536000)
            return root.rundText(sek / 86400) + "d";
        return root.rundText(sek / 31536000) + "y";
    }

    // Grob gerundet, damit es sauber aussieht: ab zehn ganzzahlig, darunter
    // eine Nachkommastelle -- und die faellt weg, wenn sie eine Null waere.
    // **Gerundet wird nur die Anzeige**, der Wert dahinter bleibt genau.
    function rundText(wert) {
        if (wert >= 10 || Math.abs(wert - Math.round(wert)) < 0.05)
            return Tr.group(Math.round(wert), root.lang);
        return Tr.fixed(wert, 1, root.lang);
    }

    // --------------------------------------------------------------- Kerzen
    Canvas {
        id: leinwand

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Der Platz der Ablesezeile bleibt frei, auch wenn sie leer ist --
        // sonst huepft der Graph bei jedem Ueberfahren um eine Zeilenhoehe.
        anchors.topMargin: Math.max(kopf.height, wahl.height)
                           + root.baseFont * 0.25 + ablesen.implicitHeight
                           + root.baseFont * 0.35
        anchors.bottomMargin: root.bandHoehe + root.schieberHoehe
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var n = root.sicht.length;
            if (n < 1)
                return;
            // Waehrend des Ziehens wandert das ganze Bild mit; was rechts oder
            // links fehlt, ist noch nicht geholt und bleibt leer, statt
            // erfunden zu werden.
            if (root.ziehVersatz !== 0)
                ctx.translate(root.ziehVersatz, 0);

            var breiteGesamt = root.feldBreite;
            var kerzeBreite = Math.max(1, root.kerzeBreite);
            var koerper = Math.max(1, Math.min(kerzeBreite * 0.7, kerzeBreite - 1));
            var preisHoehe = root.preisHoehe;
            var lo = root.tief, hi = root.hoch;
            var spanne = root.spanne;
            var padB = root.padB, volHoehe = root.volHoehe;

            function yPreis(v) {
                return root.yPreis(v);
            }

            // Waagerechte Hilfslinien und die Preisachse rechts
            ctx.strokeStyle = root.lineColor;
            ctx.fillStyle = root.dimColor;
            ctx.font = (root.baseFont - 2) + "px " + Fonts.sansCss();
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
            // **Die Vorschau sagt, dass sie eine ist**: gedaempft und als
            // Linie, auch wenn sonst Kerzen stehen. Tageskerzen in einem
            // Fenster, das eigentlich Viertelstunden zeigt, waeren eine
            // Genauigkeit, die die Daten nicht hergeben.
            if (root.vorschau)
                ctx.globalAlpha = 0.55;
            if (root.kind === "line" || root.vorschau) {
                var g = ctx.createLinearGradient(0, root.padT, 0, root.padT + preisHoehe);
                g.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0.28));
                g.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g,
                                          root.accentColor.b, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo(kerzeBreite / 2, root.padT + preisHoehe);
                for (i = 0; i < n; i++)
                    ctx.lineTo(i * kerzeBreite + kerzeBreite / 2, yPreis(root.sicht[i][4]));
                ctx.lineTo((n - 1) * kerzeBreite + kerzeBreite / 2,
                           root.padT + preisHoehe);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = root.accentColor;
                ctx.lineWidth = 1.6;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (i = 0; i < n; i++) {
                    var xl = i * kerzeBreite + kerzeBreite / 2;
                    if (i === 0)
                        ctx.moveTo(xl, yPreis(root.sicht[i][4]));
                    else
                        ctx.lineTo(xl, yPreis(root.sicht[i][4]));
                }
                ctx.stroke();
            }

            // ---- Kerzen ----------------------------------------------------
            for (i = 0; i < n; i++) {
                k = root.sicht[i];
                x = i * kerzeBreite + (kerzeBreite - koerper) / 2;
                steigt = k[4] >= k[1];
                farbe = steigt ? root.upColor : root.downColor;

                if (root.kind === "candles" && !root.vorschau) {
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
                if (root.lower === "volume" && root.maxVol > 0) {
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

            // ---- CVD statt der Balken --------------------------------------
            // **Nach der Schleife**: eine Linie ist keine Folge von Balken,
            // sie braucht alle Punkte auf einmal.
            if (root.lower === "cvd") {
                var cBasis = height - padB;
                var cLo = root.cvdTief, cHi = root.cvdHoch;
                var cSpanne = (cHi - cLo) || 1;

                function yCvd(v) {
                    return cBasis - volHoehe * (v - cLo) / cSpanne;
                }

                // Die Nulllinie zuerst -- an ihr wird abgelesen, ob die
                // Kaeufer oder die Verkaeufer vorn liegen.
                var yNull = yCvd(0);
                ctx.strokeStyle = root.lineColor;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, Math.round(yNull) + 0.5);
                ctx.lineTo(breiteGesamt, Math.round(yNull) + 0.5);
                ctx.stroke();

                var letzterCvd = root.cvd.length ? root.cvd[root.cvd.length - 1] : 0;
                var cvdFarbe = letzterCvd >= 0 ? root.upColor : root.downColor;

                // Flaeche zwischen Linie und Null, damit man die Richtung
                // auch aus dem Augenwinkel sieht
                ctx.beginPath();
                ctx.moveTo(kerzeBreite / 2, yNull);
                for (i = 0; i < n; i++)
                    ctx.lineTo(i * kerzeBreite + kerzeBreite / 2, yCvd(root.cvd[i]));
                ctx.lineTo((n - 1) * kerzeBreite + kerzeBreite / 2, yNull);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(cvdFarbe.r, cvdFarbe.g, cvdFarbe.b, 0.16);
                ctx.fill();

                ctx.strokeStyle = cvdFarbe;
                ctx.lineWidth = 1.4;
                ctx.lineJoin = "round";
                ctx.beginPath();
                for (i = 0; i < n; i++) {
                    var xc = i * kerzeBreite + kerzeBreite / 2;
                    if (i === 0)
                        ctx.moveTo(xc, yCvd(root.cvd[i]));
                    else
                        ctx.lineTo(xc, yCvd(root.cvd[i]));
                }
                ctx.stroke();
            }

            // Zeitachse: Anfang und Ende
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "left";
            ctx.fillText(root.uhrzeit(root.sicht[0][0]), 0, height - 2);
            ctx.textAlign = "right";
            ctx.fillText(root.uhrzeit(root.sicht[n - 1][0]), breiteGesamt, height - 2);
        }
    }

    // Bei einem Tag sagt ein Datum nichts, bei neun Jahren eine Uhrzeit nichts.
    // **Aber die Jahreszahl gehoert dazu**, sobald ueberhaupt ein Datum steht:
    // "31.10." allein ist bei einem Zeitraum, der Jahre umfassen kann, keine
    // Angabe, sondern ein Raten.
    function uhrzeit(ts) {
        var sek = root.gezeigteSekunden;
        if (sek <= 86400 * 2)
            return Qt.formatDateTime(new Date(ts * 1000), "HH:mm");
        if (sek <= 86400 * 400)
            return Qt.formatDateTime(new Date(ts * 1000), "dd.MM.yy");
        return Qt.formatDateTime(new Date(ts * 1000), "MM.yyyy");
    }

    // In der Ablesezeile ist Platz -- dort steht das volle Datum mit Uhrzeit.
    function zeitpunkt(ts) {
        return Qt.formatDateTime(new Date(ts * 1000),
                                 root.gezeigteSekunden <= 86400 * 2 ? "dd.MM.yyyy  HH:mm"
                                                                   : "dd.MM.yyyy");
    }

    // **Das Ablesen steht in einer eigenen Zeile.** In der Kopfzeile wuchs es
    // mit jedem Wert und schob sich unter die Boersenpunkte und die Knoepfe --
    // vier Zahlen mit Beschriftung sind schlicht breiter als der Platz neben
    // dem Preis.
    Text {
        id: ablesen

        anchors.left: parent.left
        anchors.right: wahl.left
        anchors.rightMargin: root.baseFont
        anchors.top: parent.top
        anchors.topMargin: Math.max(kopf.height, wahl.height) + root.baseFont * 0.25
        visible: root.zeigerDa || root.vorschau
        elide: Text.ElideRight
        text: {
            // Beim Ziehen steht hier, **wo** man ist und dass das Bild grob
            // ist. Der Platz war ohnehin freigehalten.
            if (root.vorschau)
                return Tr.t("market.preview", root.lang) + "    "
                     + root.zeitpunkt(root.endeEffektiv);
            if (!root.zeigerDa)
                return "";
            var k = root.sicht[root.zeiger];
            var zeile = root.zeitpunkt(k[0]) + "    O " + Tr.group(k[1], root.lang)
                      + "   H " + Tr.group(k[2], root.lang)
                      + "   L " + Tr.group(k[3], root.lang)
                      + "   C " + Tr.group(k[4], root.lang);
            // Steht der CVD unten, gehoert sein Wert an dieser Stelle dazu --
            // sonst liest man eine Linie ohne Achse ab.
            if (root.lower === "cvd" && root.zeiger < root.cvd.length) {
                var v = root.cvd[root.zeiger];
                zeile += "   CVD " + (v >= 0 ? "+" : "\u2212")
                       + Tr.fixed(Math.abs(v), 1, root.lang) + " \u20bf";
            }
            return zeile;
        }
        color: root.textColor
        font.pixelSize: root.baseFont - 2
        font.family: Fonts.mono()
    }

    // ------------------------------------------- Zoom, Zeiger, Fadenkreuz
    MouseArea {
        id: zeigerFeld

        anchors.fill: leinwand
        anchors.rightMargin: root.padR
        hoverEnabled: true
        // Ziehen verschiebt das Fenster in der Zeit. Die Ansicht folgt dabei
        // sofort -- verschoben wird das gezeichnete Bild --, geholt wird erst,
        // wenn die Hand loslaesst.
        acceptedButtons: Qt.LeftButton
        cursorShape: druck ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property bool druck: false
        property real griffX: 0

        onPressed: function (m) {
            zeigerFeld.druck = true;
            zeigerFeld.griffX = m.x;
        }

        onReleased: {
            if (!zeigerFeld.druck)
                return;
            zeigerFeld.druck = false;
            if (Math.abs(root.ziehVersatz) >= 2) {
                // Nach rechts gezogen heisst: zurueck in die Vergangenheit.
                var proPunkt = root.sichtSekunden / Math.max(1, root.feldBreite);
                root.fensterSetzen(root.endeEffektiv - root.ziehVersatz * proPunkt);
            }
            root.ziehVersatz = 0;
            leinwand.requestPaint();
        }

        onCanceled: {
            zeigerFeld.druck = false;
            root.ziehVersatz = 0;
            leinwand.requestPaint();
        }

        onPositionChanged: function (m) {
            if (zeigerFeld.druck) {
                root.ziehVersatz = m.x - zeigerFeld.griffX;
                root.zeiger = -1;
                leinwand.requestPaint();
                return;
            }
            root.zeiger = root.indexBei(m.x);
            root.zeigerY = m.y;
        }
        onExited: root.zeiger = -1

        // **Das Rad bedient den eigenen Zeitraum.** Hineindrehen verkuerzt
        // ihn, herausdrehen verlaengert ihn -- und weil der Dienst das Raster
        // zum Zeitraum sucht, kommen immer rund zweihundert Kerzen heraus,
        // egal wie tief man hineingeht. Ein fester Zeitraum wird beim ersten
        // Dreh zum eigenen: alles andere waere ein Umschalter, der sich beim
        // Zoomen selbst widerspricht.
        //
        // **Ein `WheelHandler`, kein `onWheel` an der MouseArea.** Die steht
        // hier auf `acceptedButtons: Qt.NoButton`, weil sie nur ueberfahren
        // und nicht geklickt werden soll -- ob sie damit noch Raddrehungen
        // bekommt, ist genau die Art Zusicherung, die man nicht pruefen kann,
        // ohne ein Rad zu drehen. Der Handler ist dafuer gebaut.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (rad) {
                // Ein Rasterschritt sind 120 Achtelgrad; ein Rollfeld meldet
                // feinere Schritte. Beides ueber denselben Faktor, damit sich
                // Maus und Rollfeld gleich anfuehlen.
                var schritte = rad.angleDelta.y / 120;
                if (!schritte)
                    return;
                root.zoomen(Math.pow(1 / 1.35, schritte));
            }
        }
    }

    // Wie lang ein benannter Zeitraum ist -- fuer den ersten Dreh am Rad
    function sekundenVon(r) {
        switch (r) {
        case "1h":
            return 3600;
        case "12h":
            return 43200;
        case "24h":
            return 86400;
        case "7d":
            return 604800;
        case "30d":
            return 2592000;
        case "1y":
            return 31536000;
        case "all":
            // Binance beginnt am 31.07.2017
            return Math.round(Date.now() / 1000) - 1501459200;
        }
        return root.customSecs;
    }

    readonly property bool zeigerDa: root.zeiger >= 0 && root.zeiger < root.sicht.length

    // Senkrechte durch die Kerze unter dem Zeiger
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x + (root.zeiger + 0.5) * root.kerzeBreite
        y: leinwand.y + root.padT
        width: 1
        height: root.preisHoehe
        color: root.dimColor
        opacity: 0.7
    }

    // Waagerechte auf Hoehe des Zeigers
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x
        y: leinwand.y + root.zeigerY
        width: root.feldBreite
        height: 1
        color: root.dimColor
        opacity: 0.7
    }

    // Der Preis an der Waagerechten, rechts auf der Achse
    Rectangle {
        visible: root.crosshair && root.zeigerDa
        x: leinwand.x + root.feldBreite + 2
        y: leinwand.y + root.zeigerY - height / 2
        width: preisMarke.implicitWidth + 8
        height: preisMarke.implicitHeight + 4
        radius: 3
        color: root.accentColor

        Text {
            id: preisMarke

            anchors.centerIn: parent
            text: Tr.group(root.preisBei(root.zeigerY), root.lang)
            color: "#11131f"
            font.pixelSize: root.baseFont - 2
        }
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
        function onSichtChanged() {
            leinwand.requestPaint();
        }
    }

    // ------------------------------------------------ Schieber der Zeit
    // Die ganze Breite ist die ganze Geschichte -- vom ersten Handelstag bei
    // Binance bis jetzt. Der Griff ist das gezeigte Fenster: er sagt zugleich,
    // **wo** man ist und **wie viel** man sieht. Ziehen verschiebt, ein Klick
    // daneben springt.
    Item {
        id: schieber

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: root.padR
        anchors.bottom: bandFeld.visible ? bandFeld.top : parent.bottom
        height: root.schieberHoehe
        visible: root.schieberDa

        readonly property real gesamt: Math.max(1, root.jetzt - root.beginn)
        readonly property real anteil: Math.min(1, root.sichtSekunden / gesamt)
        readonly property real griffBreite: Math.max(10, width * anteil)
        readonly property real griffX: {
            var start = root.endeEffektiv - root.sichtSekunden;
            var t = (start - root.beginn) / schieber.gesamt;
            return Math.max(0, Math.min(width - schieber.griffBreite, t * width));
        }

        // Ein Zeitpunkt aus einer Stelle auf der Leiste
        function zeitBei(x) {
            return root.beginn + schieber.gesamt * Math.max(0, Math.min(1, x / width));
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(3, root.baseFont * 0.35)
            radius: height / 2
            color: root.lineColor
        }

        Rectangle {
            id: griff

            // **Ziehen zerreisst die Bindung.** `drag.target` schreibt `x`
            // unmittelbar, und damit folgt der Griff danach nicht mehr dem
            // Fenster -- ein Klick neben den Griff verschob bisher das Bild,
            // aber nicht den Griff. Nach jeder Geste wird sie deshalb neu
            // geknuepft.
            function bindungZurueck() {
                griff.x = Qt.binding(function () {
                    return schieber.griffX;
                });
            }

            x: schieber.griffX
            width: schieber.griffBreite
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(7, root.baseFont * 0.8)
            radius: height / 2
            color: griffMaus.pressed || griffMaus.containsMouse
                   ? root.accentColor : root.dimColor

            MouseArea {
                id: griffMaus

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                drag.target: griff
                drag.axis: Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: schieber.width - griff.width
                drag.threshold: 0

                // Solange gezogen wird, zeichnet die Ansicht aus der
                // Uebersicht. Geholt wird erst beim Loslassen -- ein frisches
                // Fenster kostet ueber eine Sekunde, und am Schieber waere
                // jede Handbewegung eines.
                onPressed: root.vorschau = true

                onPositionChanged: {
                    if (!drag.active)
                        return;
                    // Der Griff steht fuer den **Anfang** des Fensters
                    root.fensterSchieben(schieber.zeitBei(griff.x) + root.sichtSekunden);
                }

                onReleased: {
                    root.vorschau = false;
                    root.fensterSetzen(schieber.zeitBei(griff.x) + root.sichtSekunden);
                    griff.bindungZurueck();
                }

                onCanceled: {
                    root.vorschau = false;
                    griff.bindungZurueck();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            // Neben den Griff geklickt: dorthin springen, Fenstermitte auf
            // die angeklickte Stelle.
            onClicked: function (m) {
                root.fensterSetzen(schieber.zeitBei(m.x) + root.sichtSekunden / 2);
            }
        }
    }

    // -------------------------------------------------- Laufendes Band
    // Die Trades, wie sie hereinkommen -- juengster oben. Der Dienst hebt nur
    // auf, was ueber tausend Dollar liegt, und schickt je Abfrage nur das
    // Neue; hier stehen die letzten, so viele wie Platz ist.
    ListView {
        id: bandFeld

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.bandHoehe
        visible: root.bandDa
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        // Der juengste Trade steht oben. Wer zurueckblaettert, soll dabei
        // nicht von jedem neuen Trade wieder nach oben gerissen werden --
        // deshalb kein Nachfuehren der Lage.
        model: root.bandUmgekehrt

        delegate: Item {
            id: zeile

            required property var modelData

            width: bandFeld.width
            height: Math.round(root.baseFont * 1.35)

            // Wie stark eine Zeile heraussticht, entscheidet ihr Betrag.
            // Unter zehntausend bleibt sie ein Strich am Rand, darueber
            // faerbt sie sich durch -- so sieht man Grosses, ohne dass
            // Kleines verschwindet.
            readonly property real wucht: Math.max(0, Math.min(1,
                (zeile.modelData[3] - 1000) / 99000))

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: root.padR
                color: zeile.modelData[4] ? root.upColor : root.downColor
                opacity: 0.10 + zeile.wucht * 0.5
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(zeile.modelData[1] * 1000), "HH:mm:ss")
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
                font.family: Fonts.mono()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: root.baseFont * 5
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.group(zeile.modelData[2], root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont - 2
                font.family: Fonts.mono()
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.padR + 6
                anchors.verticalCenter: parent.verticalCenter
                text: root.zeichen + " " + Tr.group(zeile.modelData[3], root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont - 2
                font.family: Fonts.mono()
                font.bold: zeile.wucht > 0.4
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.padR + root.baseFont * 7
                anchors.verticalCenter: parent.verticalCenter
                text: zeile.modelData[5]
                color: root.dimColor
                font.pixelSize: root.baseFont - 3
            }
        }
    }

    // ------------------------------------------------------------ Hinweise
    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.sicht.length
        text: root.fehler !== "" ? Tr.t("market.failed", root.lang, root.fehler)
                                 : Tr.t("market.waiting", root.lang)
        color: root.dimColor
        font.pixelSize: root.baseFont
    }


}
