# Entwuerfe fuers Anwendungssymbol

Stand 05.09.2026. Hier liegt, was zur Auswahl stand, samt der Begruendung --
damit die Entscheidung spaeter nachvollziehbar ist und nicht neu ausgedacht
werden muss.

**Warum im Repo und nicht im Kratzverzeichnis:** genau dort lagen sie zuerst,
und genau dort waren an diesem Tag schon `vm.py`s Pfade und die
VM-Datentraeger verschwunden. Was man wieder ansehen koennen will, gehoert
neben den Quelltext.

## Die drei Pruefungen

Ein Symbol muss alle drei bestehen; die Kontaktbogen zeigen sie
nebeneinander:

1. **Gross** -- wie es gemeint ist.
2. **Bei 44 Pixeln** -- so steht es im Starter. Feine Muster zerfallen hier
   zu Textur.
3. **Einfarbig** -- Androids eingefaerbte Symbole ab 13 und kleine
   Windows-Groessen. Formen, die sich beruehren, verschmelzen zu einem Fleck.

## Was zur Auswahl stand

| Datei | Gedanke | Befund |
|---|---|---|
| `1-block-fein.svg` | der Block, fein gepackt | bei 44 px nur noch Textur |
| `2-blockuhr.svg` | Bitcoin als Uhr, die in Bloecken schlaegt | beste Silhouette, sieht aber nach Stopp-Taste aus |
| `3-halde.svg` | der Mempool als Halde (das bisherige Zeichen) | klein generisch, drei Kloetzchen |
| `4-deck.svg` | der Name selbst, gestapelte Blaetter | huebsch, sagt nichts ueber Bitcoin |
| `5-block-grob.svg` | Block mit weniger, groesseren Kacheln | besser, aber einfarbig verschmolzen |
| `6-ring-mosaik.svg` | Ring plus Mosaik statt vollem Quadrat | nimmt die Stopp-Taste weg |
| `A-flaeche.svg` | Block, echte Fugen, kein Rahmen | **empfohlen** |
| `B-rahmen.svg` | derselbe Block mit Rahmen | Rahmen liest sich als Fenster oder Tabelle |
| `C-fuellt-sich.svg` | die Packung mit Leserichtung | ehrlichstes Bild, schwaechster Umriss |

## Der Handgriff, der den Unterschied macht

In A, B und C wird die Fuge **vom Rechteck abgezogen**, nicht zwischen die
Rechtecke gelegt:

    x + luecke/2, breite - luecke

Dadurch ist sie bei jeder Groesse gleich breit. Genau daran ist
`5-block-grob.svg` einfarbig gescheitert: dort lagen die Kacheln aneinander
und wurden zu einer weissen Masse.

## Kontaktbogen

- `blatt-1-vier-gedanken.png` -- die vier Grundgedanken
- `blatt-2-nachgeschaerft.png` -- die beiden Nachschaerfungen dagegen
- `blatt-3-block-fassungen.png` -- A, B, C in der Block-Richtung
- `A-flaeche-512.png` -- die empfohlene Fassung einzeln

## Was folgt, wenn eine gewaehlt ist

Ein Master-SVG, alles andere daraus abgeleitet. Heute gibt es genau **eine**
Symboldatei (`app/icons/store._21rebel.orangedeck.svg`), und fuer Windows und
macOS noch gar keine -- billiger als jetzt wird ein Wechsel nie.

    Flatpak/Linux   das Master-SVG
    Android         adaptive Ikone (Vorder-/Hintergrund), monochrome Ebene,
                    Dichten mdpi bis xxxhdpi
    Windows         .ico mit 16/32/48/256
    macOS           .icns
    Verknuepfungen  Feed, Uhr, Explorer in derselben Sprache
