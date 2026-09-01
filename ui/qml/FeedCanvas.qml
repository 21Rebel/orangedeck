// Bitfeed-Ansicht: gefundener Block in der Mitte, Mempool als Halde unten,
// neue Transaktionen fallen von oben hinein.
//
// Packung, Groessen und Farben folgen dem Original (bitfeed, MIT, mononaut):
//   Kantenlaenge = ceil(log10(Ausgabewert in sat)) - 5, begrenzt auf 1..5
//   Anordnung    = Mondrian-Slot-Layout, siehe mondrian.js
//   Farbe        = nach Alter (orange -> blau in 60 s) oder Gebuehrenrate
//   Abstand      = fester Pixelwert, deshalb ueberall gleich gross
import QtQuick
import "mondrian.js" as Mondrian
import "colors.js" as Palette

Item {
    id: root

    property var feed: null
    property bool paused: false
    property bool showBlock: true
    property real density: 1.0
    property string colorMode: "age"        // "age" | "fee"
    property string sizeMode: "value"       // "value" | "vbytes"
    property int fullMempool: 120000        // volle Halde entspricht so vielen TX
    property color gridColor: "#2a2a38"
    property color rulerColor: "#7d8a8a"
    property int labelFont: 11
    property bool showRuler: true

    // --- Raster und Aufteilung, Formeln aus bitfeed ----------------------
    // TxPoolScene.resize: heightLimit = Hoehe/4 (bei schmalen Fenstern /4,5).
    // Die Halde ist also auf ein Viertel der Fensterhoehe gedeckelt und reicht
    // nie weiter ins Bild -- genau das hat bei uns vorher gefehlt.
    readonly property real poolLimit: height / (width <= 620 ? 4.5 : 4)
    readonly property real poolTop: showBlock ? Math.max(0, height - poolLimit) : 0
    readonly property real poolH: height - poolTop
    // Im Original haengt die Kachelgroesse an der Fensterbreite
    // (max(4, Breite/250)) -- beim Aufziehen des Fensters wachsen die Kacheln
    // dort also mit. Hier ist sie **fest**: 4 px Kachel, 1 px Abstand, also
    // genau das Bild, das bitfeed bei rund tausend Pixeln Breite zeigt. Breiter
    // wird das Fenster, mehr Spalten passen hinein -- die Kacheln bleiben
    // gleich. Groesser oder kleiner geht ueber die Einstellung "Kachelgroesse".
    readonly property int unitWidth: Math.max(2, Math.min(10, Math.round(4 * density)))
    readonly property int unitPad: Math.max(1, Math.min(3, Math.round(density)))
    readonly property int gridSize: unitWidth + unitPad * 2
    readonly property int gridW: Math.max(8, Math.floor(width / gridSize) - 1)
    readonly property int gridRows: Math.max(3, Math.floor(poolH / gridSize))
    readonly property real gridLeft: Math.round((width - gridW * gridSize) / 2)
    // TxController.resize: blockAreaSize = min(Breite*0,75, Hoehe/2,5)
    readonly property real blockSide: Math.min(width * 0.72, height / 2.5, poolTop * 0.86)
    readonly property real blockCenterY: poolTop * 0.5
    // Oberkante der Halde -- dort sitzt die gestrichelte Linie, wie im Original
    // (mempoolScreenHeight). Sie wandert also mit dem Fuellstand.
    readonly property real pileTopY: height - pileRows * gridSize + scrollPx

    // --- Zustand ---------------------------------------------------------
    property var layout: null
    property var poolTx: []                 // {sq, t0, rate, fly, fromY}
    property var fallout: []            // unten herausfallende Transaktionen
    // Eigene Liste der noch fallenden Kacheln. Sonst muesste dreissigmal pro
    // Sekunde die ganze Halde durchlaufen werden, um die paar zu finden.
    property var flying: []
    property real scrollPx: 0           // sanftes Nachrutschen nach dem Abraeumen
    property var cellIndex: ({})            // Rasterzelle -> Kachel, fuer den Tooltip
    property var hoveredTx: null
    property var hoverRect: null            // Umriss der Kachel unter dem Zeiger
    property real hoverX: 0
    property real hoverY: 0
    property real blockPulse: 0

    // --- Sicht: Zoom und Verschiebung ------------------------------------
    // Die Kacheln sind 4 px gross; ohne Vergroesserung laesst sich eine
    // einzelne Transaktion kaum treffen. Der Zoom ist bewusst eine reine
    // *Sicht*-Angelegenheit: das Raster und die Packung bleiben unveraendert,
    // nur gezeichnet wird verschoben und skaliert. Deshalb sitzt er als
    // ctx.setTransform in den Leinwaenden und als transform auf den
    // Rechteck-Ebenen -- beides zeichnet dadurch scharf neu, statt ein
    // fertiges Bild zu vergroessern.
    property real zoom: 1
    property real viewX: 0
    property real viewY: 0
    readonly property real minZoom: 1
    readonly property real maxZoom: 24
    readonly property bool zoomed: zoom > 1.0001

    function viewApply(ctx) {
        ctx.setTransform(zoom, 0, 0, zoom, viewX, viewY);
    }

    function toSceneX(px) {
        return (px - viewX) / zoom;
    }

    function toSceneY(py) {
        return (py - viewY) / zoom;
    }

    // Nie ueber den Rand hinaus: bei Zoom 1 sitzt die Sicht wieder genau auf
    // dem Bild.
    function clampView() {
        if (zoom <= minZoom + 0.0001) {
            zoom = minZoom;
            viewX = 0;
            viewY = 0;
            return;
        }
        viewX = Math.min(0, Math.max(width - width * zoom, viewX));
        viewY = Math.min(0, Math.max(height - height * zoom, viewY));
    }

    // Vergroessern um einen festen Punkt herum: was unter dem Zeiger liegt,
    // bleibt unter dem Zeiger.
    function setZoomAt(px, py, z) {
        var z1 = Math.max(minZoom, Math.min(maxZoom, z));
        if (Math.abs(z1 - zoom) < 0.0001)
            return;
        var sx = toSceneX(px);
        var sy = toSceneY(py);
        zoom = z1;
        viewX = px - sx * z1;
        viewY = py - sy * z1;
        clampView();
        repaintView();
    }

    function zoomAt(px, py, factor) {
        setZoomAt(px, py, zoom * factor);
    }

    function panBy(dx, dy) {
        if (!zoomed)
            return;
        viewX += dx;
        viewY += dy;
        clampView();
        repaintView();
    }

    function resetView() {
        zoom = minZoom;
        viewX = 0;
        viewY = 0;
        repaintView();
    }

    function repaintView() {
        poolCanvas.requestPaint();
        blockCanvas.requestPaint();
        if (blockPhase !== "idle")
            blockAnim.requestPaint();
        flyLayer.refresh();
    }

    onWidthChanged: clampView()
    onHeightChanged: clampView()
    property var mining: []             // Kacheln auf dem Weg in den Block
    property string blockPhase: "idle"  // idle | ice | fly
    property real blockClock: 0
    property bool blockRevealed: true
    property real blockFade: 0
    property real levelClock: 0
    property int placed: 0
    property bool poolDirty: false
    property int pileRows: 0
    property int occupied: 0            // belegte Rastereinheiten, Summe r*r
    property var queue: []              // wartende Ankuenfte
    property real queueAcc: 0

    signal blockLayoutChanged

    // Abstand zwischen den Blockkacheln -- ein Viertel der Rasterweite wie im
    // Original, aber auf ganze Pixel gerundet. Zusammen mit den gerundeten
    // Kanten (siehe blockRect) sind die Luecken dadurch ueberall exakt gleich
    // breit. Vorher lagen sie auf gebrochenen Pixelwerten: mal fiel ein Pixel
    // mehr auf die Luecke, mal weniger, und daraus entstand ein Karomuster.
    function blockPad(g) {
        return Math.max(1, Math.round(g / 4));
    }

    function txSize(valueSats, vbytes) {
        if (sizeMode === "vbytes")
            return Math.min(5, Math.max(1, Math.ceil(Math.sqrt((vbytes || 1) / 256))));
        return Mondrian.txSize(valueSats, 5);
    }

    function resetPool() {
        queue = [];
        queueAcc = 0;
        layout = new Mondrian.MondrianLayout(gridW);
        poolTx = [];
        fallout = [];
        flying = [];
        scrollPx = 0;
        cellIndex = ({});
        hoveredTx = null;
        placed = 0;
        occupied = 0;
    }

    function addTx(value, rate, vsize, ageMs, tx) {
        return addSized(txSize(value, vsize), rate, ageMs, tx);
    }

    function addSized(size, rate, ageMs, tx) {
        if (!layout)
            return null;
        var sq = layout.place(size);
        var side = sq.r * gridSize - unitPad * 2;
        var entry = {
            "sq": sq,
            "t0": Date.now() - (ageMs || 0),
            "rate": rate,
            "fly": ageMs ? 1 : 0,
            "fromY": -side - Math.random() * height * 0.5,
            "vy": 0,
            "tx": tx || null
        };
        poolTx.push(entry);
        if (entry.fly < 1)
            flying.push(entry);
        occupied += sq.r * sq.r;
        placed++;
        for (var cx = 0; cx < sq.r; cx++) {
            for (var cy = 0; cy < sq.r; cy++)
                cellIndex[(sq.x + cx) + ":" + (sq.y + cy)] = entry;
        }
        return entry;
    }

    function removeTx(entry) {
        var i = poolTx.indexOf(entry);
        if (i < 0)
            return;
        poolTx.splice(i, 1);
        var fi = flying.indexOf(entry);
        if (fi >= 0)
            flying.splice(fi, 1);
        occupied -= entry.sq.r * entry.sq.r;
        for (var cx = 0; cx < entry.sq.r; cx++) {
            for (var cy = 0; cy < entry.sq.r; cy++)
                delete cellIndex[(entry.sq.x + cx) + ":" + (entry.sq.y + cy)];
        }
        if (hoveredTx && hoveredTx === entry.tx)
            hoveredTx = null;
        layout.remove(entry.sq);
    }

    function targetX(sq) {
        return gridLeft + sq.x * gridSize + unitPad;
    }

    // Der Bildpunkt wandert mit dem Foerderband: rowOffset zaehlt die Zeilen,
    // die unten schon herausgefallen sind, scrollPx laesst die Halde danach
    // sanft nachrutschen statt zu springen.
    function targetY(sq) {
        return height - (sq.y - layout.rowOffset + sq.r) * gridSize + unitPad + scrollPx;
    }

    // Die Halde arbeitet wie im Original als Foerderband: oben landen neue
    // Transaktionen, unten faellt die aelteste Zeile aus dem Bild. Dadurch
    // entstehen im Inneren gar keine Loecher -- nachgemessen ueber 40 000
    // Kacheln bleibt die Dichte bei 100 %. Vorher wurde mitten aus der Halde
    // entfernt; das loechert sie unaufhaltsam aus (bis 17 %).
    function shedBottomRow() {
        var base = layout.rowOffset;
        var keep = [];
        for (var i = 0; i < poolTx.length; i++) {
            var e = poolTx[i];
            if (e.sq.y === base) {
                var side = Math.max(1, e.sq.r * gridSize - unitPad * 2);
                fallout.push({
                    "x": targetX(e.sq),
                    "y0": targetY(e.sq),
                    "y": targetY(e.sq),
                    "s": side,
                    "c": colorFor(e)
                });
                occupied -= e.sq.r * e.sq.r;
                layout.remove(e.sq);
            } else {
                keep.push(e);
            }
        }
        poolTx = keep;
        layout.dropBottomRow();
        scrollPx = -gridSize;       // die Halde rutscht sichtbar nach
    }

    // Die Halde wird **nicht** kuenstlich aufgefuellt. Jede Kachel darin ist
    // eine echte Transaktion, die von oben hereingefallen ist. Der Preis dafuer:
    // nach dem Start dauert es rund eine Viertelstunde, bis die Halde voll ist
    // -- die oeffentliche Schnittstelle liefert nur die neu eintreffenden
    // Transaktionen (etwa fuenf pro Sekunde), nicht den Bestand des Mempools.
    // Vorher standen dort Platzhalter: die erschienen ohne zu fallen und hatten
    // keine Angaben fuer den Tooltip.
    function maintainPool(dt) {
        levelClock += dt;
        if (levelClock < 0.15 || !layout || gridW < 2)
            return false;
        levelClock = 0;

        // Was oben ueber den Rand waechst, faellt unten heraus
        var changed = false;
        var rounds = 0;
        while (layout.height() > gridRows && rounds++ < 3) {
            shedBottomRow();
            changed = true;
        }
        return changed;
    }


    // Welche Kachel liegt unter dem Mauszeiger? Ueber die Rasterzelle, damit es
    // nicht ueber tausende Kacheln laufen muss.
    // px/py sind bereits Szenenkoordinaten (siehe toSceneX/toSceneY).
    function txAt(px, py) {
        if (!layout || gridSize < 1)
            return null;
        if (py < pileTopY - gridSize)
            return null;
        var gx = Math.floor((px - gridLeft) / gridSize);
        var gy = layout.rowOffset + Math.floor((height + scrollPx - py) / gridSize);
        var e = cellIndex[gx + ":" + gy];
        return (e && e.fly >= 1) ? e : null;
    }

    // Blockfund, wie in bitfeed (TxController.addBlock + TxBlockScene.prepareTx):
    //
    // 1. Die geminten Transaktionen verschwinden aus der Halde und leuchten
    //    weiss auf (ice(): dieselbe Farbe mit Helligkeit 1 -> #ffffff).
    // 2. Sie pulsieren kurz, zeitlich versetzt. Das Blockfeld bleibt leer.
    // 3. Nach drei Sekunden fliegen **alle** Transaktionen des Blocks an ihren
    //    Platz. Die, die nicht mehr im Bild sind (der Mempool ist groesser als
    //    die sichtbare Halde), ziehen dafuer von unter der Bildkante herauf --
    //    im Original ist das `prepareTxOnScreen` fuer noch nicht gezeichnete
    //    Transaktionen.
    // 4. Zusammengesetzt wird in Weiss; erst danach faerbt sich der Block in
    //    einem Uebergang orange.
    function startBlockAnimation() {
        blockRevealed = false;
        blockPhase = "ice";
        blockClock = 0;
        blockPulse = 1;
        mining = [];

        // Ein Block fasst rund fuenf Prozent des Mempools -- ungefaehr so viele
        // Kacheln leuchten auch auf. Der Rest des Blocks zieht spaeter von
        // unter der Bildkante herauf.
        var take = Math.min(Math.round(poolTx.length * 0.12), 700);
        for (var i = 0; i < take && poolTx.length > 0; i++) {
            var e = poolTx[Math.floor(Math.random() * poolTx.length)];
            if (!e)
                continue;
            var side = Math.max(1, e.sq.r * gridSize - unitPad * 2);
            mining.push({
                "x0": targetX(e.sq),
                "y0": targetY(e.sq),
                "x": targetX(e.sq),
                "y": targetY(e.sq),
                "s0": side,
                "s": side,
                "ts": side,
                "tx": 0,
                "ty": 0,
                "white": 0,
                "delay": 0.2 + Math.random() * 1.5,
                "flyDelay": Math.random() * 0.9,
                "fromBelow": false
            });
            removeTx(e);
        }
    }

    function assignBlockTargets() {
        var list = blockCanvas.squares;
        if (!list || list.length === 0)
            return false;

        // Wie viele Kacheln der Block hat -- bei sehr grossen Bloecken wird
        // ausgeduennt, damit die Animation fluessig bleibt
        var maxTiles = 6000;
        var step = Math.max(1, Math.ceil(list.length / maxTiles));
        var targets = [];
        for (var i = 0; i < list.length; i += step)
            targets.push(blockCanvas.rectFor(list[i].sq));

        // vorhandene Kacheln aus der Halde zuerst
        var n = Math.min(mining.length, targets.length);
        for (var k = 0; k < n; k++) {
            var m = mining[k];
            var t = targets[k];
            m.tx = t.x;
            m.ty = t.y;
            m.ts = t.s;
            m.x0 = m.x;
            m.y0 = m.y;
            m.s0 = m.s;
        }
        if (mining.length > targets.length)
            mining = mining.slice(0, targets.length);

        // der Rest zieht von unter der Bildkante herauf
        for (var j = n; j < targets.length; j++) {
            var q = targets[j];
            mining.push({
                "x0": q.x + (Math.random() - 0.5) * width * 0.25,
                "y0": height + 10 + Math.random() * height * 0.7,
                "x": q.x,
                "y": height + 10,
                "s0": q.s,
                "s": q.s,
                "ts": q.s,
                "tx": q.x,
                "ty": q.y,
                "white": 1,
                "delay": 0,
                "flyDelay": Math.random() * 0.9,
                "fromBelow": true
            });
        }
        return true;
    }

    function finishBlockAnimation() {
        blockPhase = "idle";
        mining = [];
        blockRevealed = true;
        blockAnim.requestPaint();
        blockCanvas.requestPaint();
    }

    function stepBlockAnimation(dt) {
        if (blockPhase === "idle")
            return false;
        blockClock += dt;
        var i, m, u;

        if (blockPhase === "ice") {
            for (i = 0; i < mining.length; i++) {
                m = mining[i];
                u = blockClock - m.delay;
                if (u <= 0)
                    continue;
                m.white = Math.min(1, u / 0.35);
                var p = u < 0.75 ? Math.sin(u / 0.75 * Math.PI) : 0;
                m.s = m.s0 * (1 + 0.25 * p);
            }
            var ready = blockCanvas.forHeight === (feed ? feed.tipHeight : 0) && blockCanvas.squares.length > 0;
            if (blockClock > 3 && ready && assignBlockTargets()) {
                blockPhase = "fly";
                blockClock = 0;
            } else if (blockClock > 20) {
                finishBlockAnimation();
            }
            return true;
        }

        if (blockPhase === "fly") {
            var pending = false;
            for (i = 0; i < mining.length; i++) {
                m = mining[i];
                u = (blockClock - m.flyDelay) / 1.2;
                if (u < 1)
                    pending = true;
                u = u < 0 ? 0 : (u > 1 ? 1 : u);
                var ease = u * u * (3 - 2 * u);
                m.x = m.x0 + (m.tx - m.x0) * ease;
                m.y = m.y0 + (m.ty - m.y0) * ease;
                m.s = m.s0 + (m.ts - m.s0) * ease;
                m.white = 1;                 // zusammengesetzt wird in Weiss
            }
            if (!pending) {
                blockPhase = "settle";
                blockClock = 0;
            }
            return true;
        }

        // settle: der fertige Block faerbt sich von Weiss nach Orange
        blockFade = Math.min(1, blockClock / 0.9);
        if (blockClock > 1.15)
            finishBlockAnimation();
        return true;
    }

    function colorFor(entry) {
        if (colorMode === "fee")
            return Palette.feeColorForRate(entry.rate);
        return Palette.ageColor(Date.now() - entry.t0);
    }

    // mempool.space liefert die neuen Transaktionen im Sekundentakt als Paket.
    // Wuerden sie alle gleichzeitig losfallen, gaebe es Stoesse statt Regen --
    // also werden sie ueber das Intervall verteilt losgeschickt.
    function drainQueue(dt) {
        if (queue.length === 0) {
            queueAcc = 0;
            return;
        }
        queueAcc += (queue.length / 0.85) * dt;
        while (queueAcc >= 1 && queue.length > 0) {
            queueAcc -= 1;
            var t = queue.shift();
            addTx(t.a, t.r, t.v, 0, t);
        }
    }

    // Liefert true, wenn sich die Halde geaendert hat und neu gezeichnet werden muss
    function step(dt) {
        drainQueue(dt);
        var g = height * 1.1;
        var settled = false;
        var stillFlying = [];
        for (var i = 0; i < flying.length; i++) {
            var e = flying[i];
            e.vy += g * dt;
            var ty = targetY(e.sq);
            var span = ty - e.fromY;
            // Der Uebergang zaehlt, nicht der Zustand: 'pending' darf nur in
            // dem einen Bild gesetzt werden, in dem die Kachel landet. Wird es
            // stattdessen bei jedem 'fly >= 1' gesetzt, ueberschreibt step()
            // (30/s) sofort wieder, was poolCanvas.onPaint (5/s) zurueckgesetzt
            // hat -- die Kachel verlaesst 'flying' nie, die Liste waechst auf
            // die ganze Halde und ab 'capacity' fallen neue unsichtbar.
            var wasFlying = e.fly < 1;
            e.fly = span > 0 ? Math.min(1, e.fly + (e.vy * dt) / span) : 1;
            if (e.fly >= 1 && wasFlying) {
                e.pending = true;
                settled = true;
            }
            // Erst wenn die Halde neu gezeichnet ist (poolCanvas setzt pending
            // zurueck), faellt die Kachel aus dieser Liste. Sonst ist sie fuer
            // ein bis zwei Bilder nirgends zu sehen und blinkt weg.
            if (e.fly < 1 || e.pending)
                stillFlying.push(e);
        }
        if (stillFlying.length !== flying.length)
            flying = stillFlying;

        if (blockPulse > 0)
            blockPulse = Math.max(0, blockPulse - dt / 1.8);

        if (layout) {
            var rows = layout.height();
            if (rows !== pileRows)
                pileRows = rows;
        }

        var scrolled = false;
        if (scrollPx < 0) {
            scrollPx = Math.min(0, scrollPx + gridSize * dt / 0.3);
            scrolled = true;
        }

        // Die unterste Zeile wird beim Nachrutschen aus dem Bild geschoben --
        // keine eigene Fallanimation. Die ist den Transaktionen vorbehalten,
        // die wirklich aus dem Mempool verschwinden.
        if (fallout.length > 0) {
            if (scrollPx >= 0) {
                fallout = [];
            } else {
                for (var n = 0; n < fallout.length; n++)
                    fallout[n].y = fallout[n].y0 + gridSize + scrollPx;
            }
        }

        var animating = stepBlockAnimation(dt);
        return maintainPool(dt) || settled || scrolled || animating;
    }

    onGridWChanged: resetPool()
    onGridRowsChanged: resetPool()
    Component.onCompleted: resetPool()

    Connections {
        target: root.feed
        enabled: root.feed !== null

        function onTransactionsArrived(txs) {
            if (root.paused || !root.layout)
                return;
            for (var i = 0; i < txs.length; i++) {
                var t = txs[i];
                root.queue.push(t);
            }
        }

        function onBlockMined(tip) {
            root.startBlockAnimation();
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.visible && !root.paused && root.width > 0
        onTriggered: {
            if (root.step(0.033))
                root.poolDirty = true;
            flyLayer.refresh();
            if (root.blockPhase !== "idle")
                blockAnim.requestPaint();
        }
    }

    // Die Halde ist die teure Ebene. Sie wird hoechstens fuenfmal pro Sekunde
    // neu gezeichnet -- bis dahin zeichnet die Animationsebene weiter.
    Timer {
        interval: 200
        repeat: true
        running: root.visible && !root.paused
        onTriggered: {
            if (root.poolDirty) {
                root.poolDirty = false;
                poolCanvas.requestPaint();
            }
        }
    }

    // Die Farbe nach Alter wandert langsam -- dafuer reicht ein Neuzeichnen
    // im Sekundentakt statt dreissigmal pro Sekunde.
    Timer {
        interval: 1200
        repeat: true
        running: root.visible && !root.paused && root.colorMode === "age"
        onTriggered: poolCanvas.requestPaint()
    }


    // ------------------------------------------------------------ Blockfeld
    // Eigene Leinwand: der Block aendert sich nur alle zehn Minuten und muss
    // nicht dreissigmal pro Sekunde neu gezeichnet werden.
    Canvas {
        id: blockCanvas

        anchors.fill: parent
        antialiasing: false
        visible: root.showBlock

        property var squares: []
        property var cellIdx: ({})      // Rasterzelle -> Kachelnummer, fuer den Tooltip
        property int gridUnits: 1
        property int rowsUsed: 1
        property int forHeight: 0

        function rebuild() {
            var b = root.feed ? root.feed.block : null;
            if (!b || !b.tiles || b.tiles.length < 2) {
                squares = [];
                requestPaint();
                return;
            }

            var tiles = b.tiles;
            var n = Math.floor(tiles.length / 2);
            var sizes = [], buckets = [], weight = 0;
            for (var i = 0; i < n; i++) {
                var r = parseInt(tiles.charAt(i * 2), 10) || 1;
                sizes.push(r);
                buckets.push(parseInt(tiles.charAt(i * 2 + 1), 10) || 0);
                weight += r * r;
            }

            var gw = Math.max(4, Math.ceil(Math.sqrt(weight)));
            var lay = new Mondrian.MondrianLayout(gw);
            var out = [];
            for (var k = 0; k < n; k++)
                out.push({ "sq": lay.place(sizes[k]), "b": buckets[k] });

            var idx = {};
            for (var c = 0; c < out.length; c++) {
                var q = out[c].sq;
                for (var qx = 0; qx < q.r; qx++) {
                    for (var qy = 0; qy < q.r; qy++)
                        idx[(q.x + qx) + ":" + (q.y + qy)] = c;
                }
            }
            cellIdx = idx;

            squares = out;
            gridUnits = gw;
            rowsUsed = Math.max(gw, lay.height());
            forHeight = b.height;
            requestPaint();
        }

        // Umriss der Blockkachel unter dem Zeiger
        function hoverRectAt(px, py) {
            if (squares.length === 0)
                return null;
            var g = root.blockSide / rowsUsed;
            var pad = root.blockPad(g);
            var bx = (root.width - gridUnits * g) / 2;
            var by = root.blockCenterY - (rowsUsed * g) / 2;
            var cx = Math.floor((px - bx) / g);
            var cy = Math.floor((py - by) / g);
            var i = cellIdx[cx + ":" + cy];
            if (i === undefined || !squares[i])
                return null;
            return blockRect(squares[i].sq, g, bx, by, pad);
        }

        // Kanten auf ganze Pixel runden, damit alle Luecken gleich breit sind
        function blockRect(q, g, bx, by, pad) {
            var x0 = Math.round(bx + q.x * g);
            var x1 = Math.round(bx + (q.x + q.r) * g);
            var y0 = Math.round(by + q.y * g);
            var y1 = Math.round(by + (q.y + q.r) * g);
            return {
                "x": x0 + pad,
                "y": y0 + pad,
                "w": Math.max(1, x1 - x0 - pad * 2),
                "h": Math.max(1, y1 - y0 - pad * 2)
            };
        }

        // Welche Transaktion des Blocks liegt unter dem Zeiger?
        function blockTxAt(px, py) {
            if (squares.length === 0 || !root.blockRevealed)
                return null;
            var g = root.blockSide / rowsUsed;
            var bx = (root.width - gridUnits * g) / 2;
            var by = root.blockCenterY - (rowsUsed * g) / 2;
            var cx = Math.floor((px - bx) / g);
            var cy = Math.floor((py - by) / g);
            if (cx < 0 || cy < 0 || cx >= gridUnits || cy >= rowsUsed)
                return null;
            var i = cellIdx[cx + ":" + cy];
            if (i === undefined)
                return null;
            var list = (root.feed && root.feed.block) ? root.feed.block.txs : null;
            var t = list ? list[i] : null;
            if (!t)
                return null;
            return {
                "t": t[0],
                "v": t[1],
                "f": t[2],
                "a": t[3],
                "r": t[4],
                "inBlock": true
            };
        }

        // Bildschirmrechteck einer Blockkachel -- die Flugziele beim Blockfund
        function rectFor(q) {
            var side = root.blockSide;
            var g = side / rowsUsed;
            var pad = root.blockPad(g);
            var bx = (root.width - gridUnits * g) / 2;
            var by = root.blockCenterY - (rowsUsed * g) / 2;
            var r = blockRect(q, g, bx, by, pad);
            return {
                "x": r.x,
                "y": r.y,
                "s": r.w
            };
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            root.viewApply(ctx);
            // Waehrend die geminten Transaktionen unterwegs sind, ist das
            // Blockfeld leer -- der Block entsteht erst, wenn sie ankommen.
            if (!root.blockRevealed || squares.length === 0 || root.poolTop < 24)
                return;

            var side = root.blockSide;
            var g = side / rowsUsed;
            var pad = root.blockPad(g);
            var bx = (root.width - gridUnits * g) / 2;
            // Im Block laeuft die Rasterachse nach unten (Zeile 0 oben) -- die
            // zuerst gesetzten, grossen Transaktionen liegen dadurch oben.
            var by = root.blockCenterY - (rowsUsed * g) / 2;

            var byColor = {};
            for (var i = 0; i < squares.length; i++) {
                var s = squares[i];
                var c = root.colorMode === "fee" ? Palette.bucketColor(s.b) : Palette.blockAgeColor();
                if (!byColor[c])
                    byColor[c] = [];
                byColor[c].push(s.sq);
            }

            for (var col in byColor) {
                ctx.fillStyle = col;
                var list = byColor[col];
                for (var j = 0; j < list.length; j++) {
                    var r = blockRect(list[j], g, bx, by, pad);
                    ctx.fillRect(r.x, r.y, r.w, r.h);
                }
            }
        }

        Connections {
            target: root.feed
            enabled: root.feed !== null
            function onBlockChanged() {
                blockCanvas.rebuild();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: rebuild()

        Connections {
            target: root
            function onBlockRevealedChanged() {
                blockCanvas.requestPaint();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onPositionChanged: mouse => {
            // Der Tooltip sitzt am Fenster, die Trefferpruefung in der Szene.
            var sx = root.toSceneX(mouse.x);
            var sy = root.toSceneY(mouse.y);
            var e = root.txAt(sx, sy);
            root.hoverX = mouse.x;
            root.hoverY = mouse.y;
            if (e && e.tx) {
                root.hoveredTx = e.tx;
                var sd = Math.max(1, e.sq.r * root.gridSize - root.unitPad * 2);
                root.hoverRect = {
                    "x": root.targetX(e.sq),
                    "y": root.targetY(e.sq),
                    "w": sd,
                    "h": sd
                };
            } else if (sy < root.pileTopY) {
                // oberhalb der Halde: vielleicht das Blockfeld
                var bt = blockCanvas.blockTxAt(sx, sy);
                if (bt) {
                    root.hoveredTx = bt;
                    root.hoverRect = blockCanvas.hoverRectAt(sx, sy);
                }
            }
            // Zwischen zwei Kacheln liegt eine Luecke von ein paar Pixeln.
            // Faellt der Zeiger darauf, bleibt die letzte Angabe stehen, statt
            // zu flackern -- geraeumt wird beim Verlassen.
        }

        onExited: {
            root.hoveredTx = null;
            root.hoverRect = null;
        }
    }

    // ----------------------------------------------- Zoom und Verschieben
    // Drei Wege auf dieselbe Sicht: Rad, Zusammenziehen (Touchpad und
    // Bildschirm) und Ziehen. Die MouseArea darueber nimmt keine Tasten an
    // (`acceptedButtons: Qt.NoButton`), deshalb kommen sich beide nicht in die
    // Quere.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            // 1,0016 pro Rasterschritt: ein ueblicher Radschritt (120) ergibt
            // rund 21 % -- fein genug zum Anpeilen, schnell genug zum Erreichen.
            root.zoomAt(event.x, event.y, Math.pow(1.0016, event.angleDelta.y));
            event.accepted = true;
        }
    }

    PinchHandler {
        id: pinchView

        target: null
        property real startZoom: 1

        onActiveChanged: {
            if (active)
                startZoom = root.zoom;
        }
        onActiveScaleChanged: {
            if (active)
                root.setZoomAt(centroid.position.x, centroid.position.y,
                               startZoom * activeScale);
        }
    }

    DragHandler {
        id: panView

        target: null
        // Ohne Vergroesserung gibt es nichts zu verschieben -- dann bleibt das
        // Ziehen aus, damit es sich nicht wie ein haengendes Fenster anfuehlt.
        enabled: root.zoomed
        property real lastX: 0
        property real lastY: 0

        onActiveChanged: {
            lastX = centroid.position.x;
            lastY = centroid.position.y;
        }
        onCentroidChanged: {
            if (!active)
                return;
            root.panBy(centroid.position.x - lastX, centroid.position.y - lastY);
            lastX = centroid.position.x;
            lastY = centroid.position.y;
        }
    }

    // Doppeltippen bzw. Doppelklick stellt die Sicht wieder her.
    TapHandler {
        onDoubleTapped: root.resetView()
    }

    // Beim Blockfund fliegen bis zu dreitausend Kacheln gleichzeitig. Das
    // sprengt die Rechteck-Ebene, deshalb eine eigene Leinwand, die nur
    // waehrend der Animation zeichnet.
    Canvas {
        id: blockAnim

        anchors.fill: parent
        antialiasing: false
        visible: root.blockPhase !== "idle"

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            root.viewApply(ctx);
            if (root.blockPhase === "idle" || !root.mining || root.mining.length === 0)
                return;

            var ice = Palette.iceWhite();
            var mid = Palette.iceMid();
            var ramp = Palette.iceRamp();
            var i, m;

            if (root.blockPhase === "settle") {
                var idx = Math.max(0, Math.min(ramp.length - 1, Math.floor(root.blockFade * (ramp.length - 1))));
                ctx.fillStyle = ramp[idx];
                for (i = 0; i < root.mining.length; i++) {
                    m = root.mining[i];
                    ctx.fillRect(m.x, m.y, m.s, m.s);
                }
                return;
            }

            if (root.blockPhase === "fly") {
                ctx.fillStyle = ice;
                for (i = 0; i < root.mining.length; i++) {
                    m = root.mining[i];
                    ctx.fillRect(m.x, m.y, m.s, m.s);
                }
                return;
            }

            // ice: die Kacheln leuchten nacheinander auf
            for (i = 0; i < root.mining.length; i++) {
                m = root.mining[i];
                ctx.fillStyle = m.white > 0.66 ? ice : (m.white > 0.25 ? mid : Palette.blockAgeColor());
                ctx.fillRect(m.x, m.y, m.s, m.s);
            }
        }
    }

    // Die Transaktion unter dem Zeiger wird eingefaerbt, damit klar ist, wozu
    // die Angaben gehoeren -- im Original `hoverOn()` mit der Farbe bluegreen.
    Rectangle {
        id: hoverMark

        // Liegt in Szenenkoordinaten, wird also wie die Leinwaende transformiert.
        transform: [
            Scale { xScale: root.zoom; yScale: root.zoom },
            Translate { x: root.viewX; y: root.viewY }
        ]
        visible: opacity > 0.01
        color: Palette.hoverColor()
        opacity: root.hoverRect ? 1 : 0
        x: root.hoverRect ? root.hoverRect.x : 0
        y: root.hoverRect ? root.hoverRect.y : 0
        width: root.hoverRect ? root.hoverRect.w : 0
        height: root.hoverRect ? (root.hoverRect.h !== undefined ? root.hoverRect.h : root.hoverRect.w) : 0
        z: 60

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    // ----------------------------------------------------- Halde und Fallen
    Canvas {
        id: poolCanvas

        anchors.fill: parent
        antialiasing: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            // Nur den Haldenbereich loeschen statt der ganzen Leinwand -- im
            // Vollbild sind das vier Millionen Bildpunkte weniger pro Bild.
            // Bei Zoom greift die Sparmassnahme nicht mehr: die Halde kann dann
            // ueberall stehen, also die ganze Flaeche raeumen.
            var clearTop = root.zoomed ? 0 : Math.max(0, root.poolTop - 8);
            ctx.clearRect(0, clearTop, root.width, root.height - clearTop);
            root.viewApply(ctx);
            // Beim Laden und Entladen (z. B. Dashboard-Tab) kann gezeichnet
            // werden, bevor der Zustand steht
            if (!root.layout || !root.poolTx)
                return;

            var now = Date.now();
            var ageOn = root.colorMode === "age";
            var pal = Palette.ageColors();
            var steps = pal.length;

            // Nach Farbe buendeln -- das spart tausende Zustandswechsel
            var groups = {};
            var i, e, key;
            for (i = 0; i < root.poolTx.length; i++) {
                e = root.poolTx[i];
                if (e.fly < 1)
                    continue;
                e.pending = false;
                if (ageOn) {
                    var idx = Math.floor((now - e.t0) / 60000 * (steps - 1));
                    key = idx < 0 ? 0 : (idx >= steps ? steps - 1 : idx);
                } else {
                    key = Palette.feeColorForRate(e.rate);
                }
                if (!groups[key])
                    groups[key] = [];
                groups[key].push(e);
            }

            for (var g in groups) {
                ctx.fillStyle = ageOn ? pal[parseInt(g, 10)] : g;
                var list = groups[g];
                for (var j = 0; j < list.length; j++) {
                    var t = list[j];
                    var side = t.sq.r * root.gridSize - root.unitPad * 2;
                    if (side < 1)
                        side = 1;
                    ctx.fillRect(root.targetX(t.sq), root.targetY(t.sq), side, side);
                }
            }

            // Trennlinie am oberen Rand des Mempool-Bereichs. Von Hand
            // gestrichelt -- verlaesslicher als setLineDash.
            if (root.showRuler && root.pileRows > 0) {
                ctx.fillStyle = String(root.rulerColor);
                ctx.globalAlpha = 0.75;
                var y0 = Math.round(root.pileTopY) - 3.5;
                for (var dx = 0; dx < root.width; dx += 11)
                    ctx.fillRect(dx, y0, 6, 1);
                ctx.globalAlpha = 1;
            }
        }
    }

    Text {
        id: poolLabel

        anchors.left: parent.left
        y: Math.round(root.pileTopY) - height - 7
        visible: root.showRuler && root.pileRows > 0 && root.height > 150
        color: root.rulerColor
        font.pixelSize: root.labelFont
        text: {
            var n = root.feed ? root.feed.mempoolCount : 0;
            if (!n)
                return "Mempool";
            var t = String(n), out = "", c = 0;
            for (var i = t.length - 1; i >= 0; i--) {
                out = t[i] + out;
                if (++c % 3 === 0 && i > 0)
                    out = "." + out;
            }
            return "Mempool: " + out + " unbestätigt";
        }
    }

    // Fallende und eingesaugte Transaktionen als echte Rechtecke statt auf einer
    // Leinwand: es sind nur ein paar Dutzend, und so entfaellt das Vollbild-
    // Loeschen dreissigmal pro Sekunde.
    Item {
        id: flyLayer

        anchors.fill: parent
        // Rechtecke sind vektoriell -- sie bleiben beim Skalieren scharf.
        transform: [
            Scale { xScale: root.zoom; yScale: root.zoom },
            Translate { x: root.viewX; y: root.viewY }
        ]

        readonly property int capacity: 320

        function refresh() {
            if (!root.flying || !root.fallout)
                return;
            var n = 0;
            var i, item;

            for (i = 0; i < root.flying.length && n < capacity; i++) {
                var t = root.flying[i];
                item = flyRepeater.itemAt(n++);
                if (!item)
                    break;
                var side = Math.max(1, t.sq.r * root.gridSize - root.unitPad * 2);
                var ty = root.targetY(t.sq);
                item.x = root.targetX(t.sq);
                item.y = t.fromY + (ty - t.fromY) * t.fly;
                item.width = side;
                item.height = side;
                item.color = root.colorFor(t);
                item.opacity = 1;
                item.visible = true;
            }

            var cx = root.width / 2, cy = root.poolTop * 0.5;
            for (i = 0; i < root.fallout.length && n < capacity; i++) {
                var fo = root.fallout[i];
                item = flyRepeater.itemAt(n++);
                if (!item)
                    break;
                item.x = fo.x;
                item.y = fo.y;
                item.width = fo.s;
                item.height = fo.s;
                item.color = fo.c;
                item.opacity = 1;
                item.visible = true;
            }

            for (i = n; i < capacity; i++) {
                item = flyRepeater.itemAt(i);
                if (!item)
                    break;
                if (!item.visible)
                    break;
                item.visible = false;
            }
        }

        Repeater {
            id: flyRepeater

            model: flyLayer.capacity

            Rectangle {
                visible: false
                antialiasing: false
            }
        }
    }

    // Puls beim Blockfund
    Rectangle {
        visible: root.blockPulse > 0 && root.showBlock
        color: "transparent"
        border.color: "#f7941d"
        border.width: 2 + 8 * root.blockPulse
        opacity: root.blockPulse * 0.5
        width: root.blockSide + 32 * (1 - root.blockPulse)
        height: width
        x: (root.width - width) / 2
        y: root.blockCenterY - height / 2
    }
}
