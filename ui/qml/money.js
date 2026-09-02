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

// **Kein Formatieren hier.** Zahlen schreibt `strings.js`, denn die
// Schreibweise haengt an der Sprache und nicht an der Waehrung. Ein
// `.import` von dort waere der naheliegende Weg gewesen -- er traegt aber
// nicht: eine `.pragma library` kann kein anderes Skript einbinden, das
// Laden scheitert stumm ("Script ... unavailable"). Also andersherum: hier
// nur Kurs und Zeichen, formatiert wird beim Aufrufer.
