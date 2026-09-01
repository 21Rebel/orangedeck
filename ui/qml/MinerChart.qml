// Verlauf eines Miners: Hashrate und Temperatur uebereinander, wie in der
// Weboberflaeche von AxeOS. Zwei Achsen, weil die Groessen nichts miteinander
// zu tun haben.
//
// Die Daten schreibt der Daemon mit -- nicht das Geraet. AxeOS zeichnet nur
// auf, wenn `statsFrequency` gesetzt ist, und die cgminer-Schnittstelle kennt
// gar keinen Verlauf.
import QtQuick

Item {
    id: root

    property var hist: ({})
    property color lineColor: "#f7931a"
    property color tempColor: "#e8e4f0"
    property color gridColor: Qt.rgba(1, 1, 1, 0.07)
    property color dimColor: "#9a94a6"
    property real labelSize: 9

    readonly property var hr: (hist && hist.hr) || []
    readonly property var temp: (hist && hist.temp) || []

    onHrChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = root.hr;
            if (s.length < 2)
                return;

            var padL = 4, padR = 4, padT = 6, padB = 14;
            var w = width - padL - padR, h = height - padT - padB;
            if (w <= 0 || h <= 0)
                return;

            // Waagerechte Hilfslinien
            ctx.strokeStyle = root.gridColor;
            ctx.lineWidth = 1;
            for (var g = 0; g <= 3; g++) {
                var gy = Math.round(padT + h * g / 3) + 0.5;
                ctx.beginPath();
                ctx.moveTo(padL, gy);
                ctx.lineTo(padL + w, gy);
                ctx.stroke();
            }

            function draw(vals, color, width2) {
                var pts = [];
                for (var i = 0; i < vals.length; i++) {
                    if (vals[i] !== null && vals[i] !== undefined)
                        pts.push([i, vals[i]]);
                }
                if (pts.length < 2)
                    return null;
                var lo = pts[0][1], hi = pts[0][1];
                for (var j = 1; j < pts.length; j++) {
                    lo = Math.min(lo, pts[j][1]);
                    hi = Math.max(hi, pts[j][1]);
                }
                // Etwas Luft, damit die Kurve nicht am Rand klebt
                var span = Math.max(hi - lo, Math.abs(hi) * 0.02, 0.1);
                lo -= span * 0.15;
                hi += span * 0.15;
                ctx.beginPath();
                for (var k = 0; k < pts.length; k++) {
                    var x = padL + w * pts[k][0] / (vals.length - 1);
                    var y = padT + h - h * (pts[k][1] - lo) / (hi - lo);
                    k === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.strokeStyle = color;
                ctx.lineWidth = width2;
                ctx.stroke();
                return [lo, hi];
            }

            var tRange = draw(root.temp, root.tempColor, 1.2);
            var hRange = draw(s, root.lineColor, 1.8);

            // Beschriftung: links Hashrate, rechts Temperatur
            ctx.font = root.labelSize + "px sans-serif";
            ctx.fillStyle = root.dimColor;
            if (hRange) {
                ctx.textAlign = "left";
                ctx.fillText(hRange[1].toFixed(0) + " GH/s", padL, padT + root.labelSize);
                ctx.fillText(hRange[0].toFixed(0), padL, padT + h);
            }
            if (tRange) {
                ctx.textAlign = "right";
                ctx.fillText(tRange[1].toFixed(0) + " °C", padL + w, padT + root.labelSize);
                ctx.fillText(tRange[0].toFixed(0), padL + w, padT + h);
            }
            ctx.textAlign = "center";
            ctx.fillText(Math.round(s.length * 5 / 60) + " Min", padL + w / 2, height - 2);
        }
    }
}
