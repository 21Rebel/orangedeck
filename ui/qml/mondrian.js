// Packung der Transaktionsquadrate, nach dem Vorbild von bitfeed
// (client/src/models/TxMondrianPoolScene.js, MIT, mononaut).
//
// Die Anordnung ist dieselbe: das Raster ist "width" Einheiten breit, waechst
// nach oben, und jede Transaktion kommt an die erste freie Stelle von unten
// links, an die ihr r x r grosses Quadrat passt. Genau daraus entsteht das
// typische Bild -- grosse Quadrate verstreut zwischen dicht gepackten kleinen.
//
// Die Buchhaltung darunter ist bewusst anders geloest. Das Original fuehrt eine
// Liste freier "Slots" {x, y, r}. Das ist schnell, gibt beim Entfernen einer
// Kachel aber nicht die ganze Flaeche zurueck: nachgemessen sinkt die Dichte
// bei staendigem Umschichten von 96 % auf 90 % und die Loecher wachsen
// unaufhaltsam. Bitfeed stoert das nicht, weil es Kacheln fast nie entfernt --
// diese Ansicht schichtet dagegen laufend um. Hier steht deshalb eine exakte
// Belegungskarte: eine Zelle ist belegt oder frei, mehr nicht.

.pragma library

function MondrianLayout(width) {
    this.width = width;
    this.rows = [];          // je Zeile ein Array, 1 = belegt
    this.rowFree = [];       // Anzahl freier Zellen je Zeile
    this.lowestFree = 0;     // ab dieser Zeile lohnt das Suchen
    // Die unterste Zeile faellt aus dem Bild, wenn die Halde zu hoch wird.
    // Damit die Kacheln darueber ihre Koordinate behalten, zaehlt rowOffset
    // mit, wie viele Zeilen schon unten herausgefallen sind. Alle y-Werte sind
    // absolut, der Zugriff auf rows[] geht ueber y - rowOffset.
    this.rowOffset = 0;
}

MondrianLayout.prototype.idx = function (y) {
    return y - this.rowOffset;
};

MondrianLayout.prototype.ensureRows = function (upTo) {
    var need = this.idx(upTo);
    while (this.rows.length <= need) {
        var row = new Array(this.width);
        for (var i = 0; i < this.width; i++)
            row[i] = 0;
        this.rows.push(row);
        this.rowFree.push(this.width);
    }
};

MondrianLayout.prototype.fits = function (x, y, r) {
    if (x + r > this.width)
        return false;
    for (var yy = this.idx(y); yy < this.idx(y) + r; yy++) {
        if (yy < 0)
            return false;                // schon herausgefallen
        if (yy >= this.rows.length)
            continue;                    // noch nicht angelegte Zeilen sind frei
        var row = this.rows[yy];
        for (var xx = x; xx < x + r; xx++) {
            if (row[xx])
                return false;
        }
    }
    return true;
};

MondrianLayout.prototype.mark = function (x, y, r, value) {
    this.ensureRows(y + r);
    for (var yy = this.idx(y); yy < this.idx(y) + r; yy++) {
        if (yy < 0 || yy >= this.rows.length)
            continue;
        var row = this.rows[yy];
        for (var xx = x; xx < x + r; xx++) {
            if (row[xx] !== value) {
                row[xx] = value;
                this.rowFree[yy] += value ? -1 : 1;
            }
        }
    }
};

// Setzt ein Quadrat der Kantenlaenge "size" an die erste passende Stelle von
// unten links und liefert {x, y, r}.
MondrianLayout.prototype.place = function (size) {
    var y = Math.max(this.lowestFree, this.rowOffset);
    for (;;) {
        this.ensureRows(y + size);
        if (this.rowFree[this.idx(y)] >= size) {
            var row = this.rows[this.idx(y)];
            for (var x = 0; x + size <= this.width; x++) {
                if (row[x])
                    continue;
                if (this.fits(x, y, size)) {
                    this.mark(x, y, size, 1);
                    while (this.idx(this.lowestFree) < this.rows.length && this.rowFree[this.idx(this.lowestFree)] === 0)
                        this.lowestFree++;
                    return { x: x, y: y, r: size };
                }
            }
        }
        y++;
    }
};

MondrianLayout.prototype.remove = function (square) {
    this.mark(square.x, square.y, square.r, 0);
    if (square.y < this.lowestFree)
        this.lowestFree = square.y;
};

// **Schwerkraft: Kacheln ruecken in die Luecken nach.** Nach dem Vorbild von
// mempool.space (`BlockLayout.applyGravity` in
// frontend/src/app/components/block-overview-graph/block-scene.ts): jede
// Kachel, unter der die ganze Zeile davor frei ist, wird herausgenommen und
// an der ersten passenden Stelle neu gesetzt. Ihre eigene Stelle ist dabei
// wieder frei, sie landet also nie schlechter als vorher.
//
// Gebraucht wird das beim Nachfuehren eines geplanten Blocks: Abgaenge geben
// ihre Flaeche zurueck, Zugaenge fuellen die Luecken von vorn -- aber nur,
// wenn sie hineinpassen. Was nicht passt, blieb bis zum 10.09.2026 als Loch
// stehen, auf dem Telefon wie am Schreibtisch. In einer Simulation mit
// 150 Runden Umschichtung (`node tools/packung-sim.js`) sank die Zahl der
// eingeschlossenen freien Zellen damit von 525 auf 139, bei rund 25
// bewegten Kacheln je Runde. Eine strengere Fassung (jede Kachel neu setzen)
// kam auf 106, bewegte aber sechsmal so viele -- das Bild waere unruhig
// geworden fuer wenig mehr. Mehrere Durchgaenge je Runde brachten nichts:
// in der Reihenfolge von vorn nach hinten erfasst einer schon die Ketten.
//
// `entries` sind Objekte mit `sq` = {x, y, r}; `sq` wird ersetzt, wenn die
// Kachel faellt. Rueckgabe: wie viele gefallen sind.
MondrianLayout.prototype.gravity = function (entries) {
    var order = entries.slice().sort(function (a, b) {
        return a.sq.y - b.sq.y || a.sq.x - b.sq.x;
    });
    var moved = 0;
    for (var i = 0; i < order.length; i++) {
        var q = order[i].sq;
        var vorher = this.idx(q.y - 1);
        if (vorher < 0 || vorher >= this.rows.length)
            continue;
        var row = this.rows[vorher], frei = true;
        for (var x = q.x; x < q.x + q.r; x++) {
            if (row[x]) {
                frei = false;
                break;
            }
        }
        if (!frei)
            continue;
        this.remove(q);
        var neu = this.place(q.r);
        order[i].sq = neu;
        if (neu.x !== q.x || neu.y !== q.y)
            moved++;
    }
    return moved;
};

// Freie Zellen, unter denen in derselben Spalte noch eine Kachel liegt --
// die Loecher, die man sieht. Der ausgefranste Rand ganz hinten gehoert zu
// jeder Packung und zaehlt nicht mit.
MondrianLayout.prototype.enclosedHoles = function () {
    var h = this.height(), n = 0;
    for (var x = 0; x < this.width; x++) {
        var letzte = -1, y;
        for (y = 0; y < h; y++) {
            if (this.rows[y][x])
                letzte = y;
        }
        for (y = 0; y < letzte; y++) {
            if (!this.rows[y][x])
                n++;
        }
    }
    return n;
};

// **Stabil neu packen: dieselbe Reihenfolge, keine Loecher.** Die Schwerkraft
// allein reicht nicht. Am 10.09.2026 sieben Minuten lang am echten Strom
// gemessen, zwei Instanzen am selben Daemon, eingeschlossene Zellen je
// Minute in einem Block von 110 x 110:
//
//     ohne Schwerkraft    0  10  308  799  933  818  629
//     mit Schwerkraft     0   7  113  247  387  312  219
//
// Sie drittelt die Loecher, verhindert sie aber nicht: ein Loch, ueber dem
// eine breitere Kachel liegt, bleibt offen. mempool.space lebt damit bis zum
// naechsten Blockfund; hier wurde es als Fehler gemeldet.
//
// Also werden die Kacheln, sobald die Loecher ueberhand nehmen, in ihrer
// jetzigen Reihenfolge (von vorn nach hinten, Zeile fuer Zeile) in eine
// frische Packung gesetzt. Wer vor dem ersten Loch liegt, bleibt, wo er ist;
// dahinter ruecken die Kacheln auf. In der Simulation (`node
// tools/packung-sim.js`) wechselten dabei 7 bis 11 % der Kacheln den Platz --
// nicht die 99,7 % eines Neupackens nach Gebuehr, das den Block in Flimmern
// aufloeste. Liefert die neue Packung; `sq` der Eintraege wird ersetzt.
function repackStable(width, entries) {
    var lay = new MondrianLayout(width);
    var order = entries.slice().sort(function (a, b) {
        return a.sq.y - b.sq.y || a.sq.x - b.sq.x;
    });
    for (var i = 0; i < order.length; i++)
        order[i].sq = lay.place(order[i].sq.r);
    return lay;
}

// Oberste belegte Zeile
// Hoehe der Halde in sichtbaren Zeilen
MondrianLayout.prototype.height = function () {
    for (var y = this.rows.length - 1; y >= 0; y--) {
        if (this.rowFree[y] < this.width)
            return y + 1;
    }
    return 0;
};

// Unterste Zeile aus dem Bild schieben. Sie muss vorher leer sein -- die
// Kacheln darin fallen sichtbar nach unten heraus.
MondrianLayout.prototype.dropBottomRow = function () {
    if (this.rows.length === 0)
        return;
    this.rows.shift();
    this.rowFree.shift();
    this.rowOffset++;
    if (this.lowestFree < this.rowOffset)
        this.lowestFree = this.rowOffset;
};

// Groesse einer Transaktion in Rastereinheiten -- exakt wie logTxSize() im Original
function txSize(valueSats, max) {
    var v = Math.max(1, valueSats || 1);
    var scale = Math.ceil(Math.log(v) / Math.LN10) - 5;
    return Math.min(max || 5, Math.max(1, scale));
}
