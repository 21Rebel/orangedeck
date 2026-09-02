// Waehrungen an einer Stelle.
//
// mempool.space liefert sieben Kurse in derselben Nachricht mit -- es kostet
// also nichts, alle anzubieten. Welche gezeigt wird, steht in den
// Einstellungen; hier stehen nur Zeichen, Namen und das Umrechnen.
.pragma library

var CURRENCIES = [
    { "k": "eur", "l": "Euro", "z": "€" },
    { "k": "usd", "l": "Dollar", "z": "$" },
    { "k": "gbp", "l": "Pfund", "z": "£" },
    { "k": "chf", "l": "Franken", "z": "CHF" },
    { "k": "cad", "l": "kan. Dollar", "z": "CA$" },
    { "k": "aud", "l": "aust. Dollar", "z": "A$" },
    { "k": "jpy", "l": "Yen", "z": "¥" }
];

function symbol(cur) {
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (CURRENCIES[i].k === cur)
            return CURRENCIES[i].z;
    }
    return "€";
}

function label(cur) {
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (CURRENCIES[i].k === cur)
            return CURRENCIES[i].l;
    }
    return cur;
}

// Der Kurs in der gewaehlten Waehrung. Fehlt sie, wird der Reihe nach
// ausgewichen -- lieber eine andere Waehrung als ein Strich.
function rate(price, cur) {
    if (!price)
        return 0;
    if (price[cur])
        return price[cur];
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (price[CURRENCIES[i].k])
            return price[CURRENCIES[i].k];
    }
    return 0;
}

// Welche Waehrung tatsaechlich benutzt wird -- fuer die Beschriftung
function actual(price, cur) {
    if (!price)
        return cur;
    if (price[cur])
        return cur;
    for (var i = 0; i < CURRENCIES.length; i++) {
        if (price[CURRENCIES[i].k])
            return CURRENCIES[i].k;
    }
    return cur;
}

function group(n) {
    if (n === undefined || n === null || isNaN(n))
        return "–";
    var t = String(Math.round(n)), out = "", c = 0;
    for (var i = t.length - 1; i >= 0; i--) {
        out = t[i] + out;
        if (++c % 3 === 0 && i > 0)
            out = "." + out;
    }
    return out;
}

// Satoshi -> Betrag in der gewaehlten Waehrung, mit Zeichen
function fiat(sats, price, cur) {
    var r = rate(price, cur);
    if (!r || !sats)
        return "";
    var v = sats / 1e8 * r;
    var z = symbol(actual(price, cur));
    if (v >= 1e9)
        return "≈ " + (v / 1e9).toFixed(2).replace(".", ",") + " Mrd " + z;
    if (v >= 1e6)
        return "≈ " + Math.round(v / 1e6) + " Mio " + z;
    return "≈ " + group(v) + " " + z;
}

// Der Kurs selbst, also der Preis eines ganzen Bitcoin
function price1(price, cur) {
    var r = rate(price, cur);
    return r ? group(r) + " " + symbol(actual(price, cur)) : "–";
}
