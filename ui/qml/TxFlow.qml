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
    property real edgeGap: Math.max(2, labelSize * 0.3)
    // Pfeilspitze am rechten Ende, damit die Richtung erkennbar ist
    property real arrowLen: Math.max(8, Math.min(width * 0.035, labelSize * 1.6))

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
    function build(list, valueOf, scale) {
        var n = Math.min(list.length, root.maxBands);
        var nBands = n + (list.length > n ? 1 : 0);
        var nGaps = Math.max(0, nBands - 1);
        // Der Lueckenanteil ergibt sich aus der gewuenschten Taille
        var gap = nGaps > 0
            ? Math.max(root.edgeGap * 0.5,
                       root.height * (1 - root.waistTarget) / nGaps)
            : 0;
        // Nie so viel, dass fuer die Baender zu wenig bleibt
        gap = Math.min(gap, root.height * 0.55 / Math.max(1, nGaps));
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

        // Am Rand teilen sich die Baender die Hoehe **abzueglich der Luecken**
        var sum = 0;
        for (i = 0; i < out.length; i++)
            sum += out[i].h;
        var gapsTotal = gap * Math.max(0, out.length - 1);
        var avail = Math.max(4, root.height - gapsTotal);
        var f = sum > 0 ? avail / sum : 1;

        // Im Strang behaelt jedes Band **dieselbe** Dicke -- es faellt nur die
        // Luecke weg. Der Stapel wird dadurch von selbst um genau die Summe der
        // Luecken schmaler und sitzt mittig. Genau das ergibt die Form: aussen
        // breit, in der Mitte schmal. Wuerde man hier hochskalieren, damit die
        // Mitte auch die volle Hoehe fuellt, bliebe alles rechteckig.
        var stack = 0;
        for (i = 0; i < out.length; i++) {
            out[i].hEdge = out[i].h * f;
            out[i].hMid = out[i].hEdge;
            stack += out[i].hEdge;
        }
        var top = (root.height - stack) / 2;

        var ey = 0, my = top;
        for (i = 0; i < out.length; i++) {
            out[i].edgeY = ey;
            out[i].midY = my;
            ey += out[i].hEdge + gap;
            my += out[i].hMid;
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
        var scale = height / totalIn;
        bandsIn = build(vin || [], function (e) {
            return (e.prevout && e.prevout.value) || 0;
        }, scale);
        var bo = build(voutWithFee, function (e) {
            return e.value || 0;
        }, scale);
        // Die Gebuehr steht vorn und bekommt ihre eigene Farbe
        if (fee > 0 && bo.length)
            bo[0].fee = true;
        bandsOut = bo;
        canvas.requestPaint();
    }

    Canvas {
        id: canvas

        anchors.fill: parent

        function band(ctx, x0, y0a, y0b, x1, y1a, y1b) {
            var c1 = x0 + (x1 - x0) * 0.5;
            var c2 = x1 - (x1 - x0) * 0.5;
            ctx.beginPath();
            ctx.moveTo(x0, y0a);
            ctx.bezierCurveTo(c1, y0a, c2, y1a, x1, y1a);
            ctx.lineTo(x1, y1b);
            ctx.bezierCurveTo(c2, y1b, c1, y0b, x0, y0b);
            ctx.closePath();
            ctx.fill();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.bandsIn.length)
                return;

            var w = width, h = height;
            var midL = w * 0.42, midR = w * 0.58;
            var i, b, lit;

            for (i = 0; i < root.bandsIn.length; i++) {
                b = root.bandsIn[i];
                lit = root.hovered && root.hovered.side === "in" && root.hovered.index === b.i;
                var g = ctx.createLinearGradient(0, 0, midL, 0);
                g.addColorStop(0, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 1 : 0.8));
                g.addColorStop(1, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 0.95 : 0.62));
                ctx.fillStyle = g;
                canvas.band(ctx, 0, b.edgeY, b.edgeY + b.hEdge, midL, b.midY, b.midY + b.hMid);
            }

            // Der Strang ist genau so hoch wie der lueckenlose Stapel
            var sTop = root.bandsIn.length ? root.bandsIn[0].midY : 0;
            var sBot = root.bandsIn.length
                ? root.bandsIn[root.bandsIn.length - 1].midY + root.bandsIn[root.bandsIn.length - 1].hMid
                : h;
            var trunk = ctx.createLinearGradient(midL, 0, midR, 0);
            trunk.addColorStop(0, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, 0.62));
            trunk.addColorStop(1, Qt.rgba(root.outColor.r, root.outColor.g, root.outColor.b, 0.62));
            ctx.fillStyle = trunk;
            ctx.fillRect(midL, sTop, midR - midL, sBot - sTop);

            for (i = 0; i < root.bandsOut.length; i++) {
                b = root.bandsOut[i];
                lit = root.hovered && root.hovered.side === "out" && root.hovered.index === b.i;
                var col = b.fee ? root.feeColor : root.outColor;
                var g2 = ctx.createLinearGradient(midR, 0, w, 0);
                g2.addColorStop(0, Qt.rgba(col.r, col.g, col.b, b.fee ? 0.5 : (lit ? 0.95 : 0.62)));
                g2.addColorStop(1, Qt.rgba(col.r, col.g, col.b, lit ? 1 : (b.fee ? 0.85 : 0.82)));
                ctx.fillStyle = g2;
                // Bis kurz vor den Rand, dann die Spitze
                var ax = w - root.arrowLen;
                canvas.band(ctx, midR, b.midY, b.midY + b.hMid, ax, b.edgeY, b.edgeY + b.hEdge);
                var over = Math.min(b.hEdge * 0.35, root.arrowLen * 0.35);
                ctx.beginPath();
                ctx.moveTo(ax, b.edgeY - over);
                ctx.lineTo(w, b.edgeY + b.hEdge / 2);
                ctx.lineTo(ax, b.edgeY + b.hEdge + over);
                ctx.closePath();
                ctx.fill();
            }

            // Die Gebuehr beschriften, wenn Platz ist
            if (root.fee > 0 && root.bandsOut.length) {
                var fb = root.bandsOut[0];
                ctx.font = root.labelSize + "px sans-serif";
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                var ty = fb.edgeY + fb.hEdge / 2 + root.labelSize * 0.35;
                if (fb.hEdge < root.labelSize * 1.4)
                    ty = fb.edgeY - root.labelSize * 0.35;
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
