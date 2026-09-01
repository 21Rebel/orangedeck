// Der Fluss einer Transaktion: Eingaenge links, Ausgaenge rechts, die Breite
// jedes Bandes im Verhaeltnis zum Betrag. In der Mitte laufen alle zu einem
// Strang zusammen -- so ist es auch richtig: welcher Eingang welchen Ausgang
// bezahlt, laesst sich in Bitcoin **nicht** sagen. Ein Sankey-Diagramm mit
// Einzelverbindungen waere daher eine Erfindung.
//
// Die Gebuehr ist der Unterschied zwischen beiden Seiten und wird unten rechts
// als eigenes, schmales Band gezeigt.
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
    // Mehr Baender als das bringen nichts -- der Rest wird zusammengefasst
    property int maxBands: 40

    // Unten bleibt ein Streifen frei, in den die Gebuehr abzweigt. Ohne ihn
    // waere sie unsichtbar: eine uebliche Gebuehr ist ein Bruchteil eines
    // Promille des Betrags -- 385 sat von 646.354 sind 0,06 %, auf 220 px also
    // 0,13 Bildpunkte.
    readonly property real feeLane: Math.max(labelSize * 2.2, height * 0.18)
    readonly property real mainH: Math.max(10, height - feeLane)
    // Mindestdicke fuer **jedes** Band, damit nie etwas ganz verschwindet.
    // Unterhalb dieser Schwelle wird ueberhoeht gezeichnet; der Tooltip nennt
    // dann den genauen Betrag und sagt es dazu.
    readonly property real minBand: Math.max(2, labelSize * 0.25)
    // Die Gebuehr zweigt durchgehend mit dieser Dicke ab -- Ansatz wie Ende.
    readonly property real feeThickness: Math.max(fee * (mainH / Math.max(1, totalIn)), minBand)
    // Was nach dem Abzweig fuer die Ausgaenge bleibt
    readonly property real outH: Math.max(4, mainH - feeThickness)

    // Welches Band liegt unter dem Zeiger: {side: "in"|"out"|"fee", index}
    property var hovered: null

    signal activated(string side, int index)

    readonly property real totalIn: {
        var s = 0;
        for (var i = 0; i < (vin || []).length; i++)
            s += (vin[i].prevout && vin[i].prevout.value) || 0;
        return s;
    }
    readonly property real totalOut: {
        var s = 0;
        for (var i = 0; i < (vout || []).length; i++)
            s += vout[i].value || 0;
        return s;
    }

    onVinChanged: rebuild()
    onVoutChanged: rebuild()
    onWidthChanged: rebuild()
    onHeightChanged: rebuild()

    property var bandsIn: []
    property var bandsOut: []

    // Baender ausrechnen: Betrag -> Hoehe, gestapelt. Die Mitte ist
    // luekenlos, die Raender bekommen Abstaende -- daher der Trichter.
    function build(list, valueOf, total, scale, fitInto) {
        var out = [];
        var n = Math.min(list.length, root.maxBands);
        var gap = list.length > 1
            ? Math.min(root.height * 0.02, root.height * 0.25 / Math.max(1, n)) : 0;
        var edgeY = 0, midY = 0;
        for (var i = 0; i < n; i++) {
            var v = valueOf(list[i]) || 0;
            var h = Math.max(root.minBand, v * scale);
            out.push({ "i": i, "v": v, "edgeY": edgeY, "midY": midY, "h": h,
                       "hEdge": Math.max(1, h - gap) });
            edgeY += h;
            midY += h;
        }
        if (list.length > n) {
            var rest = 0;
            for (var k = n; k < list.length; k++)
                rest += valueOf(list[k]) || 0;
            var rh = Math.max(root.minBand, rest * scale);
            out.push({ "i": -1, "v": rest, "edgeY": edgeY, "midY": midY, "h": rh,
                       "hEdge": Math.max(1, rh - gap), "more": list.length - n });
            edgeY += rh;
        }

        // Die Mindesthoehe von einem Bildpunkt summiert sich: bei sehr vielen
        // Eingaengen laeuft der Stapel sonst unten aus dem Bild. Nachgemessen
        // waren es bei 120 Eingaengen auf 220 px gut zwei Pixel. Deshalb zum
        // Schluss einmal auf die verfuegbare Hoehe normieren.
        // Die Mindestdicke summiert sich -- zum Schluss auf den verfuegbaren
        // Platz normieren, sonst laeuft der Stapel unten heraus.
        if (edgeY > fitInto && edgeY > 0) {
            var f = fitInto / edgeY;
            var y = 0;
            for (var m = 0; m < out.length; m++) {
                out[m].h *= f;
                out[m].hEdge = Math.max(0.5, out[m].hEdge * f);
                out[m].edgeY = y;
                out[m].midY = y;
                y += out[m].h;
            }
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
        // Eingaenge fuellen die ganze Hoehe des Hauptfelds. Die Ausgaenge
        // teilen sich, was nach dem Gebuehrenabzweig bleibt -- so passt beides
        // zusammen und der Abzweig ist immer zu sehen.
        bandsIn = build(vin || [], function (e) {
            return (e.prevout && e.prevout.value) || 0;
        }, totalIn, mainH / totalIn, mainH);
        bandsOut = build(vout || [], function (e) {
            return e.value || 0;
        }, totalOut, outH / Math.max(1, totalOut), outH);
        canvas.requestPaint();
    }

    Component.onCompleted: rebuild()

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

            var w = width, h = root.mainH;
            var midL = w * 0.42, midR = w * 0.58;

            // Eingaenge: vom linken Rand in die Mitte
            for (var i = 0; i < root.bandsIn.length; i++) {
                var b = root.bandsIn[i];
                var lit = root.hovered && root.hovered.side === "in" && root.hovered.index === b.i;
                var g = ctx.createLinearGradient(0, 0, midL, 0);
                g.addColorStop(0, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 1 : 0.75));
                g.addColorStop(1, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, lit ? 0.95 : 0.6));
                ctx.fillStyle = g;
                canvas.band(ctx, 0, b.edgeY, b.edgeY + b.hEdge, midL, b.midY, b.midY + b.h);
            }

            // Der Strang in der Mitte
            ctx.fillStyle = Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, 0.6);
            var trunk = ctx.createLinearGradient(midL, 0, midR, 0);
            trunk.addColorStop(0, Qt.rgba(root.inColor.r, root.inColor.g, root.inColor.b, 0.6));
            trunk.addColorStop(1, Qt.rgba(root.outColor.r, root.outColor.g, root.outColor.b, 0.6));
            ctx.fillStyle = trunk;
            ctx.fillRect(midL, 0, midR - midL, h);

            // Ausgaenge: aus der Mitte an den rechten Rand
            for (var j = 0; j < root.bandsOut.length; j++) {
                var o = root.bandsOut[j];
                var lit2 = root.hovered && root.hovered.side === "out" && root.hovered.index === o.i;
                var g2 = ctx.createLinearGradient(midR, 0, w, 0);
                g2.addColorStop(0, Qt.rgba(root.outColor.r, root.outColor.g, root.outColor.b, lit2 ? 0.95 : 0.6));
                g2.addColorStop(1, Qt.rgba(root.outColor.r, root.outColor.g, root.outColor.b, lit2 ? 1 : 0.8));
                ctx.fillStyle = g2;
                canvas.band(ctx, midR, o.midY, o.midY + o.h, w, o.edgeY, o.edgeY + o.hEdge);
            }

            // --- Die Gebuehr zweigt ab -------------------------------------
            // Sie ist der Unterschied zwischen beiden Seiten. Am Strang setzt
            // sie massstabsgetreu an (meist ein Haarstrich), laeuft nach unten
            // aus dem Hauptfeld heraus und endet im Streifen darunter mit
            // sichtbarer Dicke.
            if (root.fee > 0) {
                var lit3 = root.hovered && root.hovered.side === "fee";
                var endT = root.feeThickness;     // durchgehend gleich dick
                var top = h - endT;               // setzt unter den Ausgaengen an
                var endY = height - root.feeLane * 0.45;   // Ziel im Streifen
                var c1 = midR + (w - midR) * 0.45;
                var c2 = w - (w - midR) * 0.35;

                ctx.beginPath();
                ctx.moveTo(midR, top);
                ctx.bezierCurveTo(c1, top, c2, endY - endT / 2, w, endY - endT / 2);
                ctx.lineTo(w, endY + endT / 2);
                ctx.bezierCurveTo(c2, endY + endT / 2, c1, h, midR, h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(root.feeColor.r, root.feeColor.g, root.feeColor.b,
                                        lit3 ? 0.95 : 0.7);
                ctx.fill();

                // Beschriftung an der Abzweigung
                ctx.font = root.labelSize + "px sans-serif";
                ctx.fillStyle = root.dimColor;
                ctx.textAlign = "right";
                ctx.fillText("Gebühr " + root.fee + " sat",
                             w - root.labelSize * 0.4, endY - endT / 2 - root.labelSize * 0.4);
            }
        }
    }

    // Welches Band liegt unter dem Zeiger?
    function bandAt(px, py) {
        // Alles unterhalb des Hauptfelds gehoert zur Gebuehrenabzweigung
        if (py > mainH && fee > 0)
            return { "side": "fee", "index": -1, "value": fee, "more": 0 };
        var side = px < width * 0.5 ? "in" : "out";
        var list = side === "in" ? bandsIn : bandsOut;
        // Am Rand gelten die Randpositionen, in der Mitte die gestapelten
        var edge = side === "in" ? px < width * 0.2 : px > width * 0.8;
        for (var i = 0; i < list.length; i++) {
            var b = list[i];
            var y0 = edge ? b.edgeY : b.midY;
            var y1 = y0 + (edge ? b.hEdge : b.h);
            if (py >= y0 && py <= y1)
                return { "side": side, "index": b.i, "value": b.v, "more": b.more || 0 };
        }
        if (side === "out" && fee > 0) {
            var feeH = root.fee * (mainH / Math.max(1, root.totalIn));
            if (py >= mainH - Math.max(feeH, 3))
                return { "side": "fee", "index": -1, "value": root.fee, "more": 0 };
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
            if (root.hovered && root.hovered.index >= 0)
                root.activated(root.hovered.side, root.hovered.index);
        }
    }

    // Kurzauskunft zum Band unter dem Zeiger
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
                if (hv.side === "fee") {
                    var exact = root.fee * (root.mainH / Math.max(1, root.totalIn));
                    return "Gebühr " + v + " · " + root.fee + " sat"
                         + (exact < root.minBand ? " (überhöht gezeichnet)" : "");
                }
                if (hv.more)
                    return (hv.side === "in" ? "weitere " : "weitere ") + hv.more + " · " + v;
                return (hv.side === "in" ? "Eingang " : "Ausgang ") + (hv.index + 1) + " · " + v;
            }
        }
    }
}
