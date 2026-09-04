// Schriftfamilien an einer Stelle.
//
// Bisher stand ueberall `font.family: "monospace"` bzw. `"sans-serif"`. Das
// sind **fontconfig-Namen**: unter Linux loest fontconfig sie auf die vom
// Benutzer eingestellte Standardschrift auf, unter Windows und macOS gibt es
// sie nicht. Dort faellt Qt auf irgendeine Schrift zurueck -- an einer
// Monospace-Stelle womoeglich auf eine proportionale, und dann stehen Hashes
// und Betraege nicht mehr untereinander.
//
// `font.families` waere der naheliegende Weg, **gibt es in QML aber nicht**:
// die Wertetyp-`font` kennt nur `family` (geprueft mit Qt 6.11.2, die
// Zuweisung wird mit "Cannot assign to non-existent property" abgelehnt).
// Also wird hier ausgewaehlt statt aufgezaehlt.
//
// Unter Linux bleibt es beim generischen Namen -- dort aendert sich nichts,
// es bleibt die eingestellte Standardschrift. Nur auf Windows und macOS wird
// die erste tatsaechlich vorhandene Schrift aus der Liste genommen.
.pragma library

var _kandidaten = {
    "mono": ["Menlo", "SF Mono", "Consolas", "Cascadia Mono", "Roboto Mono",
             "DejaVu Sans Mono", "Liberation Mono", "Courier New"],
    "sans": ["Helvetica Neue", "Segoe UI", "Roboto", "Noto Sans",
             "DejaVu Sans", "Liberation Sans", "Arial"],
    "serif": ["Times New Roman", "Georgia", "DejaVu Serif", "Liberation Serif"]
};

var _generisch = { "mono": "monospace", "sans": "sans-serif", "serif": "serif" };

// Einmal ausgerechnet, dann gemerkt: `Qt.fontFamilies()` liest die ganze
// Schriftdatenbank, und das gehoert nicht in eine Bindung, die bei jeder
// Zeile neu rechnet.
var _gemerkt = {};

function _waehle(art) {
    if (_gemerkt[art] !== undefined)
        return _gemerkt[art];
    var name = _generisch[art];
    var os = (typeof Qt !== "undefined" && Qt.platform) ? Qt.platform.os : "";
    if (os === "windows" || os === "osx") {
        var da = Qt.fontFamilies();
        var liste = _kandidaten[art];
        for (var i = 0; i < liste.length; i++) {
            if (da.indexOf(liste[i]) >= 0) {
                name = liste[i];
                break;
            }
        }
    }
    _gemerkt[art] = name;
    return name;
}

function mono() {
    return _waehle("mono");
}

function sans() {
    return _waehle("sans");
}

function serif() {
    return _waehle("serif");
}

// Fuer `ctx.font` auf einer Leinwand: dort gilt die CSS-Kurzschreibweise.
// Ein Name mit Leerzeichen gehoert dort in Anfuehrungszeichen, ein
// generischer ausdruecklich **nicht** -- in Anfuehrungszeichen waere er ein
// gesuchter Schriftname statt einer Gattung, und dann findet Qt ihn nicht.
function _css(name) {
    return name.indexOf(" ") >= 0 ? '"' + name + '"' : name;
}

function monoCss() {
    return _css(_waehle("mono"));
}

function sansCss() {
    return _css(_waehle("sans"));
}
