// Rollen mit der Tastatur: Bild auf/ab, Pos1, Ende.
//
// **Warum es das gibt.** Mining, Explorer, Uhr und Einstellungen sind
// laenger als ein kleines Fenster, und gerollt wurde bis zum 16.09.2026 nur
// mit Maus oder Finger. In der Pruef-VM (kein Rad) blieb der untere Teil der
// Seiten deshalb ungeprueft, und am Rechner ohne Maus unerreichbar -- am
// selben Tag lag die RBF-Tafel des Explorers in Xvfb unter der Fensterkante.
.pragma library

// `wie`: "ab", "auf", "anfang", "ende". Eine Seite ist 90 % der Hoehe, damit
// eine Zeile vom vorigen Bild stehen bleibt und man nicht den Faden verliert.
function rollen(f, wie) {
    if (!f)
        return false;
    var min = f.originY - f.topMargin;
    var max = Math.max(min, f.originY + f.contentHeight + f.bottomMargin - f.height);
    var y = f.contentY;
    if (wie === "anfang")
        y = min;
    else if (wie === "ende")
        y = max;
    else
        y += (wie === "ab" ? 1 : -1) * f.height * 0.9;
    y = Math.max(min, Math.min(max, y));
    if (y === f.contentY)
        return false;
    f.cancelFlick();
    f.contentY = y;
    return true;
}
