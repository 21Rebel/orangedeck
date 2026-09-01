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

pragma ComponentBehavior: Bound

Item {
    id: root

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
    // Pfeilspitze am rechten Ende, damit die Richtung erkennbar ist.
    // **Fuer alle Baender gleich lang und bewusst kurz** -- eine lange Spitze
    // laesst das Band vorn duenner wirken, als es ist, und verschieden lange
    // Spitzen machen die rechte Kante unruhig.
    property real arrowLen: Math.max(4, Math.min(width * 0.014, labelSize * 0.8))
    // Abstand des Pfeils vom rechten Rand -- ohne ihn klebt er an der Kante.
    property real edgeMargin: Math.max(4, Math.min(width * 0.012, labelSize))

    function tipFor(thickness) {
        return Math.min(root.arrowLen, Math.max(2, thickness));
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
        var trunkTop = root.padY + (root.innerH - root.trunkH) / 2;
        var acc = 0;
        for (i = 0; i < out.length; i++) {
            var centre = trunkTop + acc + out[i].weight / 2;
            out[i].midY = centre - out[i].thick / 2;
            out[i].hMid = out[i].thick;
            acc += out[i].weight;
        }

        // Ist ein Band dicker als sein Gewicht (Mindestdicke), steht es oben
        // und unten ueber. Wie weit, haengt davon ab, wie viele Baender
        // betroffen sind -- und das ist auf beiden Seiten verschieden. Ohne
        // Ausgleich sitzt die eine Seite darum ein paar Bildpunkte hoeher als
        // die andere, und in der Mitte klafft ein Versatz.
        //
        // Deshalb zum Schluss die **gezeichnete** Flaeche mittig ausrichten,
        // nicht die gerechnete.
        var spanTop = out[0].midY;
        var spanBot = out[0].midY + out[0].hMid;
        for (i = 1; i < out.length; i++) {
            spanTop = Math.min(spanTop, out[i].midY);
            spanBot = Math.max(spanBot, out[i].midY + out[i].hMid);
        }
        var shift = (root.padY + root.innerH / 2) - (spanTop + spanBot) / 2;
        for (i = 0; i < out.length; i++)
            out[i].midY += shift;

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

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.bandsIn.length)
                return;

            var w = width;
            var xL = root.connector;
            var xC = w * 0.5;
            var xEnd = w - root.edgeMargin;
            var xR = xEnd - root.arrowLen - root.connector;
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
                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                ctx.moveTo(0, cEdge);
                ctx.lineTo(xL, cEdge);
                canvas.curve(ctx, xL, cEdge, xC + seam, cMid);
                ctx.stroke();
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
                var tip = root.tipFor(b.hEdge);
                var xT = xEnd - tip;

                ctx.strokeStyle = g;
                ctx.lineWidth = b.hEdge;
                ctx.beginPath();
                ctx.moveTo(xC - seam, cMid);
                canvas.curve(ctx, xC - seam, cMid, xR, cEdge);
                ctx.lineTo(xT, cEdge);
                ctx.stroke();

                // Die Spitze als eigenes Dreieck -- ein Strich kann nicht
                // spitz zulaufen.
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.moveTo(xT - 0.5, cEdge - b.hEdge / 2);
                ctx.lineTo(xEnd, cEdge);
                ctx.lineTo(xT - 0.5, cEdge + b.hEdge / 2);
                ctx.closePath();
                ctx.fill();
            }

            if (root.fee > 0 && root.bandsOut.length) {
                var fb = root.bandsOut[0];
                ctx.font = root.labelSize + "px sans-serif";
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                var ty = fb.edgeY - root.labelSize * 0.45;
                if (ty < root.labelSize)
                    ty = fb.edgeY + fb.hEdge + root.labelSize;
                ctx.fillText("Gebühr " + root.fee + " sat", w - root.edgeMargin, ty);
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
                         "value": b.v, "more": b.more };
        }
        return null;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onPositionChanged: mouse => {
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

    Rectangle {
        visible: root.hovered !== null
        width: tipText.width + root.labelSize * 1.4
        height: tipText.height + root.labelSize * 0.8
        radius: root.labelSize * 0.4
        color: Qt.rgba(0.05, 0.05, 0.08, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        x: Math.max(0, Math.min(root.width - width, root.width / 2 - width / 2))
        y: root.height - height - root.labelSize * 0.4

        Text {
            id: tipText

            anchors.centerIn: parent
            color: root.textColor
            font.pixelSize: root.labelSize
            text: {
                var hv = root.hovered;
                if (!hv)
                    return "";
                var v = "₿ " + (hv.value / 1e8).toFixed(8).replace(".", ",");
                if (hv.side === "fee")
                    return "Gebühr " + v + " · " + root.fee + " sat";
                if (hv.more)
                    return "weitere " + hv.more + " · " + v;
                var n = hv.index + (hv.side === "out" && root.fee > 0 ? 0 : 1);
                return (hv.side === "in" ? "Eingang " : "Ausgang ") + n + " · " + v;
            }
        }
    }
}
