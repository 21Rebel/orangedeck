// Erkennung, was der Benutzer eingegeben hat.
//
// **Portierung aus bitfeed** (MIT, mononaut):
// upstream/bitfeed/client/src/utils/search.js, Funktion `matchQuery`.
// Uebernommen sind die Muster -- sie decken mehr Faelle ab, als man von Hand
// bedenkt, allen voran der Blockhash mit seinen acht fuehrenden Nullen und die
// beiden Formen `txid:n` (Ausgang) und `n:txid` (Eingang).
//
// Nicht uebernommen ist der Datenweg: bitfeed fragt seinen eigenen
// Elixir-Server, hier laeuft alles ueber den Daemon.
.pragma library

function matchQuery(query) {
    if (!query || !query.length)
        return null;

    var q = String(query).trim();
    var lower = q.toLowerCase();

    // Eine Zahl -- Blockhoehe
    var asInt = parseInt(lower, 10);
    if (!isNaN(asInt) && asInt >= 0 && String(asInt) === lower) {
        return { "kind": "blockheight", "label": "Blockhöhe", "value": lower, "arg": lower };
    }

    // Blockhash: 64 Hex, davon acht fuehrende Nullen
    if (/^0{8}[a-f0-9]{56}$/.test(lower)) {
        return { "kind": "blockhash", "label": "Blockhash", "value": lower, "arg": lower };
    }

    // Eingang: n:txid
    if (/^[0-9]+:[a-f0-9]{64}$/.test(lower)) {
        var pi = lower.split(":");
        return { "kind": "input", "label": "Transaktionseingang", "value": lower,
                 "arg": pi[1], "index": parseInt(pi[0], 10) };
    }

    // Ausgang: txid:n
    if (/^[a-f0-9]{64}:[0-9]+$/.test(lower)) {
        var po = lower.split(":");
        return { "kind": "output", "label": "Transaktionsausgang", "value": lower,
                 "arg": po[0], "index": parseInt(po[1], 10) };
    }

    // Transaktion: 64 Hex ohne die Nullen vorn
    if (/^[a-f0-9]{64}$/.test(lower)) {
        return { "kind": "tx", "label": "Transaktion", "value": lower, "arg": lower };
    }

    // Adressen -- Gross- und Kleinschreibung zaehlt, deshalb `q` statt `lower`
    if (/^(bc1|tb1|bcrt1)[023456789acdefghjklmnpqrstuvwxyz]{6,87}$/i.test(q)) {
        return { "kind": "address", "label": "Adresse (SegWit)", "value": q, "arg": q };
    }
    if (/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/.test(q)) {
        return { "kind": "address", "label": "Adresse", "value": q, "arg": q };
    }
    if (/^(xpub|ypub|zpub|vpub|upub)[a-km-zA-HJ-NP-Z1-9]{50,}$/.test(q)) {
        return { "kind": "xpub", "label": "Erweiterter öffentlicher Schlüssel", "value": q, "arg": q };
    }

    return null;
}

// Was die Eingabe sein *koennte*, waehrend noch getippt wird -- fuer den
// Hinweis unter dem Feld.
function hintFor(query) {
    if (!query || !query.length)
        return "Blockhöhe, Blockhash, TxID oder Adresse";
    var m = matchQuery(query);
    if (m)
        return m.label;
    var q = String(query).trim();
    if (/^[0-9a-fA-F]+$/.test(q) && q.length < 64)
        return "noch " + (64 - q.length) + " Zeichen bis zu einer TxID";
    return "keine gültige Eingabe";
}
