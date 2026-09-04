// Verlauf eines Miners: Hashrate und Temperatur uebereinander, wie in der
// Weboberflaeche von AxeOS. Zwei Achsen, weil die Groessen nichts miteinander
// zu tun haben.
//
// Die Daten schreibt der Daemon mit -- nicht das Geraet. AxeOS zeichnet nur
// auf, wenn `statsFrequency` gesetzt ist, und die cgminer-Schnittstelle kennt
// gar keinen Verlauf.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

Item {
    id: root

    property string lang: "de"

    property var hist: ({})
    property color lineColor: "#f7931a"
    property color tempColor: "#e8e4f0"
    property color gridColor: Qt.rgba(1, 1, 1, 0.07)
    property color dimColor: "#9a94a6"
    property real labelSize: 9
    // Ab hier in TH/s statt GH/s. Bewusst etwas ueber 1000, damit die Einheit
    // nicht bei jedem Ausschlag um die Marke herum hin und her springt.
    property real teraFrom: 1025

    // Der Verlauf liegt in GH/s vor.
    function fmtRate(gh, withUnit) {
        if (gh >= root.teraFrom)
            return Tr.fixed(gh / 1000, 2, root.lang) + (withUnit ? " TH/s" : "");
        return Tr.fixed(gh, 0, root.lang) + (withUnit ? " GH/s" : "");
    }

    readonly property var hr: (hist && hist.hr) || []
    readonly property var hrNow: (hist && hist.hrNow) || []
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

            // Beide Hashraten teilen sich eine Achse, sonst waere der
            // Vergleich sinnlos.
            function rangeOf(lists) {
                var lo = null, hi = null;
                for (var a = 0; a < lists.length; a++) {
                    var v = lists[a];
                    for (var b = 0; b < v.length; b++) {
                        if (v[b] === null || v[b] === undefined)
                            continue;
                        lo = (lo === null) ? v[b] : Math.min(lo, v[b]);
                        hi = (hi === null) ? v[b] : Math.max(hi, v[b]);
                    }
                }
                if (lo === null)
                    return null;
                var span = Math.max(hi - lo, Math.abs(hi) * 0.02, 0.1);
                return [lo - span * 0.15, hi + span * 0.15];
            }

            function drawIn(vals, range, color, width2, alpha) {
                if (!range)
                    return;
                var lo = range[0], hi = range[1];
                ctx.beginPath();
                var started = false;
                for (var i = 0; i < vals.length; i++) {
                    if (vals[i] === null || vals[i] === undefined)
                        continue;
                    var x = padL + w * i / Math.max(1, vals.length - 1);
                    var y = padT + h - h * (vals[i] - lo) / (hi - lo);
                    started ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
                    started = true;
                }
                ctx.strokeStyle = color;
                ctx.globalAlpha = alpha === undefined ? 1 : alpha;
                ctx.lineWidth = width2;
                ctx.stroke();
                ctx.globalAlpha = 1;
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
            // Momentanwert duenn und blass, der Zehnminutenwert kraeftig
            // darueber -- so wie es die Weboberflaeche des Geraets zeigt, und
            // es macht auf einen Blick klar, welche Linie die Hashrate ist.
            var hRange = rangeOf([s, root.hrNow]);
            drawIn(root.hrNow, hRange, root.lineColor, 1.0, 0.45);
            drawIn(s, hRange, root.lineColor, 2.0, 1.0);

            // Beschriftung **in der Farbe der jeweiligen Kurve** -- sonst ist
            // nicht zu erkennen, welche Achse zu welcher Linie gehoert.
            ctx.font = root.labelSize + "px " + Fonts.sansCss();
            if (hRange) {
                ctx.fillStyle = root.lineColor;
                ctx.textAlign = "left";
                ctx.fillText(root.fmtRate(hRange[1], true), padL, padT + root.labelSize);
                ctx.fillText(root.fmtRate(hRange[0], false), padL, padT + h);
            }
            if (tRange) {
                ctx.fillStyle = root.tempColor;
                ctx.textAlign = "right";
                ctx.fillText(tRange[1].toFixed(0) + " °C", padL + w, padT + root.labelSize);
                ctx.fillText(tRange[0].toFixed(0), padL + w, padT + h);
            }
            ctx.fillStyle = root.dimColor;
            ctx.textAlign = "center";
            ctx.fillText(Tr.t("duration.min", root.lang, Math.round(s.length * 5 / 60)),
                         padL + w / 2, height - 2);
        }
    }
}
