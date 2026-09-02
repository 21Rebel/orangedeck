// Die Kachelgrafik eines Blocks -- dieselbe Optik wie im Feed, nur fuer einen
// beliebigen Block aus dem Explorer.
//
// Packung und Farben kommen aus denselben Bausteinen wie dort (`mondrian.js`,
// `colors.js`), damit beide Ansichten wirklich gleich aussehen und nicht nur
// aehnlich.
//
// Zwei Betriebsarten:
//
//   `live: false`  -- ein bestaetigter Block. Er aendert sich nicht mehr, die
//                     Packung wird einmal gerechnet.
//   `live: true`   -- ein **geplanter** Block. Er aendert sich staendig, und
//                     dann darf nicht neu gepackt werden: nachgemessen wechseln
//                     zwischen zwei Abfragen 99,7 % der Kacheln ihren Platz,
//                     das Bild waere nur noch Flimmern. Stattdessen bleiben
//                     bekannte Kacheln liegen, Abgaenge geben ihre Flaeche
//                     zurueck und Zugaenge fuellen die Luecken. Nachgemessen
//                     bleibt die Packung dabei dicht (0,7 % -> 3,0 % freie
//                     Zellen, fast alle an der Oberkante) -- genau dafuer
//                     fuehrt `mondrian.js` eine exakte Belegungskarte.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "mondrian.js" as Mondrian
import "colors.js" as Palette

pragma ComponentBehavior: Bound

Item {
    id: root

    // Die aufbereiteten Kacheldaten aus /lookup/blocktiles/<hash> oder
    // /lookup/projectedtiles/<rang>
    property var block: null
    property bool live: false
    property string colorMode: "fee"      // fee | age
    property color dimColor: "#9a94a6"
    property real labelSize: 11

    // Je Kachel: { sq: {x,y,r}, b: Gebuehrenklasse, d: Angaben fuer den Tooltip }
    property var squares: []
    property int gridUnits: 0
    property int rowsUsed: 0
    property var cellIdx: ({})
    property bool __idxDirty: true
    property var hovered: null

    // Was sich bei der letzten Aktualisierung getan hat -- die Ansicht darueber
    // schreibt es hin, und die frischen Kacheln blitzen kurz weiss auf.
    property int addedCount: 0
    property int removedCount: 0
    property var freshIdx: []
    property real flashPhase: 0
    // Umriss der frischen Kacheln. Ohne ihn raeumt jedes Bild des Ausblendens
    // die ganze Leinwand ab und schiebt sie neu hinueber -- gemessen 4 % CPU.
    property var flashBox: null

    // Der laufend gepflegte Zustand des lebendigen Betriebs
    property var __lay: null
    property var __byId: ({})

    signal txPicked(string txid)

    readonly property real side: Math.min(width, height)
    // Ganzzahlige Rasterweite -- siehe DOKUMENTATION, sonst werden die Kacheln
    // ungleich und es entsteht ein Karomuster.
    function unit(rows) {
        var g = side / Math.max(1, rows);
        return g < 2 ? g : Math.floor(g);
    }

    function pad(g) {
        if (g < 2)
            return g / 4;
        return Math.max(1, Math.round(g / 8));
    }

    onBlockChanged: rebuild()
    onWidthChanged: repaintAll()
    onHeightChanged: repaintAll()
    onLiveChanged: {
        // Beim Wechsel der Betriebsart faengt die Buchfuehrung von vorn an
        root.__lay = null;
        root.__byId = ({});
        rebuild();
    }

    function repaintAll() {
        canvas.requestPaint();
        flashCanvas.requestPaint();
    }

    // Aus den Kacheldaten die Einzelangaben herausziehen: je Kachel eine
    // Kennung, die Kantenlaenge, die Gebuehrenklasse und die Zeile fuer den
    // Tooltip. Die Kennung ist die TXID -- ohne sie gibt es keinen lebendigen
    // Betrieb, denn nur an ihr laesst sich "kenne ich schon" ablesen.
    function records(b) {
        var tiles = b.tiles;
        var n = Math.floor(tiles.length / 2);
        var txs = b.txs || [];
        var out = [];
        for (var i = 0; i < n; i++) {
            var d = txs[i];
            out.push({
                "id": (d && d[0]) ? String(d[0]) : ("#" + i),
                "r": parseInt(tiles.charAt(i * 2), 10) || 1,
                "b": parseInt(tiles.charAt(i * 2 + 1), 10) || 0,
                "d": d || null
            });
        }
        return out;
    }

    function gridFor(recs) {
        var w = 0;
        for (var i = 0; i < recs.length; i++)
            w += recs[i].r * recs[i].r;
        return Math.max(4, Math.ceil(Math.sqrt(w)));
    }

    // Die Zuordnung Zelle -> Kachel neu aufbauen. Sie traegt den Tooltip und
    // den Klick -- und wird deshalb erst gebaut, wenn die Maus wirklich ueber
    // der Grafik steht. Bei jeder Aktualisierung sind es siebentausend
    // Eintraege, die sonst niemand liest.
    function reindex() {
        root.__idxDirty = false;
        var idx = {};
        for (var i = 0; i < root.squares.length; i++) {
            var sq = root.squares[i].sq;
            for (var cx = 0; cx < sq.r; cx++) {
                for (var cy = 0; cy < sq.r; cy++)
                    idx[(sq.x + cx) + ":" + (sq.y + cy)] = i;
            }
        }
        root.cellIdx = idx;
    }

    function clear() {
        root.squares = [];
        root.cellIdx = ({});
        root.__idxDirty = true;
        root.freshIdx = [];
        root.__lay = null;
        root.__byId = ({});
        root.hovered = null;
        repaintAll();
    }

    function rebuild() {
        var b = root.block;
        if (!b || !b.tiles || b.tiles.length < 2) {
            clear();
            return;
        }
        var recs = root.records(b);
        if (!root.live) {
            root.fullBuild(recs);
            return;
        }

        // Lohnt das Nachfuehren ueberhaupt? Nach einem Blockfund ist der
        // geplante Block ein voellig anderer -- dann ist Neupacken richtig.
        var known = 0;
        for (var i = 0; i < recs.length; i++) {
            if (root.__byId[recs[i].id])
                known++;
        }
        var gw = root.gridFor(recs);
        var passt = root.__lay !== null && recs.length > 0
            && known / recs.length > 0.25
            && Math.abs(gw - root.gridUnits) <= root.gridUnits * 0.15;
        if (!passt) {
            root.fullBuild(recs);
            return;
        }
        root.update(recs);
    }

    function fullBuild(recs) {
        var gw = root.gridFor(recs);
        var lay = new Mondrian.MondrianLayout(gw);
        var out = [], byId = {};
        for (var i = 0; i < recs.length; i++) {
            var e = { "sq": lay.place(recs[i].r), "b": recs[i].b, "d": recs[i].d };
            out.push(e);
            byId[recs[i].id] = e;
        }
        root.squares = out;
        root.gridUnits = gw;
        root.rowsUsed = Math.max(gw, lay.height());
        root.__lay = lay;
        root.__byId = byId;
        root.addedCount = 0;
        root.removedCount = 0;
        root.freshIdx = [];
        root.flashPhase = 0;
        root.__idxDirty = true;
        repaintAll();
    }

    // Nachfuehren statt neu packen: erst alle Abgaenge, damit ihre Flaeche
    // wieder zur Verfuegung steht, dann die Zugaenge in der Reihenfolge, in der
    // sie geliefert wurden (nach Gebuehrenrate absteigend).
    function update(recs) {
        var lay = root.__lay;
        var alt = root.__byId, neu = {}, i, e;
        var vorhanden = {};
        for (i = 0; i < recs.length; i++)
            vorhanden[recs[i].id] = recs[i];

        var raus = 0;
        for (var id in alt) {
            if (!vorhanden[id]) {
                lay.remove(alt[id].sq);
                raus++;
            }
        }

        var out = [], fresh = [], dazu = 0;
        for (i = 0; i < recs.length; i++) {
            var r = recs[i];
            e = alt[r.id];
            if (e) {
                // Bekannt: Platz behalten, aber Gebuehrenklasse und Angaben
                // nachziehen -- die Rate einer Transaktion kann sich aendern.
                e.b = r.b;
                e.d = r.d;
            } else {
                e = { "sq": lay.place(r.r), "b": r.b, "d": r.d };
                fresh.push(out.length);
                dazu++;
            }
            neu[r.id] = e;
            out.push(e);
        }

        root.squares = out;
        root.__byId = neu;
        root.rowsUsed = Math.max(root.gridUnits, lay.height());
        root.addedCount = dazu;
        root.removedCount = raus;
        root.freshIdx = fresh;
        root.__idxDirty = true;
        canvas.requestPaint();

        root.computeFlashBox();
        // Nur aufblitzen lassen, wenn jemand hinsieht
        if (fresh.length > 0 && root.visible) {
            root.flashPhase = 1;
            flashTimer.restart();
        } else {
            root.flashPhase = 0;
        }
        root.markFlash();
    }

    // Nur die Aenderung einarbeiten. Der Daemon fuehrt ein Aenderungsbuch und
    // schickt auf Wunsch nur, was seit dem letzten Stand zu- und abgegangen
    // ist -- gemessen 5 bis 90 kB statt 634 kB je Abfrage. Ohne das kostete
    // allein das Zerlegen des JSON 6 % CPU.
    function applyDelta(d) {
        if (!root.live || root.__lay === null || !root.squares.length) {
            return false;
        }
        var lay = root.__lay, byId = root.__byId, i;

        var raus = 0, rem = d.removed || [];
        for (i = 0; i < rem.length; i++) {
            var alt = byId[rem[i]];
            if (alt) {
                lay.remove(alt.sq);
                delete byId[rem[i]];
                raus++;
            }
        }

        var recs = (d.tiles && d.tiles.length >= 2) ? root.records(d) : [];
        var frisch = {}, dazu = 0;
        for (i = 0; i < recs.length; i++) {
            var r = recs[i];
            var e = byId[r.id];
            if (e) {
                // Schon da: nur die Gebuehrenklasse zieht nach, der Platz
                // bleibt. Genau das ist der Sinn der Uebung.
                e.b = r.b;
                e.d = r.d;
            } else {
                byId[r.id] = { "sq": lay.place(r.r), "b": r.b, "d": r.d };
                frisch[r.id] = true;
                dazu++;
            }
        }

        // Die Kachelliste neu aufreihen. Die Reihenfolge spielt fuers Bild
        // keine Rolle -- jede Kachel traegt ihren Platz bei sich.
        var out = [], fresh = [];
        for (var id in byId) {
            if (frisch[id])
                fresh.push(out.length);
            out.push(byId[id]);
        }

        root.squares = out;
        root.__byId = byId;
        root.rowsUsed = Math.max(root.gridUnits, lay.height());
        root.addedCount = dazu;
        root.removedCount = raus;
        root.freshIdx = fresh;
        root.__idxDirty = true;
        canvas.requestPaint();

        root.computeFlashBox();
        if (fresh.length > 0 && root.visible) {
            root.flashPhase = 1;
            flashTimer.restart();
        } else {
            root.flashPhase = 0;
        }
        root.markFlash();
        return true;
    }

    // Das Ausblenden laeuft ueber einen Zeitgeber, nicht ueber eine
    // NumberAnimation. Eine Animation taktet mit der Bildwiederholrate, und
    // jedes Bild kostet hier -- nachgemessen 5 % CPU allein fuer einen
    // pulsierenden Punkt von sechs Pixeln. Fuenf Stufen ueber 750 ms sehen
    // aus wie ein Verlauf und kosten ein Zwoelftel davon.
    Timer {
        id: flashTimer

        interval: 150
        repeat: true
        running: false
        onTriggered: {
            root.flashPhase -= 0.2;
            if (root.flashPhase <= 0.01 || !root.visible) {
                root.flashPhase = 0;
                stop();
            }
            root.markFlash();
        }
    }

    // Nur den Umriss der frischen Kacheln neu zeichnen lassen
    function markFlash() {
        if (root.flashBox)
            flashCanvas.markDirty(Qt.rect(root.flashBox.x, root.flashBox.y,
                                          root.flashBox.w, root.flashBox.h));
        else
            flashCanvas.requestPaint();
    }

    // Umriss aller frischen Kacheln in Leinwandkoordinaten
    function computeFlashBox() {
        if (!root.freshIdx.length) {
            root.flashBox = null;
            return;
        }
        var g = root.gridStep, p = root.pad(g);
        var bx = root.originX, by = root.originY;
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (var i = 0; i < root.freshIdx.length; i++) {
            var s = root.squares[root.freshIdx[i]];
            if (!s)
                continue;
            var t = root.rectFor(s.sq, g, bx, by, p);
            if (t.x < x0) x0 = t.x;
            if (t.y < y0) y0 = t.y;
            if (t.x + t.w > x1) x1 = t.x + t.w;
            if (t.y + t.h > y1) y1 = t.y + t.h;
        }
        root.flashBox = x1 < x0 ? null
            : { "x": Math.floor(x0) - 1, "y": Math.floor(y0) - 1,
                "w": Math.ceil(x1 - x0) + 2, "h": Math.ceil(y1 - y0) + 2 };
    }

    function rectFor(q, g, bx, by, p) {
        if (g < 2) {
            var sd = Math.max(0.35, q.r * g - p * 2);
            return { "x": bx + q.x * g + p, "y": by + q.y * g + p, "w": sd, "h": sd };
        }
        var x0 = Math.round(bx + q.x * g), x1 = Math.round(bx + (q.x + q.r) * g);
        var y0 = Math.round(by + q.y * g), y1 = Math.round(by + (q.y + q.r) * g);
        return { "x": x0 + p, "y": y0 + p,
                 "w": Math.max(1, x1 - x0 - p * 2), "h": Math.max(1, y1 - y0 - p * 2) };
    }

    readonly property real gridStep: unit(rowsUsed)
    readonly property real originX: Math.round((side - gridUnits * gridStep) / 2)
    readonly property real originY: Math.round((side - rowsUsed * gridStep) / 2)

    Canvas {
        id: canvas

        anchors.centerIn: parent
        width: root.side
        height: root.side
        antialiasing: root.rowsUsed > 0 && root.gridStep < 2

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.squares.length)
                return;
            var g = root.gridStep;
            var p = root.pad(g);
            var bx = root.originX;
            var by = root.originY;

            // Nach Farbe buendeln -- das spart tausende Zustandswechsel
            var groups = {}, i, s, c;
            for (i = 0; i < root.squares.length; i++) {
                s = root.squares[i];
                c = Palette.bucketColor(s.b);
                if (!groups[c])
                    groups[c] = [];
                groups[c].push(s);
            }
            for (var col in groups) {
                ctx.fillStyle = col;
                var list = groups[col];
                for (i = 0; i < list.length; i++) {
                    var t = root.rectFor(list[i].sq, g, bx, by, p);
                    ctx.fillRect(t.x, t.y, t.w, t.h);
                }
            }

            // Kachel unter dem Zeiger hervorheben
            if (root.hovered !== null && root.squares[root.hovered]) {
                var h = root.rectFor(root.squares[root.hovered].sq, g, bx, by, p);
                ctx.fillStyle = Palette.hoverColor();
                ctx.fillRect(h.x, h.y, h.w, h.h);
            }
        }
    }

    // Die frisch hinzugekommenen Kacheln liegen auf einer eigenen Leinwand --
    // dieselbe Aufteilung wie im Feed (Halde unten, fallende Kacheln darueber).
    // Nur so kostet das Aufblitzen wenige Rechtecke statt des ganzen Blocks.
    Canvas {
        id: flashCanvas

        anchors.fill: canvas
        antialiasing: canvas.antialiasing
        visible: root.flashPhase > 0

        onPaint: {
            var ctx = getContext("2d");
            var box = root.flashBox;
            if (box)
                ctx.clearRect(box.x, box.y, box.w, box.h);
            else
                ctx.reset();
            if (root.flashPhase <= 0 || !root.freshIdx.length)
                return;
            var g = root.gridStep;
            var p = root.pad(g);
            var bx = root.originX;
            var by = root.originY;
            var weiss = Palette.iceWhite();
            for (var i = 0; i < root.freshIdx.length; i++) {
                var s = root.squares[root.freshIdx[i]];
                if (!s)
                    continue;
                var t = root.rectFor(s.sq, g, bx, by, p);
                ctx.fillStyle = Palette.blendHex(Palette.bucketColor(s.b), weiss, root.flashPhase);
                ctx.fillRect(t.x, t.y, t.w, t.h);
            }
        }
    }

    function at(px, py) {
        if (!root.squares.length)
            return null;
        if (root.__idxDirty)
            root.reindex();
        var g = root.gridStep;
        var cx = Math.floor((px - root.originX) / g), cy = Math.floor((py - root.originY) / g);
        var i = root.cellIdx[cx + ":" + cy];
        return i === undefined ? null : i;
    }

    MouseArea {
        anchors.fill: canvas
        hoverEnabled: true

        onPositionChanged: mouse => {
            var i = root.at(mouse.x, mouse.y);
            if (i !== root.hovered) {
                root.hovered = i;
                canvas.requestPaint();
            }
        }
        onExited: {
            root.hovered = null;
            canvas.requestPaint();
        }
        onClicked: {
            var d = root.hovered !== null && root.squares[root.hovered]
                ? root.squares[root.hovered].d : null;
            if (d && d[0])
                root.txPicked(String(d[0]));
        }
    }

    // Angaben zur Kachel unter dem Zeiger
    Rectangle {
        visible: root.hovered !== null && tipCol.height > 0
        width: tipCol.width + root.labelSize * 1.6
        height: tipCol.height + root.labelSize * 1.2
        radius: root.labelSize * 0.4
        color: Qt.rgba(0.05, 0.05, 0.08, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        x: Math.max(0, Math.min(root.width - width, root.width / 2 - width / 2))
        y: root.height - height - root.labelSize * 0.4
        z: 20

        Column {
            id: tipCol

            anchors.centerIn: parent
            spacing: 1

            readonly property var d: (root.hovered !== null && root.squares[root.hovered])
                ? root.squares[root.hovered].d : null

            Text {
                visible: tipCol.d !== null && tipCol.d !== undefined
                text: tipCol.d ? String(tipCol.d[0]).substring(0, 20) + "…" : ""
                color: "#f2eef8"
                font.pixelSize: root.labelSize
                font.family: "monospace"
            }

            Text {
                visible: tipCol.d !== null && tipCol.d !== undefined
                text: tipCol.d
                    ? (tipCol.d[1] + " vByte · " + tipCol.d[4] + " sat/vB · "
                       + (tipCol.d[3] / 1e8).toFixed(8).replace(".", ",") + " ₿")
                    : ""
                color: root.dimColor
                font.pixelSize: root.labelSize * 0.92
            }
        }
    }
}
