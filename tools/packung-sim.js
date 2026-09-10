// Wie dicht bleibt ein geplanter Block, wenn er laufend umgeschichtet wird?
//
//     node tools/packung-sim.js
//
// **Warum es das gibt.** Am 10.09.2026 gemeldet: im Explorer entstehen beim
// naechsten Block "immer wieder Loecher", auf dem Telefon wie am Schreibtisch.
// `BlockTiles` fuehrt den geplanten Block nach, statt ihn neu zu packen (sonst
// wechselten 99,7 % der Kacheln je Abfrage den Platz). Abgaenge geben dabei
// ihre Flaeche zurueck, Zugaenge fuellen sie von vorn -- aber nur, wo sie
// hineinpassen.
//
// Die Simulation packt einen Block von rund 6500 Zellen, schichtet ihn 150
// Runden lang um (Abgaenge bevorzugt hinten, wo die guenstigen Transaktionen
// liegen; Zugaenge gleicher Flaeche) und zaehlt danach die eingeschlossenen
// freien Zellen: frei, und in derselben Spalte liegt weiter hinten noch eine
// Kachel. Das sind die Loecher, die man sieht. Der ausgefranste Rand ganz
// hinten gehoert zu jeder Packung und zaehlt nicht.
//
// Gemessen am 10.09.2026 (eingeschlossene Zellen am Ende und im Mittel ueber
// alle Runden, bewegte Kacheln insgesamt):
//
//     ohne Schwerkraft    525 / 388            0 bewegt
//     Schwerkraft         139 / 232         3724 bewegt
//     streng              106 / 107        21629 bewegt
//     beides               31 /  51        31863 bewegt, 89 x neu gepackt
//     frisch gepackt        0              (Massstab)
//
// Die Simulation schichtet haerter um als der echte Strom: dort erreichte
// die Schwerkraft allein ein Prozent Loecher erst nach gut zwei Minuten.
//
// "Schwerkraft" ist `MondrianLayout.gravity`, nach dem Vorbild von
// mempool.space; "streng" nimmt jede Kachel heraus und setzt sie neu;
// "beides" ist, was `BlockTiles` tut: Schwerkraft, und ab einem Prozent
// eingeschlossener Flaeche `repackStable`.
import("node:fs").then(fs => {
    const pfad = new URL("../ui/qml/mondrian.js", import.meta.url);
    const quelle = fs.readFileSync(pfad, "utf8").replace(".pragma library", "");
    const M = new Function(quelle + "; return { MondrianLayout, repackStable };")();

    let saat = 7;
    const zufall = () => (saat = (saat * 16807) % 2147483647) / 2147483647;
    // Meist eine Zelle, selten groesser -- wie in einem echten Block
    const groesse = () => {
        const u = zufall();
        return u < 0.72 ? 1 : u < 0.9 ? 2 : u < 0.97 ? 3 : u < 0.995 ? 4 : 5;
    };

    function streng(lay, kacheln) {
        const reihe = kacheln.slice().sort((a, b) => a.sq.y - b.sq.y || a.sq.x - b.sq.x);
        let bewegt = 0;
        for (const k of reihe) {
            const q = k.sq;
            if (lay.lowestFree >= q.y)
                continue;
            lay.remove(q);
            k.sq = lay.place(q.r);
            if (k.sq.x !== q.x || k.sq.y !== q.y)
                bewegt++;
        }
        return bewegt;
    }

    function eingeschlossen(lay, breite) {
        const h = lay.height();
        let n = 0;
        for (let x = 0; x < breite; x++) {
            let letzte = -1;
            for (let y = 0; y < h; y++)
                if (lay.rows[y][x])
                    letzte = y;
            for (let y = 0; y < letzte; y++)
                if (!lay.rows[y][x])
                    n++;
        }
        return n;
    }

    function lauf(art) {
        saat = 7;
        let kacheln = [], flaeche = 0;
        while (flaeche < 6500) {
            const r = groesse();
            kacheln.push({ r });
            flaeche += r * r;
        }
        const breite = Math.ceil(Math.sqrt(flaeche));
        const lay = new M.MondrianLayout(breite);
        for (const k of kacheln)
            k.sq = lay.place(k.r);
        let bewegt = 0, packungen = 0, lochSumme = 0;
        let lay2 = lay;
        for (let runde = 0; runde < 150; runde++) {
            const lay = lay2;
            const bleiben = [];
            let weg = 0;
            for (const k of kacheln) {
                if (zufall() < 0.02 + 0.06 * (k.sq.y / breite)) {
                    lay.remove(k.sq);
                    weg += k.r * k.r;
                } else {
                    bleiben.push(k);
                }
            }
            kacheln = bleiben;
            let dazu = 0;
            while (dazu < weg) {
                const r = groesse();
                kacheln.push({ r, sq: lay.place(r) });
                dazu += r * r;
            }
            if (art === "schwerkraft" || art === "beides")
                bewegt += lay.gravity(kacheln);
            else if (art === "streng")
                bewegt += streng(lay, kacheln);
            // Wie `BlockTiles.lueckenSchliessen`: ab einem Prozent der Flaeche
            // stabil neu packen
            if (art === "beides" && lay.enclosedHoles() > breite * breite * 0.01) {
                const vorher = kacheln.map(k => k.sq);
                lay2 = M.repackStable(breite, kacheln);
                bewegt += kacheln.filter((k, i) => k.sq.x !== vorher[i].x || k.sq.y !== vorher[i].y).length;
                packungen++;
            }
            lochSumme += lay2.enclosedHoles();
        }
        const lay_ = lay2;
        const frisch = new M.MondrianLayout(breite);
        for (const k of kacheln)
            frisch.place(k.r);
        return {
            eingeschlossen: eingeschlossen(lay_, breite),
            imMittel: Math.round(lochSumme / 150),
            frischGepackt: eingeschlossen(frisch, breite),
            bewegt,
            packungen,
            zeilenUeberRaster: lay_.height() - breite,
        };
    }

    for (const art of ["ohne", "schwerkraft", "streng", "beides"])
        console.log(art.padEnd(12), JSON.stringify(lauf(art)));
});
