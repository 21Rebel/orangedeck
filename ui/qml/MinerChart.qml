// Verlauf eines Miners: Hashrate und Temperatur uebereinander, wie in der
// Weboberflaeche von AxeOS. Zwei Achsen, weil die Groessen nichts miteinander
// zu tun haben.
//
// Die Daten schreibt der Daemon oder `DirectMiner` mit. Zeichnet das Geraet
// selbst auf (AxeOS mit `statsFrequency`), kommt der Verlauf von dort, und
// die Punkte liegen dann eine Minute auseinander statt fuenf Sekunden.
//
// **Die Zeitachse folgt den Zeitstempeln, nicht der Zahl der Punkte.** Bis
// zum 10.09.2026 lag jeder Punkt gleich weit vom naechsten, und die
// Beschriftung rechnete "Punkte mal fuenf Sekunden". Mit dem Verlauf aus dem
// Geraet stimmt beides nicht mehr: zwoelf Stunden in Minutenschritten und
// die letzten Minuten in Fuenfsekundenschritten, gleichmaessig verteilt,
// haetten die letzten Minuten auf die halbe Breite gezogen.
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
    readonly property var zeit: (hist && hist.t) || []

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

            // Waagerecht nach der Zeit, wenn es fuer jeden Punkt eine gibt;
            // sonst (Verlauf ohne Zeitstempel) wie bisher nach der Reihenfolge.
            var zt = root.zeit;
            var nachZeit = zt.length === s.length && zt[zt.length - 1] > zt[0];
            function xAt(i, n) {
                if (nachZeit)
                    return padL + w * (zt[i] - zt[0]) / (zt[zt.length - 1] - zt[0]);
                return padL + w * i / Math.max(1, n - 1);
            }

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
                    var x = xAt(i, vals.length);
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
                    var x = xAt(pts[k][0], vals.length);
                    var y = padT + h - h * (pts[k][1] - lo) / (hi - lo);
                    k === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.strokeStyle = color;
                ctx.lineWidth = width2;
                ctx.stroke();
                return [lo, hi];
            }

            var tRange = draw(root.temp, root.tempColor, 1.2);

            // **Nur der Momentanwert.** Bis zum 09.09.2026 lag der
            // Zehnminutenwert (`hr`, aus `hashRate_10m`) kraeftig darueber --
            // so zeigt es die Weboberflaeche des Geraets auch. Im Betrieb ist
            // er aber fast immer eine Waagerechte: er ist geglaettet, und ein
            // Miner, der laeuft, laeuft gleichmaessig. Eine Linie, die sich
            // nicht bewegt, sagt nichts und nimmt der zweiten die Achse weg --
            // dazu stand derselbe Wert ohnehin als Zahl daneben.
            //
            // **Aber nicht ersatzlos:** `hrNow` kommt aus `hashRate` und wird
            // nur im AxeOS-Pfad gesetzt. Ein Miner an der cgminer-Schnittstelle
            // meldet ihn nicht (`daemon/orangedeck`, "cgminer meldet MH/s"),
            // dort ist `hrNow` durchgehend null. Waere hier nur noch `hrNow`
            // gezeichnet, bliebe deren Graph leer. Also: den Momentanwert,
            // wenn es ihn gibt, sonst den geglaetteten.
            var hatNow = false;
            for (var q = 0; q < root.hrNow.length; q++) {
                if (root.hrNow[q] !== null && root.hrNow[q] !== undefined) {
                    hatNow = true;
                    break;
                }
            }
            //
            // **Und nur ueber kurze Zeit.** Seit der Verlauf aus dem Geraet
            // kommt (10.09.2026), reicht er zwoelf Stunden zurueck, und dort
            // ist es umgekehrt: 720 Momentanwerte sind ein Band aus Rauschen,
            // das den Gang des Tages verdeckt, waehrend der Zehnminutenwert
            // genau diesen Gang zeigt. Die Grenze ist eine Stunde -- darunter
            // ist der geglaettete Wert eine Waagerechte, darueber der
            // Momentanwert ein Band.
            var sekSpanne = nachZeit ? zt[zt.length - 1] - zt[0] : s.length * 5;
            var kurve = hatNow && sekSpanne < 3600 ? root.hrNow : s;
            var hRange = rangeOf([kurve]);
            drawIn(kurve, hRange, root.lineColor, 2.0, 1.0);

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
            var sek = sekSpanne;
            var spanne = sek >= 3600
                ? Tr.t("duration.hourMin", root.lang, Math.floor(sek / 3600),
                       Math.round(sek % 3600 / 60))
                : Tr.t("duration.min", root.lang, Math.round(sek / 60));
            ctx.fillText(spanne, padL + w / 2, height - 2);
        }
    }
}
