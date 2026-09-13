// Die Ansichten des Programms -- **eine** Quelle.
//
// Vorher stand dieselbe Reihenfolge dreimal da: als Liste in
// `FeedTabs.tabViews`, als Tabelle in `FeedTabs.tabNamen` und ein drittes Mal
// von Hand in der Startansicht der Einstellungen. Zwei davon hielt ein
// Kommentar zusammen ("damit die beiden nicht auseinanderlaufen"), die dritte
// nichts -- und sie lief auseinander: die Startansicht kannte bis zuletzt nur
// Feed, Uhr, Miner, Explorer, weil Markt und Wallet spaeter dazukamen. Wer im
// Markt starten wollte, konnte es nicht einstellen.
//
// Das ist dasselbe Muster wie die Klemme auf 5 in `shell.qml`: **eine Grenze
// wandert nicht von selbst mit.** Eine achte Ansicht kommt hier in die
// Tabelle, und alle drei Stellen wissen davon.
//
// Reine Funktionen, kein Zustand -- wie `strings.js` und aus demselben Grund:
// dieselben Dateien laufen in der Anwendung, im Quickshell-Fenster und im
// DMS-Plugin, und ein QML-Singleton braucht ein `qmldir`, das nur das
// CMake-Modul erzeugt.
.pragma library

// Die Grundreihenfolge -- was ein Anwender vorfindet, der nichts umstellt.
//
//   id         die Zahl, an der die Ansicht ueberall haengt (auch `--view N`
//              und die Android-Verknuepfungen). **Nicht die Position.** Der
//              Markt kam als 6 dazu und steht trotzdem an fuenfter Stelle;
//              haetten wir umnumeriert, zeigten alle gemerkten Werte und alle
//              Verknuepfungen daneben.
//   name       Schluessel in `strings.js`
//   schalter   Einstellung, mit der sich der Reiter abschalten laesst.
//              Leer heisst: laesst sich nicht abschalten.
var ANSICHTEN = [
    { "id": 0, "name": "tab.feed",     "schalter": "showFeed"     },
    { "id": 1, "name": "tab.clock",    "schalter": "showClock"    },
    { "id": 2, "name": "tab.miner",    "schalter": "showMiner"    },
    { "id": 3, "name": "tab.explorer", "schalter": "showExplorer" },
    { "id": 6, "name": "tab.market",   "schalter": "showMarket"   },
    // Die Wallet haengt nicht an einem Reiter-Schalter, sondern an
    // `walletEnabled` -- dem Schalter mit der Warnung davor. Ein zweiter
    // daneben waere nur die Frage, welcher von beiden gilt.
    { "id": 4, "name": "tab.wallet",   "schalter": ""             },
    // **Die Einstellungen bleiben immer.** Sonst schaltet man den letzten
    // Reiter ab und kommt an keinen Schalter mehr heran.
    { "id": 5, "name": "tab.settings", "schalter": ""             }
];

var EINSTELLUNGEN = 5;

function eintrag(id) {
    var n = parseInt(id, 10);
    for (var i = 0; i < ANSICHTEN.length; i++) {
        if (ANSICHTEN[i].id === n)
            return ANSICHTEN[i];
    }
    return null;
}

// Uebersetzungsschluessel einer Ansicht. Unbekanntes gibt "" -- der Aufrufer
// zeigt dann nichts, statt eine Zahl anzuschreiben.
function name(id) {
    var e = eintrag(id);
    return e ? e.name : "";
}

function schalter(id) {
    var e = eintrag(id);
    return e ? e.schalter : "";
}

function alle() {
    var out = [];
    for (var i = 0; i < ANSICHTEN.length; i++)
        out.push(ANSICHTEN[i].id);
    return out;
}

// Die gespeicherte Reihenfolge auf die bekannte Menge abbilden.
//
// **Nachsichtig in beide Richtungen**, und zwar mit Absicht: Unbekanntes
// faellt weg (eine Ansicht, die es einmal gab, sperrt nichts), Fehlendes wird
// hinten angehaengt (eine Ansicht, die neu dazukommt, ist da -- ohne dass
// jemand seine gespeicherte Reihenfolge zuruecksetzen muss). Genau daran ist
// die Startansicht gescheitert.
//
// Kommt aus QSettings, sind die Eintraege Zeichenketten ("0", "1"); aus
// view.json Zahlen. `parseInt` in `eintrag` nimmt beides.
function ordnung(gespeichert) {
    var out = [];
    if (gespeichert && gespeichert.length) {
        for (var i = 0; i < gespeichert.length; i++) {
            var e = eintrag(gespeichert[i]);
            if (e && out.indexOf(e.id) < 0)
                out.push(e.id);
        }
    }
    for (var j = 0; j < ANSICHTEN.length; j++) {
        if (out.indexOf(ANSICHTEN[j].id) < 0)
            out.push(ANSICHTEN[j].id);
    }
    return out;
}

// Die Reiter, die wirklich dastehen.
//
//   gespeichert  die Reihenfolge des Anwenders (darf leer sein)
//   moeglich(id) kann diese Ansicht ueberhaupt etwas zeigen? Technik --
//                der Miner steht im Heimnetz, die Wallet-Ableitung und die
//                Kerzen des Marktes sind Rechenarbeit des Dienstes. Ein
//                Reiter, hinter dem nichts sein kann, ist schlimmer als
//                keiner.
//   an(schluessel) hat der Anwender ihn angelassen? Der Schalter kommt oben
//                drauf und kann nichts erzwingen.
//   mitEinstellungen  ob die Einstellungen ein Reiter sind (Vorgabe ja).
//                Die eigenstaendige Anwendung hat seit dem 13.09.2026 dafuer
//                ein Zahnrad -- am Telefon lag der Vollbildknopf auf dem
//                letzten Reiter.
function reiter(gespeichert, moeglich, an, mitEinstellungen) {
    var einst = mitEinstellungen !== false;
    var ord = ordnung(gespeichert);
    var out = [];
    for (var i = 0; i < ord.length; i++) {
        var e = eintrag(ord[i]);
        if (e.id === EINSTELLUNGEN && !einst)
            continue;
        if (!moeglich(e.id))
            continue;
        if (e.schalter.length && !an(e.schalter))
            continue;
        out.push(e.id);
    }
    // Der Deckel ueber allem: die Einstellungen bleiben erreichbar, was auch
    // immer `moeglich` und `an` melden -- als Reiter oder, wenn der Wirt es
    // so will, ueber sein Zahnrad.
    if (einst && out.indexOf(EINSTELLUNGEN) < 0)
        out.push(EINSTELLUNGEN);
    return out;
}
