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
                       "help": "Alles fließt auf einen einzigen Ausgang, ohne Rückgeld — typisch beim Leeren einer Adresse oder Wallet." },
    "inscription":   { "label": "Inschrift",       "color": "#e0578f",
                       "help": "Trägt Daten im Zeugnisteil (Witness) — Ordinals und Verwandtes. Die Daten zahlen dort weniger Gebühr als in einem OP_RETURN." }
};

// --- Deutung aus den `flags` von mempool.space ---------------------------
//
// Die Kachelgrafik kennt keine Ein- und Ausgaenge, nur die Kurzform. Darin
// steckt aber ein Bitfeld, das mempool.space selbst berechnet. Die Bitlage ist
// aus `frontend/src/app/shared/filters.utils.ts` (TransactionFlags) uebernommen
// und am 02.09.2026 an echten Daten gegengeprueft: eine Transaktion mit
// gesetztem Bit 24 hatte tatsaechlich einen OP_RETURN-Ausgang, eine ohne nicht.
var FLAG = {
    "rbf": 0, "no_rbf": 1, "v1": 2, "v2": 3, "v3": 4, "nonstandard": 5,
    "p2pk": 8, "p2ms": 9, "p2pkh": 10, "p2sh": 11, "p2wpkh": 12, "p2wsh": 13, "p2tr": 14,
    "cpfp_parent": 16, "cpfp_child": 17, "replacement": 18, "acceleration": 19,
    "op_return": 24, "fake_pubkey": 25, "inscription": 26, "fake_scripthash": 27, "annex": 28,
    "coinjoin": 32, "consolidation": 33, "batch_payout": 34
};

// Vorsicht: `>>` rechnet in JavaScript mit 32 Bit, die Flags reichen bis 2^44.
// Also durch Zweierpotenzen teilen statt schieben.
function hasFlag(flags, name) {
    var b = FLAG[name];
    if (b === undefined || !flags)
        return false;
    return Math.floor(flags / Math.pow(2, b)) % 2 === 1;
}

// Reihenfolge der Arten in der Kachelgrafik. Der Daemon legt genau diese
// Ziffer je Kachel ab -- **beide Listen muessen gleich bleiben.**
var KINDS = ["payment", "consolidation", "batch", "coinjoin",
             "data", "inscription", "coinbase", "sweep"];

function kindAt(i) {
    return KINDS[i] || "payment";
}

// Aus dem Bitfeld die Art bestimmen. Die Reihenfolge ist die Rangfolge:
// was seltener und aussagekraeftiger ist, geht vor.
function fromFlags(flags, isCoinbase) {
    if (isCoinbase)
        return "coinbase";
    if (hasFlag(flags, "coinjoin"))
        return "coinjoin";
    if (hasFlag(flags, "inscription"))
        return "inscription";
    if (hasFlag(flags, "op_return"))
        return "data";
    if (hasFlag(flags, "consolidation"))
        return "consolidation";
    if (hasFlag(flags, "batch_payout"))
        return "batch";
    return "payment";
}

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
