// Erkennung der Transaktionsart aus ihrer Struktur.
//
// Bitcoin kennt keine Typen -- was hier steht, ist eine **Deutung** anhand von
// Ein- und Ausgaengen. Sie ist nuetzlich, aber nie sicher: eine Wallet kann
// jedes Muster auch aus anderen Gruenden erzeugen. Deshalb nennt die Ansicht
// die Art und keine Gewissheit.
.pragma library

// Farben passend zum uebrigen Bild: warme Toene fuer alltaegliche Zahlungen,
// kuehle fuer Umschichtungen, ein eigener Ton fuer Datenablage.
var TYPES = {
    "payment":       { "label": "Zahlung",         "color": "#f7931a",
                       "help": "Ein bis zwei Eingänge, ein Ziel und meist ein Rückgeld — die alltägliche Überweisung." },
    "consolidation": { "label": "Konsolidierung",  "color": "#3fb3a3",
                       "help": "Viele Eingänge auf wenige Ausgänge: jemand räumt sein Guthaben zusammen, meist wenn die Gebühren niedrig sind." },
    "batch":         { "label": "Sammelzahlung",   "color": "#4a86d8",
                       "help": "Wenige Eingänge auf viele Ausgänge — Börsen und Pools zahlen so an viele Empfänger auf einmal." },
    "coinjoin":      { "label": "CoinJoin",        "color": "#c065c9",
                       "help": "Viele Beteiligte zahlen gemeinsam und erhalten gleich große Ausgänge zurück. Verwischt die Zuordnung, wer wem zahlt." },
    "data":          { "label": "Datenablage",     "color": "#8a7f9c",
                       "help": "Enthält einen OP_RETURN-Ausgang: hier wird nicht Geld bewegt, sondern etwas in die Kette geschrieben." },
    "coinbase":      { "label": "Blockbelohnung",  "color": "#d8b84a",
                       "help": "Die erste Transaktion eines Blocks — hier entstehen neue Bitcoin und die Gebühren des Blocks gehen an den Finder." },
    "sweep":         { "label": "Umschichtung",    "color": "#6f7fd0",
                       "help": "Alles fließt auf einen einzigen Ausgang, ohne Rückgeld — typisch beim Leeren einer Adresse oder Wallet." }
};

function classify(tx) {
    if (!tx)
        return null;
    var vin = tx.vin || [], vout = tx.vout || [];
    var nIn = vin.length, nOut = vout.length;

    if (nIn && vin[0] && vin[0].is_coinbase)
        return "coinbase";

    // Datenablage geht vor: sie ist eindeutig erkennbar
    for (var i = 0; i < nOut; i++) {
        if (vout[i] && vout[i].scriptpubkey_type === "op_return")
            return "data";
    }

    // Gleich grosse Ausgaenge zaehlen -- das Merkmal eines CoinJoin
    var counts = {}, best = 0;
    for (i = 0; i < nOut; i++) {
        var v = vout[i] ? vout[i].value : 0;
        counts[v] = (counts[v] || 0) + 1;
        if (counts[v] > best)
            best = counts[v];
    }
    if (nIn >= 5 && nOut >= 5 && best >= 3)
        return "coinjoin";

    if (nIn >= 5 && nOut <= 2)
        return "consolidation";
    if (nIn <= 2 && nOut >= 5)
        return "batch";
    // Umschichtung erst ab zwei Eingaengen -- eine Zahlung ohne Rueckgeld
    // (1 zu 1) ist keine Umschichtung, und die kommt haeufig vor.
    if (nOut === 1 && nIn >= 2)
        return "sweep";
    return "payment";
}

function info(kind) {
    return TYPES[kind] || TYPES["payment"];
}
