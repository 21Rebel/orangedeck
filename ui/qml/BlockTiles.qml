// Die Kachelgrafik eines Blocks -- dieselbe Optik wie im Feed, nur fuer einen
// beliebigen Block aus dem Explorer.
//
// Packung und Farben kommen aus denselben Bausteinen wie dort (`mondrian.js`,
// `colors.js`), damit beide Ansichten wirklich gleich aussehen und nicht nur
// aehnlich.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "mondrian.js" as Mondrian
import "colors.js" as Palette

pragma ComponentBehavior: Bound

Item {
    id: root

    // Die aufbereiteten Kacheldaten aus /lookup/blocktiles/<hash>
    property var block: null
    property string colorMode: "fee"      // fee | age
    property color dimColor: "#9a94a6"
    property real labelSize: 11

    property var squares: []
    property int gridUnits: 0
    property int rowsUsed: 0
    property var cellIdx: ({})
    property var hovered: null

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
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    function rebuild() {
        var b = root.block;
        if (!b || !b.tiles || b.tiles.length < 2) {
            squares = [];
            canvas.requestPaint();
            return;
        }
        var tiles = b.tiles;
        var n = Math.floor(tiles.length / 2);
        var sizes = [], buckets = [], weight = 0, i;
        for (i = 0; i < n; i++) {
            var r = parseInt(tiles.charAt(i * 2), 10) || 1;
            sizes.push(r);
            buckets.push(parseInt(tiles.charAt(i * 2 + 1), 10) || 0);
            weight += r * r;
        }
        var gw = Math.max(4, Math.ceil(Math.sqrt(weight)));
        var lay = new Mondrian.MondrianLayout(gw);
        var out = [], idx = {};
        for (i = 0; i < n; i++) {
            var sq = lay.place(sizes[i]);
            out.push({ "sq": sq, "b": buckets[i], "n": i });
            for (var cx = 0; cx < sq.r; cx++) {
                for (var cy = 0; cy < sq.r; cy++)
                    idx[(sq.x + cx) + ":" + (sq.y + cy)] = out.length - 1;
            }
        }
        squares = out;
        gridUnits = gw;
        rowsUsed = Math.max(gw, lay.height());
        cellIdx = idx;
        canvas.requestPaint();
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

    Canvas {
        id: canvas

        anchors.centerIn: parent
        width: root.side
        height: root.side
        antialiasing: root.rowsUsed > 0 && root.unit(root.rowsUsed) < 2

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!root.squares.length)
                return;
            var g = root.unit(root.rowsUsed);
            var p = root.pad(g);
            var bx = Math.round((width - root.gridUnits * g) / 2);
            var by = Math.round((height - root.rowsUsed * g) / 2);

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

    function at(px, py) {
        if (!root.squares.length)
            return null;
        var g = root.unit(root.rowsUsed);
        var bx = Math.round((canvas.width - root.gridUnits * g) / 2);
        var by = Math.round((canvas.height - root.rowsUsed * g) / 2);
        var cx = Math.floor((px - bx) / g), cy = Math.floor((py - by) / g);
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
            var d = root.hovered !== null && root.block && root.block.txs
                ? root.block.txs[root.squares[root.hovered].n] : null;
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

            readonly property var d: (root.hovered !== null && root.block && root.block.txs)
                ? root.block.txs[root.squares[root.hovered].n] : null

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
