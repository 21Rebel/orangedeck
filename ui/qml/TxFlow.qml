// Der Fluss einer Transaktion: Eingaenge links, Ausgaenge rechts, die Hoehe
// jedes Bandes im Verhaeltnis zum Betrag.
//
// Aufbau wie im Original (mempool.space,
// frontend/src/app/components/tx-bowtie-graph/tx-bowtie-graph.component.ts,
// am 01.09.2026 nachgelesen). Drei Dinge davon uebernommen:
//
//   * **Keine Verjuengung.** Ein Band behaelt seine Hoehe von links nach
//     rechts. Was in der Mitte schmaler wirkt, sind nur die geschlossenen
//     Luecken -- am Rand stehen die Baender mit Abstand, im Strang lueckenlos.
//   * **Die Gebuehr ist ein Ausgang wie jeder andere**, nur in eigener Farbe.
//     Im Original `voutWithFee.unshift({ type: 'fee', value: tx.fee })`, also
//     an erster Stelle. Dadurch geht die Rechnung von selbst auf: Summe links
//     gleich Summe rechts.
//   * **Mindestdicke**, damit kleine Betraege nicht verschwinden. Im Original
//     `minWeight = 2` mit `Math.max(minWeight - 1, weight) + 1`.
//
// Dass alle Eingaenge zu einem Strang zusammenlaufen, ist keine Vereinfachung:
// welcher Eingang welchen Ausgang bezahlt, laesst sich in Bitcoin **nicht**
// sagen. Einzelverbindungen waeren erfunden.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"

    property var vin: []
    property var vout: []
    property real fee: 0
    property color inColor: "#5b8dd9"
    property color outColor: "#f7931a"
    property color feeColor: "#8a7f9c"
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property real labelSize: 10
    // Wie viele Baender einzeln gezeigt werden; der Rest wird zusammengefasst.
    // Das Original nennt das `maxStrands = 24` ("number of inputs/outputs to
    // keep fully on-screen") und begrenzt zusaetzlich auf `lineLimit = 250`.
    // Hier zusaetzlich an die Hoehe gekoppelt: unter etwa sieben Bildpunkten je
    // Band bleibt fuer die Luecken nichts mehr uebrig.
    // Das Original zeichnet bis zu `lineLimit = 250` Faeden; `maxStrands = 24`
    // meint nur, wie viele **vollstaendig** auf den Schirm passen sollen. Mit
    // 24 als harter Grenze fehlten hier sichtbar Eingaenge.
    property int maxBands: 250
    readonly property int bandLimit: Math.max(4, Math.min(maxBands,
                                     Math.floor(innerH / Math.max(1.6, minBand + 0.6))))
    // Duenn genug, dass bei vielen Eingaengen noch Luft zwischen den Faeden
    // bleibt. Zu dick wirkt der Kamm am Rand gedrungen: bei 250 Faeden zu je
    // 1,3 px blieben nur 0,7 px Luecke, bei 0,8 px sind es 1,2 px.
    property real minBand: Math.max(0.8, labelSize * 0.1)
    // Abstand zwischen zwei Baendern **am Rand**. Im Strang sind sie
    // lueckenlos -- daher wirkt er geschlossen, ohne dass ein Band schrumpft.
    // Wie schmal der Strang gegenueber den Raendern wird. **Nicht** durch
    // Verjuengung -- die Baender behalten ihre Dicke. Der Lueckenanteil am Rand
    // wird daraus abgeleitet: was dort zwischen den Baendern frei bleibt, faellt
    // im Strang weg, und genau darum ist er schmaler.
    //
    // Der Wert kommt aus dem Original (mempool.space, tx-bowtie-graph, am
    // 01.09.2026 gelesen):
    //
    //   combinedWeight = min(maxCombinedWeight /* 100 */, floor((txWidth - 2*midWidth)/6))
    //   innerTop       = height/2 - combinedWeight/2
    //   spacing        = max(4, (height - visibleWeight) / gaps)
    //
    // Bei ihrer Vorgabe 1200 x 600 sind das 100 von 600 Bildpunkten -- alle
    // Baender zusammen belegen **ein Sechstel** der Hoehe, die Luecken den
    // ganzen Rest. Genau daher die duennen Faeden und die weite Rundung. Hier
    // etwas grosszuegiger, weil die Flaeche viel flacher ist als ihre.
    //
    // Bei einem einzigen Band gibt es keine Luecke und damit keine Taille --
    // da ist auch nichts zusammenzufuehren.
    // **Ein fester Wert, keine Quote.** Im Original ist `combinedWeight` eine
    // Pixelzahl (100), die unabhaengig von der Bandzahl gleich bleibt; die
    // Zeichenflaeche waechst stattdessen mit der Zahl der Baender. Dadurch
    // bleibt der Strang immer gleich dick, waehrend sich die Luecken am Rand
    // immer weiter aufziehen -- daher die weite Rundung bei vielen Eingaengen
    // und das satte Band bei einem einzigen.
    //
    // Eine feste Quote kann das nicht: bei ihr waere das Verhaeltnis von
    // Luecke zu Band immer dasselbe, egal wie viele es sind.
    property real trunkPx: labelSize * 5
    readonly property real trunkH: Math.max(minBand, Math.min(innerH * 0.62, trunkPx))
    // Wie stark die Baender schwingen. 0,5 ergibt eine brave Sinusform, hoehere
    // Werte lassen sie flacher ansetzen und in der Mitte steiler laufen.
    property real swing: 0.78
    property real edgeGap: Math.max(2, labelSize * 0.3)
    // Abstand des Pfeils vom rechten Rand -- ohne ihn klebt er an der Kante.
    property real edgeMargin: Math.max(4, Math.min(width * 0.012, labelSize))

    // Ein kurzes gerades Stueck vor dem Eingang und hinter dem Ausgang, das
    // nach aussen in nichts uebergeht. Es sagt: hier hoert die Transaktion
    // nicht auf, davor haengt eine andere und danach geht es weiter. Das
    // Original macht das genauso (die kurzen Balken links und rechts am
    // Fluss auf mempool.space).
    property real stubLen: Math.max(10, Math.min(width * 0.075, 90))
    // **Keine Luecke zwischen Anschlussstueck und Band.** Vorher stand dort
    // eine, damit die Kerbe sich abhob -- im Original ist es genau umgekehrt:
    // beides ist **ein durchgehendes Band**, und die Kerbe allein trennt die
    // beiden Teile. Sie ist das einzige Trennende, an beiden Enden.

    // **Ein Winkel fuer beide Enden.** Vorher war die Spitze rechts auf eine
    // feste Laenge gedeckelt und der Pfeil links wuchs mit der Banddicke -- an
    // einem dicken Band trafen dadurch zwei verschiedene Steigungen aufeinander.
    // Jetzt haengt beides an derselben Formel: atan((h/2) / (h * headRatio)).
    function tipFor(thickness) {
        return root.headFor(thickness);
    }

    // Pfeil am **Anfang** der Eingaenge. Im Original sind das SVG-Marker mit
    // `markerUnits="strokeWidth"`, sie wachsen also mit der Banddicke -- an
    // duennen Faeden sieht man sie kaum, an dicken deutlich. Sie zeigen, dass
    // sich die Kette von dort aus weiterverfolgen laesst.
    // **0,55 ist aus dem Original ausgerechnet, nicht geschaetzt.** Dort ist der
    // Pfeil ein SVG-Marker mit `viewBox="-5 -5 10 10"`, `markerWidth="1.5"`,
    // `markerHeight="1"` und `markerUnits="strokeWidth"`. Bei der voreingestellten
    // Erhaltung des Seitenverhaeltnisses gilt der kleinere der beiden Massstaebe,
    // also 1/10 der Banddicke je Einheit: die Kerbe ist zehn Einheiten hoch (die
    // volle Dicke) und fuenf tief -- **eine halbe Banddicke, also 45 Grad**. Mit
    // 1,1 lag der Winkel bei 24 Grad, die Kerbe war viel zu spitz.
    property real headRatio: 0.55

    function headFor(thickness) {
        // Der Deckel haelt die Kerbe im geraden Stueck. Er lag bei 0,9 mal dem
        // Anschluss und griff schon bei mittleren Baendern -- der Winkel wurde
        // dadurch flacher als die 45 Grad der Vorlage, genau was er nicht soll.
        // Das dickste Band misst `trunkH`, hoechstens `labelSize * 5`, der
        // Anschluss `labelSize * 2`: 0,55 * 5 / 2 = 1,375. Mit 1,4 greift der
        // Deckel im Regelfall nicht mehr, und die Kerbe darf hoechstens in den
        // flachen Anfang der Kurve hineinreichen.
        return Math.max(2, Math.min(connector * 1.4, thickness * root.headRatio));
    }
    // Oben und unten bleibt Platz -- der Fluss soll frei liegen, nicht am
    // Bildrand kleben.
    property real padY: Math.max(6, height * 0.11)
    // Gerades Anschlussstueck an beiden Enden, bevor die Kurve beginnt
    property real connector: Math.max(6, Math.min(width * 0.05, labelSize * 2))
    readonly property real innerH: Math.max(8, height - 2 * padY)
    // **Nicht im RGB-Raum mischen.** Blau (H 216°) und Orange (H 33°) liegen
    // 177° auseinander, also fast gegenueber -- ihre RGB-Mitte faellt auf 28 %
    // Saettigung und wirkt grau. Nachgerechnet am 01.09.2026.
    //
    // Ueber den Farbkreis gemischt bleibt die Saettigung erhalten. Aufwaerts
    // fuehrt der Weg ueber Magenta (H 305°), abwaerts ueber Gruen (H 125°).
    // Magenta passt zum Orange und entspricht dem, was das Original tut, das
    // von Violett nach Blau laeuft.
    property bool hueUp: true

    function mixHue(a, b, t) {
        var ha = a.hsvHue < 0 ? 0 : a.hsvHue * 360;
        var hb = b.hsvHue < 0 ? 0 : b.hsvHue * 360;
        var d = root.hueUp ? ((hb - ha) + 360) % 360 : -(((ha - hb) + 360) % 360);
        var h = ((ha + d * t) % 360 + 360) % 360;
        var sa = a.hsvSaturation, sb = b.hsvSaturation;
        var va = a.hsvValue, vb = b.hsvValue;
        return Qt.hsva(h / 360, sa + (sb - sa) * t, va + (vb - va) * t, 1);
    }

    // Farbe an der Stelle t (0 = ganz links, 1 = ganz rechts)
    function flowColor(t) {
        return mixHue(root.inColor, root.outColor, Math.max(0, Math.min(1, t)));
    }

    readonly property color midColor: flowColor(0.5)

    property var hovered: null
    // Wo der Zeiger steht -- die Angaben stehen daneben, nicht am Fussrand.
    // So wie im Original: man liest dort, wo man hinsieht.
    property real zeigerX: 0
    property real zeigerY: 0
    // Die Transaktion selbst. Im Strang gehoeren beide Seiten zu ihr, deshalb
    // steht sie dort ueber den Angaben.
    property string txid: ""

    signal activated(string side, int index)

    // Die Gebuehr zaehlt als Ausgang, damit beide Seiten gleich hoch sind
    readonly property var voutWithFee: {
        var l = [];
        if (fee > 0)
            l.push({ "__fee": true, "value": fee });
        var v = vout || [];
        for (var i = 0; i < v.length; i++)
            l.push(v[i]);
        return l;
    }

    readonly property real totalIn: {
        var s = 0, v = vin || [];
        for (var i = 0; i < v.length; i++)
            s += (v[i].prevout && v[i].prevout.value) || 0;
        return s;
    }

    property var bandsIn: []
    property var bandsOut: []

    onVinChanged: rebuild()
    onVoutChanged: rebuild()
    onFeeChanged: rebuild()
    onWidthChanged: rebuild()
    onHeightChanged: rebuild()
    Component.onCompleted: rebuild()

    // Ein Band behaelt seine Hoehe; nur die Luecken unterscheiden Rand und
    // Strang. `edgeY` ist die Lage am Rand (mit Luecken), `midY` die im Strang
    // (ohne). Beide Stapel werden am Ende auf die Hoehe normiert.
    // Lage und Strichstaerke sind **zwei verschiedene Dinge** -- das ist der
    // Kern der Darstellung und war lange falsch:
    //
    //   Gewicht   der echte Anteil am Betrag. Alle Gewichte zusammen ergeben
    //             genau `trunkH`. Danach richtet sich die **Lage** im Strang.
    //   Dicke     womit gezeichnet wird, mindestens `minBand`. Ist ein Band
    //             duenner als das Minimum, ueberlappt es seine Nachbarn im
    //             Strang -- und genau dadurch bleibt der Strang schmal, obwohl
    //             zweihundertfuenfzig Faeden hineinlaufen.
    //
    // Vorher wurde beides gleichgesetzt und der Strang auf die Summe der
    // Mindestdicken aufgezogen: bei 250 Baendern zu je 1,2 px waren das 300 px
    // statt der vorgesehenen 40. Im Original steht dazu:
    //
    //   thickness = min(combinedWeight + 0.5, max(minWeight - 1, w) + 1)
    //   innerY    = min(innerBottom - thickness/2,
    //                   max(innerTop + thickness/2, lastInner + weight/2))
    //
    // -- die Lage kommt aus `weight`, die Dicke aus `thickness`.
    function build(list, valueOf, total) {
        var n = Math.min(list.length, root.bandLimit);
        var out = [];
        var i;

        function add(v, more, idx) {
            out.push({ "i": idx, "v": v, "more": more || 0, "fee": false });
        }

        for (i = 0; i < n; i++)
            add(valueOf(list[i]) || 0, 0, i);
        if (list.length > n) {
            var rest = 0;
            for (i = n; i < list.length; i++)
                rest += valueOf(list[i]) || 0;
            add(rest, list.length - n, -1);
        }

        // Kann leer sein, wenn die eine Seite schon gesetzt ist und die andere
        // noch nicht -- die Eigenschaften kommen nacheinander an. Ohne diese
        // Zeile lief der Aufbau danach in `out[0]` von einer leeren Liste.
        if (!out.length)
            return out;

        var t = total > 0 ? total : 1;
        var sumThick = 0;
        for (i = 0; i < out.length; i++) {
            out[i].weight = (out[i].v / t) * root.trunkH;
            out[i].thick = Math.max(root.minBand, out[i].weight);
            sumThick += out[i].thick;
        }
        // Passen die Dicken nicht nebeneinander an den Rand, alle gleichmaessig
        // duenner machen -- sonst laeuft der Faecher unten heraus.
        if (sumThick > root.innerH) {
            var f = root.innerH / sumThick;
            for (i = 0; i < out.length; i++)
                out[i].thick *= f;
            sumThick = root.innerH;
        }

        // --- Lage im Strang: nach Gewicht, mittig ---------------------------
        //
        // Gezeichnet wird ein Band ueberall mit derselben Dicke -- am Rand wie
        // im Strang, das ist der Kern der Darstellung. Die **gezeichnete**
        // Hoehe des Strangs ist deshalb nicht die Summe der Gewichte: oben und
        // unten steht das erste und das letzte Band um die Haelfte dessen
        // ueber, was ihm die Mindestdicke ueber sein Gewicht hinaus gibt.
        //
        // Dieser Ueberstand ist auf beiden Seiten verschieden gross -- links
        // steht vielleicht ein dicker Eingang oben, rechts die winzige
        // Gebuehr. Genau daran wurde die eine Seite an der Naht sichtbar
        // dicker als die andere. Also wird der Platz fuer die Gewichte um die
        // beiden Ueberstaende gekuerzt; dann misst der gezeichnete Strang auf
        // beiden Seiten genau `trunkH`, und die Naht stimmt.
        var ueOben = Math.max(0, (out[0].thick - out[0].weight) / 2);
        var letzt = out[out.length - 1];
        var ueUnten = Math.max(0, (letzt.thick - letzt.weight) / 2);
        var k = root.trunkH > 0
            ? Math.max(0.2, (root.trunkH - ueOben - ueUnten) / root.trunkH) : 1;
        var trunkTop = root.padY + (root.innerH - root.trunkH) / 2 + ueOben;
        var acc = 0;
        for (i = 0; i < out.length; i++) {
            var anteil = out[i].weight * k;
            out[i].hMid = out[i].thick;
            out[i].midY = trunkTop + acc + anteil / 2 - out[i].thick / 2;
            acc += anteil;
        }

        // --- Lage am Rand: nach Dicke, mit Luecken --------------------------
        var nGaps = Math.max(0, out.length - 1);
        var gap = nGaps > 0 ? Math.max(0, (root.innerH - sumThick) / nGaps) : 0;
        var ey = nGaps > 0 ? root.padY : root.padY + (root.innerH - sumThick) / 2;
        for (i = 0; i < out.length; i++) {
            out[i].hEdge = out[i].thick;
            out[i].edgeY = ey;
            ey += out[i].thick + gap;
        }
        return out;
    }

    function rebuild() {
        if (width <= 0 || height <= 0 || totalIn <= 0) {
            bandsIn = [];
            bandsOut = [];
            canvas.requestPaint();
            return;
        }
        // Beide Seiten tragen denselben Gesamtbetrag (die Gebuehr zaehlt als
        // Ausgang) -- damit ergibt sich derselbe Strang, und sie treffen sich
        // in der Mitte genau.
        bandsIn = build(vin || [], function (e) {
            return (e.prevout && e.prevout.value) || 0;
        }, totalIn);
        var bo = build(voutWithFee, function (e) {
            return e.value || 0;
        }, totalIn);
        if (fee > 0 && bo.length)
            bo[0].fee = true;
        bandsOut = bo;
        canvas.requestPaint();
    }

    Canvas {
        id: canvas

        anchors.fill: parent

        // Waagerecht ansetzende S-Kurve -- die Baender laufen an beiden Enden
        // flach aus, dazwischen der Schwung.
        function curve(ctx, x0, y0, x1, y1) {
            var d = (x1 - x0) * root.swing;
            ctx.bezierCurveTo(x0 + d, y0, x1 - d, y1, x1, y1);
        }

        // Eine winkelfoermige Kerbe quer durchs Band, nach rechts weisend.
        // Herausgeschnitten statt aufgemalt (`destination-out`): so bleibt sie
        // von der Farbe des Bandes unabhaengig und passt sich jedem Verlauf an.
        // Die Baender liegen an dieser Stelle weit auseinander, es wird also
        // nichts anderes mitgetroffen.
        function notch(ctx, x, cy, len, thickness) {
            if (len < 1.5 || thickness < 2)
                return;
            var alt = ctx.globalCompositeOperation;
            ctx.globalCompositeOperation = "destination-out";
            // Im Original ist die Kerbe keine Linie, sondern die **Luecke**
            // zwischen dem Klotz am Bandanfang und dem Band selbst -- sie
            // waechst also mit der Dicke. Nachgemessen an der Vorlage sind das
            // rund 8 % der Banddicke; 2,5 Bildpunkte Deckel liessen davon an
            // einem dicken Band ein Haar uebrig.
            ctx.lineWidth = Math.max(1, Math.min(10, thickness * 0.08));
            ctx.lineJoin = "miter";
            ctx.strokeStyle = "#000000";
            ctx.beginPath();
            ctx.moveTo(x, cy - thickness / 2);
            ctx.lineTo(x + len, cy);
            ctx.lineTo(x, cy + thickness / 2);
            ctx.stroke();
            ctx.globalCompositeOperation = alt;
            ctx.lineJoin = "round";
        }

        // Das kurze Stueck am Rand: eine Seite voll, die andere in nichts
        // auslaufend. `nachAussenRechts` sagt, wohin ausgeblendet wird.
        function stub(ctx, x, len, cy, thickness, col, nachAussenRechts, lit) {
            if (len < 1 || thickness < 0.5)
                return;
            var c = lit ? Qt.lighter(col, 1.35) : col;
            var g = ctx.createLinearGradient(x, 0, x + len, 0);
            var a0 = nachAussenRechts ? 1 : 0;
            var a1 = nachAussenRechts ? 0 : 1;
            // Gleichmaessig, ohne Stuetzstelle in der Mitte: mit ihr sass die
            // Deckkraft dort zu hoch und der Balken wirkte wie ein Kloetzchen
            // statt wie ein Auslaufen.
            g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, a0));
            g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, a1));
            ctx.strokeStyle = g;
            ctx.lineWidth = thickness;
            ctx.beginPath();
            ctx.moveTo(x, cy);
            ctx.lineTo(x + len, cy);
            ctx.stroke();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.bandsIn.length)
                return;

            var w = width;
            // Links: Anschlussstueck, Luecke, dann erst das Band mit der Kerbe.
            var xIn = root.stubLen;
            var xL = xIn + root.connector;
            var xC = w * 0.5;
            var xEnd = w - root.edgeMargin - root.stubLen;
            var xR = xEnd - root.connector;
            // Die beiden Seiten stossen in der Mitte aneinander -- ein halber
            // Bildpunkt Ueberlappung, damit dort keine Naht bleibt.
            var seam = 0.75;
            var i, b, lit, g, k, cEdge, cMid;

            // **Als Strich gezeichnet, nicht als gefuellte Flaeche.** Fuellt man
            // zwischen zwei Kurven mit gleichem *senkrechtem* Abstand, wird das
            // Band in steilen Abschnitten duenner: bei 60 Grad Steigung bleibt
            // nur die Haelfte. Ein Strich hat dagegen ueberall dieselbe Dicke.
            // Das Original macht es genauso ("stroke-width: combinedWeight").
            ctx.lineCap = "butt";
            ctx.lineJoin = "round";

            for (i = 0; i < root.bandsIn.length; i++) {
                b = root.bandsIn[i];
                lit = root.hovered && root.hovered.side === "in" && root.hovered.index === b.i;
                g = ctx.createLinearGradient(0, 0, xC, 0);
                for (k = 0; k <= 4; k++) {
                    var ck = root.flowColor(k / 8);
                    var cl = lit ? Qt.lighter(ck, 1.35) : ck;
                    g.addColorStop(k / 4, Qt.rgba(cl.r, cl.g, cl.b, 1));
                }
                cEdge = b.edgeY + b.hEdge / 2;
                cMid = b.midY + b.hMid / 2;
                var head = root.headFor(b.hEdge);
                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                // Das Band laeuft **durch** bis an den Rand. Vorher begann es
                // hinter dem Pfeil, und weil der Strich stumpf endet, blieb
                // zwischen der schraegen Kante des Dreiecks und der senkrechten
                // Kante des Bandes beidseits ein Spalt stehen.
                ctx.moveTo(xIn, cEdge);
                ctx.lineTo(xL, cEdge);
                canvas.curve(ctx, xL, cEdge, xC + seam, cMid);
                ctx.stroke();
                canvas.stub(ctx, 0, root.stubLen, cEdge, b.hEdge, root.flowColor(0), false, lit);
                // Der Pfeil ist jetzt eine **Kerbe im Band**, kein angesetztes
                // Dreieck: ein schmaler Winkel wird wieder herausgeschnitten.
                // Dadurch gibt es keine Naht, und die Richtung bleibt lesbar.
                canvas.notch(ctx, xIn, cEdge, head, b.hEdge);
            }

            for (i = 0; i < root.bandsOut.length; i++) {
                b = root.bandsOut[i];
                lit = root.hovered && root.hovered.side === "out" && root.hovered.index === b.i;
                var col = b.fee ? root.feeColor : root.outColor;
                g = ctx.createLinearGradient(xC, 0, w, 0);
                if (b.fee) {
                    g.addColorStop(0, Qt.rgba(root.midColor.r, root.midColor.g, root.midColor.b, 1));
                    g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 1));
                } else {
                    for (k = 0; k <= 4; k++) {
                        var cq = root.flowColor(0.5 + k / 8);
                        var cr = lit ? Qt.lighter(cq, 1.35) : cq;
                        g.addColorStop(k / 4, Qt.rgba(cr.r, cr.g, cr.b, 1));
                    }
                }
                cEdge = b.edgeY + b.hEdge / 2;
                cMid = b.midY + b.hMid / 2;

                // **Keine Spitze mehr.** Das Band laeuft stumpf bis an den
                // Block am Rand, und der haengt unmittelbar daran -- getrennt
                // allein durch die Kerbe, genau wie am linken Ende. Vorher
                // standen hier drei Teile: Band, Spitze, Luecke, Block.
                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                ctx.moveTo(xC - seam, cMid);
                canvas.curve(ctx, xC - seam, cMid, xR, cEdge);
                ctx.lineTo(xEnd, cEdge);
                ctx.stroke();

                // Erst der Block, dann die Kerbe: sie schneidet heraus, was
                // schon steht, und muss deshalb zuletzt kommen -- sonst
                // fuellt der Block sie wieder auf.
                canvas.stub(ctx, xEnd, root.stubLen, cEdge, b.hEdge,
                            b.fee ? root.feeColor : root.flowColor(1), true, lit);
                // Die Kerbe sitzt auf der Naht: die Schenkel an der Kante des
                // Bandes, die Spitze im Block. Dieselbe wie am Eingang.
                canvas.notch(ctx, xEnd, cEdge, root.tipFor(b.hEdge), b.hEdge);
            }

            if (root.fee > 0 && root.bandsOut.length) {
                var fb = root.bandsOut[0];
                ctx.font = root.labelSize + "px sans-serif";
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                var ty = fb.edgeY - root.labelSize * 0.45;
                if (ty < root.labelSize)
                    ty = fb.edgeY + fb.hEdge + root.labelSize;
                ctx.fillText(Tr.t("flow.fee", root.lang, root.fee), w - root.edgeMargin, ty);
            }
        }
    }

    function bandAt(px, py) {
        var side = px < width * 0.5 ? "in" : "out";
        var list = side === "in" ? bandsIn : bandsOut;
        var edge = side === "in" ? px < width * 0.25 : px > width * 0.75;
        for (var i = 0; i < list.length; i++) {
            var b = list[i];
            var y0 = edge ? b.edgeY : b.midY;
            var y1 = y0 + (edge ? b.hEdge : b.hMid);
            if (py >= y0 && py <= y1)
                return { "side": b.fee ? "fee" : side, "index": b.i,
                         "value": b.v, "more": b.more, "edge": edge };
        }
        return null;
    }

    // Die Adresse zu einem Band. Am Rand steht sie, im Strang gehoert sie
    // ebenso dazu -- dort kommt nur die Transaktion darueber.
    function addrFor(hv) {
        if (!hv || hv.index < 0)
            return "";
        var e;
        if (hv.side === "in") {
            e = (root.vin || [])[hv.index];
            return (e && e.prevout && e.prevout.scriptpubkey_address) || "";
        }
        if (hv.side === "out") {
            e = root.voutWithFee[hv.index];
            return (e && e.scriptpubkey_address) || "";
        }
        return "";
    }

    function titleFor(hv) {
        if (!hv)
            return "";
        if (hv.side === "fee")
            return Tr.t("flow.fee", root.lang, root.fee);
        if (hv.more)
            return Tr.t("flow.more", root.lang, hv.more);
        var n = hv.index + (hv.side === "out" && root.fee > 0 ? 0 : 1);
        return Tr.t(hv.side === "in" ? "flow.in" : "flow.out", root.lang, n);
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onPositionChanged: mouse => {
            root.zeigerX = mouse.x;
            root.zeigerY = mouse.y;
            var b = root.bandAt(mouse.x, mouse.y);
            if (JSON.stringify(b) !== JSON.stringify(root.hovered)) {
                root.hovered = b;
                canvas.requestPaint();
            }
        }
        onExited: {
            root.hovered = null;
            canvas.requestPaint();
        }
        onClicked: {
            if (!root.hovered || root.hovered.side === "fee" || root.hovered.index < 0)
                return;
            // Die Gebuehr steht vorn in der Liste -- der Index der echten
            // Ausgaenge ist deshalb um eins verschoben.
            var idx = root.hovered.index;
            if (root.hovered.side === "out" && root.fee > 0)
                idx -= 1;
            if (idx >= 0)
                root.activated(root.hovered.side, idx);
        }
    }

    // Die Angaben am Zeiger. Aufbau wie im Original: Transaktion (nur im
    // Strang), dann welcher Ein- oder Ausgang, der Betrag und die Adresse.
    Rectangle {
        id: tip

        readonly property bool imStrang: root.hovered !== null && !root.hovered.edge
        readonly property string adresse: root.addrFor(root.hovered)

        visible: root.hovered !== null
        width: tipInhalt.width + root.labelSize * 1.6
        height: tipInhalt.height + root.labelSize * 1.1
        radius: root.labelSize * 0.4
        color: Qt.rgba(0.05, 0.05, 0.08, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 10
        // Rechts unter dem Zeiger, sofern das passt -- sonst kippt der Kasten
        // auf die andere Seite, damit er nicht aus der Flaeche laeuft.
        x: Math.max(0, Math.min(root.width - width, root.zeigerX + root.labelSize))
        y: Math.max(0, Math.min(root.height - height, root.zeigerY + root.labelSize * 0.8))

        Column {
            id: tipInhalt

            anchors.centerIn: parent
            spacing: root.labelSize * 0.25

            Text {
                visible: tip.imStrang && root.txid !== ""
                width: Math.min(root.width * 0.6, implicitWidth)
                elide: Text.ElideMiddle
                text: Tr.t("flow.tx", root.lang) + "  " + root.txid
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
                font.family: "monospace"
            }

            Text {
                text: root.titleFor(root.hovered)
                color: root.textColor
                font.pixelSize: root.labelSize
            }

            Text {
                text: "\u20BF " + Tr.fixed((root.hovered ? root.hovered.value : 0) / 1e8,
                                           8, root.lang)
                color: root.textColor
                font.pixelSize: root.labelSize
            }

            Text {
                visible: tip.adresse !== ""
                width: Math.min(root.width * 0.6, implicitWidth)
                elide: Text.ElideMiddle
                text: tip.adresse
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
                font.family: "monospace"
            }
        }
    }
}
