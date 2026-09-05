# Helligkeitsvarianten des vollen Blocks mit Rahmen

Sechs Fassungen derselben Packung (`I-voll-rahmen`), nur die Helligkeit der
Kacheln unterscheidet sie.

**Die Toene sind nicht erfunden.** `hclToCss()` aus `ui/qml/colors.js` ist
fuer die Erzeugung nachgebaut; der Farbton steht fest auf ORANGE
(`h = 0.181`), variiert wird allein die Helligkeit `l` um den Wert der
Anwendung (`0.472`). Jeder Ton stammt damit aus derselben Reihe, aus der auch
die Kacheln auf dem Schirm kommen.

| Datei | Regel | Befund |
|---|---|---|
| `v1-flach.svg` | ein Ton fuer alle | ruhig, aber leblos |
| `v2-nach-groesse.svg` | gross hell, klein dunkel | klare Rangfolge, klein sehr gut lesbar |
| `v3-umgekehrt.svg` | gross dunkel, klein hell | die grosse Kachel wird klein zum Loch |
| `v4-diagonal.svg` | Verlauf ueber die Flaeche | schoene Tiefe, klein wie v2 |
| `v5-streuung.svg` | ohne Bezug zur Groesse | **am lebendigsten und am ehrlichsten** |
| `v6-alter.svg` | oben hell, unten dunkel | ruhig, erinnert an die Alterspalette |

## Warum v5 die ehrlichste ist

In der Anwendung sagt die Farbe einer Kachel **nichts ueber ihre Groesse**:
sie zeigt Alter, Gebuehr oder Art. Eine Helligkeit, die der Groesse folgt
(v2, v4), ist ein gestalterischer Kunstgriff, den das Programm so nie zeigt.
v5 streut unabhaengig -- genau wie die Gebuehren.

Der Einwand dagegen: v5 ist klein etwas unruhiger als v2. Wer Lesbarkeit
ueber Wahrhaftigkeit stellt, nimmt v2.
