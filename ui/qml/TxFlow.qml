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
    // Mehr Baender bringen nichts -- der Rest wird zusammengefasst. Das
    // Original erlaubt 250, hier ist deutlich weniger Platz.
    property int maxBands: 60
    property real minBand: Math.max(2, labelSize * 0.22)
    // Abstand zwischen zwei Baendern **am Rand**. Im Strang sind sie
    // lueckenlos -- daher wirkt er geschlossen, ohne dass ein Band schrumpft.
    // Wie schmal der Strang gegenueber den Raendern werden soll. **Nicht** als
    // Verjuengung der Baender -- die behalten ihre Dicke. Stattdessen wird der
    // Lueckenanteil am Rand daraus abgeleitet: was dort zwischen den Baendern
    // frei bleibt, faellt im Strang weg, und genau darum wird er schmaler.
    //
    // Bei einem einzigen Band gibt es keine Luecke und damit auch keine
    // Taille -- da ist auch nichts zusammenzufuehren.
    property real waistTarget: 0.72
    // Wie stark die Baender schwingen. 0,5 ergibt eine brave Sinusform, hoehere
    // Werte lassen sie flacher ansetzen und in der Mitte steiler laufen.
    property real swing: 0.78
    property real edgeGap: Math.max(2, labelSize * 0.3)
    // Pfeilspitze am rechten Ende, damit die Richtung erkennbar ist
    property real arrowLen: Math.max(8, Math.min(width * 0.035, labelSize * 1.6))
    // Oben und unten bleibt Platz -- der Fluss soll frei liegen, nicht am
    // Bildrand kleben.
    property real padY: Math.max(4, height * 0.09)
    // Gerades Anschlussstueck an beiden Enden, bevor die Kurve beginnt
    property real connector: Math.max(6, Math.min(width * 0.05, labelSize * 2))
    readonly property real innerH: Math.max(8, height - 2 * padY)
    // Der Farbwechsel sass frueher in der Strangflaeche. Die gibt es nicht
    // mehr, also tragen ihn die Baender: die Eingaenge laufen zur Mitte hin in
    // diesen Ton, die Ausgaenge setzen dort an. So bleibt der Verlauf
    // durchgehend, ohne harte Kante in der Mitte.
    readonly property color midColor: Qt.rgba((inColor.r + outColor.r) / 2,
                                              (inColor.g + outColor.g) / 2,
                                              (inColor.b + outColor.b) / 2, 1)

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
    // **Ein Band hat ueberall dieselbe Dicke.** Der Massstab ist fuer beide
    // Seiten derselbe: `waistStack`, die Hoehe des lueckenlosen Strangs. Am
    // Rand kommen nur die Luecken dazu, die den Rest bis `innerH` fuellen --
    // daher aussen breit und in der Mitte schmal, ohne dass irgendetwas
    // gestaucht wird.
    //
    // Weil beide Seiten denselben Gesamtbetrag haben (die Gebuehr zaehlt als
    // Ausgang), ergibt sich derselbe Strang -- Ein- und Ausgaenge treffen sich
    // dadurch in der Mitte genau. Eigene Massstaebe je Seite hatten hier einen
    // Versatz von rund 23 Bildpunkten erzeugt.
    function build(list, valueOf, scale) {
        var n = Math.min(list.length, root.maxBands);
        var out = [];
        var i;

        function add(v, more, idx) {
            out.push({ "i": idx, "v": v, "h": Math.max(root.minBand, v * scale),
                       "more": more || 0, "fee": false });
        }

        for (i = 0; i < n; i++)
            add(valueOf(list[i]) || 0, 0, i);
        if (list.length > n) {
            var rest = 0;
            for (i = n; i < list.length; i++)
                rest += valueOf(list[i]) || 0;
            add(rest, list.length - n, -1);
        }

        var sum = 0;
        for (i = 0; i < out.length; i++)
            sum += out[i].h;
        // Sicherheitsnetz: die Mindestdicke darf den Strang nicht sprengen
        if (sum > root.innerH) {
            var f = root.innerH / sum;
            for (i = 0; i < out.length; i++)
                out[i].h *= f;
            sum = root.innerH;
        }

        out.sum = sum;
        return out;
    }

    // Beide Seiten auf **denselben** Strang bringen und die Lagen rechnen.
    // Noetig, weil die Mindestdicke die Summen auseinandertreibt: bei 400
    // Eingaengen kommen 61 Baender zu je mindestens gut zwei Bildpunkten
    // zusammen und sprengen den Strang, waehrend die Gegenseite mit einem
    // Ausgang weit darunter bleibt. Ohne Angleich klaffte die Mitte um rund
    // 22 Bildpunkte auseinander.
    function fit(bands, target) {
        if (!bands.length)
            return bands;
        var i, sum = bands.sum || 0;
        if (sum > 0 && Math.abs(sum - target) > 0.01) {
            var f = target / sum;
            for (i = 0; i < bands.length; i++)
                bands[i].h *= f;
            sum = target;
        }
        var nGaps = Math.max(0, bands.length - 1);
        var gap = nGaps > 0 ? Math.max(0, (root.innerH - sum) / nGaps) : 0;
        var top = root.padY + (root.innerH - sum) / 2;
        var ey = nGaps > 0 ? root.padY : top;
        var my = top;
        for (i = 0; i < bands.length; i++) {
            bands[i].hEdge = bands[i].h;
            bands[i].hMid = bands[i].h;
            bands[i].edgeY = ey;
            bands[i].midY = my;
            ey += bands[i].h + gap;
            my += bands[i].h;
        }
        return bands;
    }

    function rebuild() {
        if (width <= 0 || height <= 0 || totalIn <= 0) {
            bandsIn = [];
            bandsOut = [];
            canvas.requestPaint();
            return;
        }
        // Der Strang ist `waistTarget` der nutzbaren Hoehe -- daraus der Massstab
        var scale = (innerH * waistTarget) / totalIn;
        var bi = build(vin || [], function (e) {
            return (e.prevout && e.prevout.value) || 0;
        }, scale);
        var bo = build(voutWithFee, function (e) {
            return e.value || 0;
        }, scale);
        // Beide Seiten tragen denselben Gesamtbetrag -- also denselben Strang
        var target = Math.min(innerH, Math.max(bi.sum || 0, bo.sum || 0));
        bandsIn = fit(bi, target);
        // Die Gebuehr steht vorn und bekommt ihre eigene Farbe
        if (fee > 0 && bo.length)
            bo[0].fee = true;
        bandsOut = fit(bo, target);
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
            // Gerade Anschluesse aussen, dazwischen die Kurve. Ein- und
            // Ausgaenge treffen sich in **einem** Punkt in der Mitte -- kein
            // Rechteck dazwischen, sonst entsteht dort eine harte Kante.
            var xL = root.connector;
            var xC = w * 0.5;
            var xR = w - root.connector - root.arrowLen;
            var i, b, lit, g;

            // --- Eingaenge -------------------------------------------------
            for (i = 0; i < root.bandsIn.length; i++) {
                b = root.bandsIn[i];
                lit = root.hovered && root.hovered.side === "in" && root.hovered.index === b.i;
                g = ctx.createLinearGradient(0, 0, xC, 0);
                g.addColorStop(0, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 1 : 0.9));
                g.addColorStop(0.55, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 1 : 0.8));
                g.addColorStop(1, Qt.rgba(root.midColor.r, root.midColor.g, root.midColor.b, lit ? 1 : 0.8));
                ctx.fillStyle = g;

                ctx.beginPath();
                ctx.moveTo(0, b.edgeY);
                ctx.lineTo(xL, b.edgeY);
                canvas.curve(ctx, xL, b.edgeY, xC, b.midY);
                ctx.lineTo(xC, b.midY + b.hMid);
                canvas.curve(ctx, xC, b.midY + b.hMid, xL, b.edgeY + b.hEdge);
                ctx.lineTo(0, b.edgeY + b.hEdge);
                ctx.closePath();
                ctx.fill();
            }

            // --- Ausgaenge -------------------------------------------------
            for (i = 0; i < root.bandsOut.length; i++) {
                b = root.bandsOut[i];
                lit = root.hovered && root.hovered.side === "out" && root.hovered.index === b.i;
                var col = b.fee ? root.feeColor : root.outColor;
                g = ctx.createLinearGradient(xC, 0, w, 0);
                if (b.fee) {
                    g.addColorStop(0, Qt.rgba(root.midColor.r, root.midColor.g, root.midColor.b, 0.7));
                    g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, lit ? 1 : 0.85));
                } else {
                    g.addColorStop(0, Qt.rgba(root.midColor.r, root.midColor.g, root.midColor.b, lit ? 1 : 0.8));
                    g.addColorStop(0.45, Qt.rgba(col.r, col.g, col.b, lit ? 1 : 0.82));
                    g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, lit ? 1 : 0.95));
                }
                ctx.fillStyle = g;

                ctx.beginPath();
                ctx.moveTo(xC, b.midY);
                canvas.curve(ctx, xC, b.midY, xR, b.edgeY);
                // Die Spitze laeuft **innerhalb** der Bandbreite zusammen --
                // ein Ueberstand an den Ecken sieht nach Fehler aus.
                ctx.lineTo(w, b.edgeY + b.hEdge / 2);
                ctx.lineTo(xR, b.edgeY + b.hEdge);
                canvas.curve(ctx, xR, b.edgeY + b.hEdge, xC, b.midY + b.hMid);
                ctx.closePath();
                ctx.fill();
            }

            // Die Gebuehr beschriften, wenn sie da ist
            if (root.fee > 0 && root.bandsOut.length) {
                var fb = root.bandsOut[0];
                ctx.font = root.labelSize + "px sans-serif";
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                var ty = fb.edgeY - root.labelSize * 0.45;
                if (ty < root.labelSize)
                    ty = fb.edgeY + fb.hEdge + root.labelSize;
                ctx.fillText("Gebühr " + root.fee + " sat", w - root.labelSize * 0.4, ty);
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
