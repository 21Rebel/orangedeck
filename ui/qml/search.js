// Erkennung, was der Benutzer eingegeben hat.
//
// `label` ist ein **Schluessel** in strings.js, kein Text. Bis 0.2.7 standen
// hier deutsche Woerter, und die erschienen rechts im Suchfeld auch unter
// englischer Oberflaeche ("Blockhöhe", "Transaktion").
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
        return { "kind": "blockheight", "label": "blockHeight", "value": lower, "arg": lower };
    }

    // Blockhash: 64 Hex, davon acht fuehrende Nullen
    if (/^0{8}[a-f0-9]{56}$/.test(lower)) {
        return { "kind": "blockhash", "label": "search.kind.blockhash", "value": lower, "arg": lower };
    }

    // Eingang: n:txid
    if (/^[0-9]+:[a-f0-9]{64}$/.test(lower)) {
        var pi = lower.split(":");
        return { "kind": "input", "label": "search.kind.input", "value": lower,
                 "arg": pi[1], "index": parseInt(pi[0], 10) };
    }

    // Ausgang: txid:n
    if (/^[a-f0-9]{64}:[0-9]+$/.test(lower)) {
        var po = lower.split(":");
        return { "kind": "output", "label": "search.kind.output", "value": lower,
                 "arg": po[0], "index": parseInt(po[1], 10) };
    }

    // Transaktion: 64 Hex ohne die Nullen vorn
    if (/^[a-f0-9]{64}$/.test(lower)) {
        return { "kind": "tx", "label": "transaction", "value": lower, "arg": lower };
    }

    // Adressen -- Gross- und Kleinschreibung zaehlt, deshalb `q` statt `lower`
    if (/^(bc1|tb1|bcrt1)[023456789acdefghjklmnpqrstuvwxyz]{6,87}$/i.test(q)) {
        return { "kind": "address", "label": "search.kind.segwit", "value": q, "arg": q };
    }
    if (/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/.test(q)) {
        return { "kind": "address", "label": "address", "value": q, "arg": q };
    }
    if (/^(xpub|ypub|zpub|vpub|upub)[a-km-zA-HJ-NP-Z1-9]{50,}$/.test(q)) {
        return { "kind": "xpub", "label": "search.kind.xpub", "value": q, "arg": q };
    }

    return null;
}

// Was die Eingabe sein *koennte*, waehrend noch getippt wird -- fuer den
// Hinweis rechts im Feld. `tr(schluessel, wert)` uebersetzt; die Bibliothek
// selbst kennt keine Sprache.
function hintFor(query, tr) {
    if (!query || !query.length)
        return tr("search.placeholder");
    var m = matchQuery(query);
    if (m)
        return tr(m.label);
    var q = String(query).trim();
    if (/^[0-9a-fA-F]+$/.test(q) && q.length < 64)
        return tr("search.moreChars", 64 - q.length);
    return tr("search.invalidHint");
}
