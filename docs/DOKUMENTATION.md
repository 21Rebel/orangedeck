# Bitcoin Feed — Live-Mempool-Ansicht (Bitfeed-Nachbau)

Nachbau der Ansicht von [bitfeed.live](https://bitfeed.live): der zuletzt
gefundene Block in der Mitte, der Mempool als Halde unten, neue Transaktionen
fallen von oben hinein.

## Aufbau

| Teil | Ort | Zweck |
|---|---|---|
| Feed-Daemon | `~/.local/bin/btcfeed` | haengt am WebSocket von mempool.space, schreibt den Zustand |
| Zustand | `$XDG_RUNTIME_DIR/btcfeed/state.json` | ~7 kB, alle 0,4 s neu geschrieben — **tmpfs**, nicht die SSD |
| Sperre | `$XDG_RUNTIME_DIR/btcfeed/btcfeed.lock` | `flock`, es laeuft immer nur **eine** Instanz |
| Grafik | `~/.local/share/btcfeed/qml/` | `FeedState`, `FeedCanvas`, `FeedPanel` — reines QtQuick |
| Packung | `~/.local/share/btcfeed/qml/mondrian.js` | Portierung des Mondrian-Layouts aus bitfeed |
| Farben | `~/.local/share/btcfeed/qml/colors.js` | HCL-Farbmodell aus bitfeed, nach sRGB gerechnet |
| Blockdaten | `$XDG_RUNTIME_DIR/btcfeed/block.json` | Kacheln des letzten Blocks, ~10 kB, nur bei Blockwechsel |
| DMS-Plugin | `~/.config/DankMaterialShell/plugins/BitcoinFeed/` | Leisten-Pille, Control-Center-Kachel, Desktop-Widget, Daemon |
| Eigenes Fenster | `~/.config/quickshell/BitcoinFeedApp/` | eigenstaendige Quickshell-Konfiguration |
| Fensterstarter | `~/.local/bin/btcfeed-window` | holt ein offenes Fenster nach vorn statt ein zweites zu oeffnen |
| Dashboard-Tab | `~/.local/bin/btcfeed-dashtab` | legt die DMS-Ueberlagerung an, die den Tab einhaengt |

Die drei QML-Dateien liegen **einmal** unter `~/.local/share/btcfeed/qml/` und
sind in Plugin- und App-Verzeichnis hineinsymlinkt. Eine Aenderung wirkt damit
ueberall.

## Bedienung

- **Leistenpille** (rechts neben der RAM-Anzeige): Linksklick oeffnet das
  Popout, Rechtsklick oeffnet direkt das eigene Fenster.
- **Popout**: das Symbol oben rechts (`open_in_new`) oeffnet die grosse Ansicht.
- **Control-Center**: Kachel "Bitcoin", aufklappbar.
- **Desktop-Widget**: Instanz `bitcoinFeed-1`. Verschieben/Groesse aendern im
  Bearbeitungsmodus (Knopf unten rechts am Bildschirm).
  Ein-/Ausschalten: `dms ipc call desktopWidget toggleEnabled bitcoinFeed-1`
- **Eigenes Fenster**: `btcfeed-window`, oder ueber den Starter "Bitcoin Feed".
  Tasten im Fenster: `c` Farbe (Alter/Gebuehr), `s` Groesse (Wert/vBytes),
  `i` Blockangaben, `l` Legende. Die Auswahl steht in
  `~/.local/state/btcfeed/view.json`.
- **Einstellungen** der DMS-Oberflaechen: Einstellungen -> Plugins ->
  Bitcoin Feed (Farbe, Groesse, Blockangaben, Legende, Deckkraft,
  Kachelgroesse).

## Die Mechanik, so wie im Original

Alles Folgende ist aus dem Quelltext von
[bitfeed](https://github.com/bitfeed-project/bitfeed) uebernommen (MIT, mononaut),
nicht nachempfunden.

**Kachelgroesse** (`client/src/utils/misc.js`, `logTxSize`):

    Kantenlaenge = ceil(log10(Ausgabewert in sat)) - 5,  begrenzt auf 1..5

Jede Rasterstufe steht also fuer den zehnfachen Wert -- genau die Legende der
Seite: 1 = < ₿ 0,01, 2 = < ₿ 0,1, 3 = < ₿ 1, 4 = < ₿ 10, 5 = < ₿ 100.
Im vByte-Modus stattdessen `ceil(sqrt(vbytes / 256))`.

**Anordnung** (`TxMondrianPoolScene.js`, nachgebaut in `mondrian.js`): das
Raster waechst nach oben, jede Transaktion kommt an die **erste freie Stelle von
unten links**, an die ihr Quadrat passt. Daraus entsteht die typische Anordnung
-- grosse Quadrate verstreut zwischen dicht gepackten kleinen.

Die Buchhaltung darunter ist bewusst anders geloest als im Original. Bitfeed
fuehrt eine Liste freier Slots `{x, y, r}`; das ist schnell, gibt beim Entfernen
einer Kachel aber nicht die ganze Flaeche zurueck. Nachgemessen sinkt die Dichte
dabei von 96 % auf 90 % und die Zahl der Loecher waechst unaufhaltsam. Bitfeed
stoert das nicht, weil dort Kacheln praktisch nie entfernt werden -- diese
Ansicht schichtet dagegen laufend um. `mondrian.js` fuehrt deshalb eine **exakte
Belegungskarte**: eine Zelle ist belegt oder frei, mehr nicht.

**Abstand und Groesse** (`TxPoolScene.resize`): `unitWidth = max(4, Breite/250)`,
`unitPadding = max(1, Breite/1000)`. Der Abstand ist ein **fester Pixelwert**,
kein Anteil der Kachelgroesse -- deshalb sind die Luecken ueberall gleich breit.
Die Groesse ist hier allerdings **fest** statt an der Fensterbreite haengend:
4 px Kachel, 1 px Abstand -- genau das Bild, das bitfeed bei rund tausend Pixeln
Breite zeigt. Zieht man das Fenster breiter, passen mehr Spalten hinein, die
Kacheln bleiben gleich. Ueber die Einstellung "Kachelgroesse" laesst sich das
skalieren.

**Aufteilung der Flaeche** (`TxPoolScene.resize` und `TxController.resize`):

    heightLimit   = Hoehe / 4        (bei Breite <= 620: / 4,5)
    blockAreaSize = min(Breite * 0,75, Hoehe / 2,5)

Die Halde ist also auf **ein Viertel der Fensterhoehe** gedeckelt und reicht nie
weiter ins Bild. Die gestrichelte Linie mit der Zaehlung sitzt auf ihrer
**Oberkante** und wandert mit dem Fuellstand (im Original `mempoolScreenHeight`).

**Farben** (`utils/color.js`, `models/BitcoinTx.js`), in HCL mit
`hcl(h * 360, 78.225, l * 150)`:

- *nach Alter* (Voreinstellung): frisch eingetroffen orange `#f7941d`, nach
  60 Sekunden blau `#00f1ca`. Bestaetigte Bloecke sind durchgehend orange.
- *nach Gebuehr*: tuerkis bis violett ueber `log2(sat/vB)` von 2 bis 128.
  Coinbase und gebuehrenfreie Transaktionen sind orange.

**Der Block in der Mitte** ist die echte Transaktionsliste des gefundenen
Blocks von `mempool.space/api/v1/block/<hash>/summary`, mit demselben Layout
gepackt. Gespeichert werden pro Transaktion nur zwei Ziffern (Kantenlaenge und
Gebuehrenklasse) -- aus 700 kB Antwort werden so 8 kB in `block.json`. Die
Reihenfolge ist die des Blocks, die Anordnung damit die echte.

**Die gestrichelte Linie** markiert die Oberkante des Mempool-Bereichs; der
Abstand zwischen ihr und der Halde ist die Luft bis zur vollen Halde.

**Was bei uns anders ist als im Original:** die Halde enthaelt nur die
Transaktionen, die seit dem Start eingetroffen sind -- die oeffentliche
Schnittstelle liefert keinen Bestand, nur den Zulauf (etwa fuenf pro Sekunde).
Nach dem Start dauert es deshalb rund **eine Viertelstunde**, bis die Halde
voll ist. Danach bleibt sie es, weil unten genauso viel herausfaellt wie oben
ankommt.

Es wurde einmal versucht, die Halde mit Platzhaltern nach der echten
Groessenverteilung vorzufuellen. Das ist wieder raus: die Platzhalter waren das
Einzige, was **nicht** von oben hereinfiel, und sie hatten keine Angaben fuer
den Tooltip. Ein eigener Node wuerde den echten Mempool-Inhalt liefern; ueber
die oeffentliche API kommt er nicht.

## Daten

Kein eigener Node noetig — alles kommt vom oeffentlichen WebSocket
`wss://mempool.space/api/v1/ws`. Abonniert werden nur `blocks`, `stats` und
`mempool-blocks`; das sind rund **4 kB/s** (~14 MB pro Stunde).

Bewusst **nicht** abonniert: `track-mempool`. Das liefert vollstaendige
Transaktionsobjekte und allein ~250 kB/s.

Faellt der WebSocket aus, schaltet `btcfeed` selbsttaetig auf REST-Polling um
(gaenger, aber die Ansicht lebt weiter) und versucht den WebSocket mit
wachsender Wartezeit erneut.

## Stolperfallen, die Zeit gekostet haben

1. **Leistenpille**: Die Pille darf **kein** `StyledRect` mit eigener Breite
   sein — DMS setzt Hintergrund und Groesse selbst. Mit eigener Breite ueberlappt
   sie die Nachbarwidgets. Richtig ist ein blosses `Row { ... }`.
2. **Widget-ID**: In `barConfigs[].rightWidgets` heisst der Eintrag schlicht
   `bitcoinFeed`, in `controlCenterWidgets` dagegen `plugin_bitcoinFeed`.
   Zwei verschiedene Konventionen im selben Programm.
3. **Dashboard-Tab braucht einen Umweg**: `Modules/DankDash/DankDashPopout.qml`
   hat die fuenf Tabs fest verdrahtet, es gibt dort keinen Plugin-Haken. Statt
   in `/usr/share` zu schreiben (Root noetig, beim Paketupdate weg) legt
   `btcfeed-dashtab` unter `~/.config/quickshell/dms-custom` eine
   **Ueberlagerung aus Symlinks** an; nur drei Dateien sind echte Kopien
   (`SettingsData.qml`, `DankDashPopout.qml`, `DMSShellIPC.qml`). Gestartet wird
   ueber ein systemd-Drop-in mit `dms run -c <pfad>`. DMS-Updates fliessen durch
   die Symlinks weiter; aendern sich die drei gepatchten Dateien, einmal
   `btcfeed-dashtab` aufrufen (`--check` sagt, ob noetig, `--remove` macht es
   rueckgaengig).
4. **Desktop-Widget** braucht einen Eintrag in `desktopWidgetInstances`
   (`{id, widgetType, enabled, config}`) — die IPC-Befehle `desktopWidget enable`
   arbeiten nur auf bereits vorhandenen Instanzen. Die Standardgroesse kommt aus
   `defaultWidth`/`defaultHeight` am Widget selbst.
5. **`qs -p <dir>` startet beliebig viele Instanzen** desselben Fensters. Daher
   der Umweg ueber `btcfeed-window`.
6. **Fuellstand**: `MondrianLayout.height()` zaehlt *angelegte* Zeilen, nicht
   belegte. Einmal angelegte Zeilen bleiben stehen, auch wenn alles daraus
   entfernt wurde. Fuer die Regelung der Haldenhoehe braucht es
   `max(sq.y + sq.r)` ueber die tatsaechlich vorhandenen Kacheln.
7. **Rechenlast**: die Halde einfach dreissigmal pro Sekunde neu zu zeichnen
   kostete 21 % CPU. Drei Massnahmen bringen es auf ~9 %: eigene Leinwand fuer
   den Block (aendert sich nur alle zehn Minuten), fallende Quadrate als echte
   `Rectangle` statt auf einer Leinwand (spart das Vollbild-Loeschen), und die
   Halde hoechstens fuenfmal pro Sekunde neu zeichnen. Kacheln werden ausserdem
   nach Farbe gebuendelt gezeichnet, das spart tausende Zustandswechsel.
8. **JavaScript-Dateien** muessen genau wie die QML-Dateien in *jedes*
   Verbraucherverzeichnis symlinkt werden; `import "mondrian.js"` sucht nur
   neben der QML-Datei.
9. **Wo abgeraeumt wird, entscheidet ueber das ganze Bild.** Der Regler muss
   staendig Kacheln entfernen, weil laufend neue eintreffen. Ueber 6000
   Umschichtungen nachgemessen (`mtest3.js`-Muster: je eine Ankunft, je ein
   Abgang):

   | Auswahl der entfernten Kachel | Loecher im Inneren nach 2000 / 6000 Schritten |
   |---|---|
   | zufaellig | 9,9 % / **16,8 %** -- waechst weiter |
   | die aelteste | 5,1 % / 4,2 % |
   | die **oberste** | 1,6 % / **0,6 %** -- wird besser |

   Nur von oben abraeumen laesst keine Loecher im Inneren entstehen, und die
   Halde wird mit der Zeit sogar dichter, weil neue Kacheln die Luecken von
   unten wieder auffuellen. Frisch Eingetroffene (juenger als 8 s) werden dabei
   verschont, sonst verschwinden sie gleich wieder.
10. **Fuellstandsregelung, zweimal falsch gemacht.** Erst ueber
   `layout.height()` -- das zaehlt angelegte, nicht belegte Zeilen. Dann ueber
   die hoechste Kachel -- das schaukelt auf: bleibt nach dem Abraeumen eine
   einzelne Kachel oben stehen, haelt der Regler die Halde weiter fuer voll und
   raeumt sie leer, bis nur noch ein paar schwebende Quadrate uebrig sind.
   Richtig ist die **belegte Flaeche** (Summe der r², inkrementell mitgezaehlt)
   geteilt durch die Rasterbreite. Beim Schrumpfen ausserdem die aeltesten
   Kacheln entfernen, nicht die zuletzt gefallenen -- sonst verschwinden gerade
   die frisch eingetroffenen wieder.
11. **Regen statt Stoesse.** mempool.space schickt die neuen Transaktionen
   einmal pro Sekunde als Paket von etwa fuenf Stueck (nachgemessen: 156 in
   30 s, alle kommen an -- es geht nichts verloren). Fallen die gleichzeitig
   los, sieht es aus, als wuerden welche fehlen. `drainQueue()` verteilt sie
   deshalb ueber das Intervall.
12. **Ein Rechteck, das seine Groesse aus einer zentrierten Spalte zieht,
   bleibt leer.** Der Tooltip war unsichtbar, weil `Column { anchors.centerIn:
   parent }` im Rechteck stand, waehrend das Rechteck seine Breite aus
   `tipCol.implicitWidth` nahm. QML bricht die gegenseitige Abhaengigkeit auf
   und liefert 0 -- ohne Fehlermeldung. Loesung: die Spalte auf feste x/y setzen
   und ihre Groesse aus `childrenRect` nehmen.
13. **Virtueller Mauszeiger zum Testen**: `evdev.UInput` mit `REL_X/REL_Y`
   (`/dev/uinput` ist hier schreibbar). Wichtig: die Bildschirmaufnahme muss
   laufen, **solange das Geraet offen ist** -- beim Schliessen verlaesst der
   Zeiger das Fenster und der Tooltip verschwindet.
14. **Rechenlast, zweiter Durchgang.** Im Vollbild (2536 x 1552) lagen 16 % CPU
   an. Der teure Teil war nicht das Zeichnen, sondern dass dreissigmal pro
   Sekunde die **ganze Halde** (4000 Kacheln) durchlaufen wurde, um die
   Handvoll noch fallender zu finden. Mit einer eigenen Liste `flying` sind es
   10 %. Das Loeschen nur des Haldenbereichs statt der ganzen Leinwand bringt
   noch einmal einen Prozentpunkt.
15. **`str.replace("", x)` schreibt `x` zwischen jedes Zeichen.** Beim Umbau
   wurde ein Textabschnitt ueber `s[s.index(a):s.index(b)]` ausgeschnitten --
   stand `b` im Text **vor** `a`, kam ein leerer Suchstring heraus und die
   Datei blaehte sich von 34 kB auf 32 MB auf. Zurueckholen liess sie sich,
   indem der eingefuegte Block wieder entfernt wurde (`replace(block, "")`) --
   der Originaltext steckt ja unveraendert dazwischen. Bei solchen Schnitten
   vorher pruefen, dass `index(a) < index(b)`.
16. **Ungleiche Luecken durch gebrochene Pixelwerte.** Im Blockraster ist die
   Rasterweite `Blockseite / Zeilen` und damit fast nie ganzzahlig. Zeichnet man
   die Kacheln direkt darauf, faellt mal ein Pixel mehr auf die Luecke und mal
   weniger -- ueber tausende Kacheln ergibt das ein deutliches Karomuster. Die
   Loesung ist, nicht Position und Groesse zu runden, sondern die **Kanten**:
   `x0 = round(bx + q.x * g)`, `x1 = round(bx + (q.x + q.r) * g)`. Weil zwei
   benachbarte Kacheln denselben gerundeten Wert benutzen, ist die Luecke
   ueberall exakt `2 * pad`. Der feine Punktraster-Eindruck im unteren
   Blockdrittel bleibt -- der ist im Original genauso, weil Kachel und Abstand
   dort beide ein Viertel der Rasterweite sind.
17. **Nicht wegoptimieren, was die Anzeige noch braucht.** Die Umstellung, nur
   noch ueber die Liste der fallenden Kacheln zu laufen, liess gelandete
   Kacheln fuer ein bis zwei Bilder verschwinden: sie fielen aus der
   Animationsebene, bevor die Halde neu gezeichnet war. Sie muessen dort
   bleiben, bis `poolCanvas` ihr `pending` zurueckgesetzt hat.
18. **Schreiblast**: der Zustand wird zweieinhalbmal pro Sekunde neu geschrieben.
   Unter `~/.local/state` waeren das rund 3 GB pro Tag auf die SSD, deshalb
   liegt er in `$XDG_RUNTIME_DIR` (tmpfs). Nur `view.json` -- die
   Tasteneinstellungen des eigenen Fensters -- gehoert dauerhaft nach
   `~/.local/state/btcfeed/`.

## Das Foerderband

Die Halde arbeitet wie im Original als Foerderband (`TxPoolScene.doScroll` +
`clearOffscreenTxs`): die Oberkante ist auf eine feste Hoehe gepinnt, neue
Transaktionen landen oben, und wenn es zu hoch wird, schiebt sich die unterste
Zeile aus dem Bild. **Deshalb gibt es im Inneren keine Loecher.** Ueber 40 000
Kacheln nachgemessen bleibt die Dichte bei 100 %.

Es wird also nie mitten aus der Halde entfernt -- das war der Fehler, der die
Halde zunehmend ausloecherte (siehe Stolperfalle 9).

## Blockfund

Nachgebaut aus `TxController.addBlock` und `TxBlockScene.prepareTx`:

1. Ein Teil der Halde (etwa der Anteil, den ein Block am Mempool hat) leuchtet
   **weiss** auf und verschwindet daraus. Das Weiss ist `ice()` aus
   `TxBlockScene.js`: dieselbe Farbe, aber Helligkeit auf 1 -- ergibt `#ffffff`.
2. Diese Kacheln pulsieren kurz (Kantenlaenge +25 %, hin und zurueck), zeitlich
   versetzt. Das Blockfeld ist waehrenddessen **leer**.
3. Nach drei Sekunden fliegen **alle** Transaktionen des Blocks an ihren Platz.
   Die sichtbaren kommen aus der Halde, alle uebrigen ziehen von **unter der
   Bildkante** herauf -- der Mempool ist groesser als die sichtbare Halde. Im
   Original ist das `prepareTxOnScreen` fuer noch nicht gezeichnete
   Transaktionen.
4. Zusammengesetzt wird der Block in **Weiss**; erst wenn alles liegt, faerbt er
   sich in einem Uebergang orange (`iceRamp()` in `colors.js`).

Das sind bis zu 6000 Kacheln gleichzeitig -- zu viele fuer die Rechteck-Ebene,
deshalb hat die Blockanimation eine eigene Leinwand, die nur waehrend der
Animation zeichnet. Sie kostet fuer die vier Sekunden rund 40 % CPU.

Zum Pruefen ohne zehn Minuten Wartezeit: Taste `b` im eigenen Fenster.

## Tooltip

Beim Ueberfahren einer Kachel -- in der **Halde wie im Block** -- erscheinen
TxID, Groesse, Gebuehrenrate, Gebuehr und Gesamtwert; die Kachel selbst faerbt
sich dabei blaugruen (im Original `hoverOn()` mit der Farbe `bluegreen`), damit
klar ist, wozu die Angaben gehoeren. Ein- und Ausgaenge stehen nicht im
Datenstrom und werden bei Bedarf einzeln ueber `/api/tx/<txid>` nachgeladen
(mit Zwischenspeicher).

Fuer den Block liegen die Angaben in `block.json` (Feld `txs`, dieselbe
Reihenfolge wie die Kacheln). Das macht die Datei rund 500 kB gross -- sie wird
aber nur einmal je Block geschrieben und gelesen. Getroffen wird ueber eine
Zellenkarte des Blockrasters, nicht durch Durchsuchen aller Kacheln.

Jede Kachel der Halde hat einen Datensatz -- es gibt keine Platzhalter mehr
(siehe oben).

## Pruefen

```
btcfeed --print                     # Zustand einmalig per REST holen und zeigen
dms ipc call bitcoinFeed status     # was das Plugin gerade liest
dms ipc call bitcoinFeed restart    # Feed neu starten
```


## Stolperfalle: QML liest keine lokalen Dateien per XMLHttpRequest

Qt sperrt das hinter `QML_XHR_ALLOW_FILE_READ=1`. Ohne die Variable bleibt der
Aufruf auf **readyState 1** stehen — kein Fehler, keine Meldung, er kommt
einfach nie bei DONE an. Am 01.09.2026 mit Qt 6.11.2 nachgemessen; mit gesetzter
Variable erreicht derselbe Aufruf readyState 4.

Deshalb liest `FeedState.qml` seinen Zustand nicht aus `state.json`, sondern
ueber die Loopback-Schnittstelle des Daemons (`http://127.0.0.1:21021/state`).
Ueber HTTP gibt es den Sonderfall nicht, und dieselbe Datei laeuft damit
unveraendert unter Android.

Nebenbei zwei Fallen beim Nachmessen selbst:
- `/usr/bin/qml` ist hier **Qt 5.15**. Versionslose Importe sind Qt-6-Syntax,
  deshalb meldet es nur "Did not load any objects". Der Qt6-Laeufer liegt unter
  `/usr/lib/qt6/bin/qml`.
- Dessen `console.log`/`console.warn` erreicht die Konsole in dieser Umgebung
  nicht. Ergebnisse lassen sich zuverlaessig ueber `Qt.exit(<code>)` heraus-
  tragen.


## Bewusste Abweichung: der Block liegt enger als im Original

`TxBlockScene.js` rechnet:

    this.gridSize    = width / this.blockWidth
    this.unitPadding = this.gridSize / 4
    this.unitWidth   = this.gridSize - (this.unitPadding * 2)

Die Kachel ist dort also **genau halb so breit wie die Rasterzelle**. Bei den
kleinen Rasterweiten, die hier vorkommen, wirkt der Block dadurch als
Punktraster statt als Flaeche -- bei `g = 6` waren das 2 px Kachel auf 4 px
Luecke, also 33 % Fuellung, waehrend die Halde daneben 4 px auf 2 px zeigt
(67 %).

`blockPadDivisor` steht deshalb auf **8** statt 4:

     g   alt: Kachel/Luecke  Fuellung      neu: Kachel/Luecke  Fuellung
     6          2 px / 4 px       33%             4 px / 2 px       67%
     7          3 px / 4 px       43%             5 px / 2 px       71%
     8          4 px / 4 px       50%             6 px / 2 px       75%
    12          6 px / 6 px       50%             8 px / 4 px       67%
    24        12 px / 12 px       50%            18 px / 6 px       75%

Damit hat der Block dieselbe Dichte wie die Halde. Der Wert ist eine
Eigenschaft und laesst sich spaeter in die Einstellungen heben.

### Und die Untergrenze dazu: ganzzahliges Raster erst ab 2 px je Zelle

`blockUnit` rundet die Rasterweite ab, damit die Kacheln quadratisch bleiben.
Bei einem **kleinen** Block kippt das ins Gegenteil: ist `blockSide / rows`
kleiner als 2, wird `floor(g)` gleich 1 -- die Kachel fuellt die Zelle
vollstaendig aus, die Luecke ist **null**, und der Block wird eine
geschlossene Flaeche.

Am 01.09.2026 genau so im Dashboard-Tab passiert. Mit den echten Blockdaten
nachgerechnet (Block 965052: 5.291 Kacheln, Gewicht 10.920, also 105
Rasterzellen Breite):

    Blockseite   g roh   floor(g)   Kachel   Luecke
           120    1,14          1        1        0   <- geschlossene Flaeche
           160    1,52          1        1        0
           200    1,90          1        1        0
           210    2,00          2        1        1   <- ab hier in Ordnung
           460    4,38          4        2        2

Deshalb: **`g < 2` bleibt gebrochen.** Dann springen die gerundeten Kanten
zwischen 1 und 2 px und ergeben wieder eine Textur. Ein Karomuster droht dort
nicht, weil bei dieser Groesse ohnehin alle Kacheln 1 px gross sind.


## Stolperfalle: `transform` skaliert nicht die Lage eines Items

`transform` wirkt im **eigenen** Koordinatensystem eines Items. Eine `Scale`
erfasst dadurch Breite und Hoehe, **nicht** aber `x` und `y` -- die beschreiben
ja die Lage im Elternitem und liegen ausserhalb der Transformation.

Beim Zoom fiel das zuerst nicht auf, weil `flyLayer` den Elternbereich ausfuellt
und damit ohnehin bei (0,0) sitzt -- dort ist der Unterschied null. `hoverMark`
dagegen hat eine eigene Lage, und die Einfaerbung landete im Zoom neben der
Kachel statt darauf.

Richtig ist ein Behaelter bei (0,0), der die Sicht traegt (`sceneLayer`);
alles darin rechnet in Szenenkoordinaten und wird korrekt mitskaliert.

## Untergrund fuer die Textangaben (`FrostedPanel.qml`)

Im Zoom liegen grosse helle Kachelflaechen direkt hinter der Schrift, und die
Angaben am Rand gehen unter. `FrostedPanel` legt sich hinter ein beliebiges
Item, uebernimmt dessen Lage und Groesse samt Rand und faerbt ein; ist
`backdropSource` gesetzt, wird der Ausschnitt dahinter zusaetzlich
weichgezeichnet (`ShaderEffectSource` + `MultiEffect`).

**Gemessene Kosten** (eigenstaendige Anwendung, 1100x800, je 8 s):

    ohne Weichzeichnung                       9,6 %
    Weichzeichnung mit live: true            14,4 %
    Weichzeichnung auf 5 Hz gedrosselt       12,5 %

Der Untergrund muss nicht sechzigmal pro Sekunde neu abgegriffen werden -- die
Halde selbst zeichnet nur fuenfmal (Timer mit 200 ms). Deshalb `live: false`
plus ein Timer, der `scheduleUpdate()` im selben Takt ruft, dazu ein sofortiges
Nachziehen bei Lage- oder Groessenaenderung. Der Rest der Mehrkosten ist der
Weichzeichner selbst, der pro Bild laeuft.

Abschaltbar ueber `frostedBlur` in `FeedPanel.qml`; die Einfaerbung allein
macht bereits lesbar. Kleiner Schoenheitsfehler: `clip` ist in QML immer
rechteckig, an den abgerundeten Ecken erscheint deshalb weichgezeichneter
Inhalt ohne Einfaerbung. Bei 6 px Radius kaum sichtbar; sauber loesen liesse
sich das ueber `maskEnabled` am MultiEffect.


## Stolperfalle: eine neue QML-Datei muss an **vier** Orten ankommen

Die geteilten Bausteine liegen einmal unter `ui/qml/`, werden aber an vier
Stellen gebraucht:

    ~/.local/share/btcfeed/qml/                          (der eine echte Ort)
    ~/.config/DankMaterialShell/plugins/BitcoinFeed/     (Plugin)
    ~/.config/quickshell/BitcoinFeedApp/                 (eigenes Fenster)
    ~/.config/quickshell/dms-custom/Modules/DankDash/    (Dashboard-Tab)
    app/CMakeLists.txt                                   (eigenstaendige App)

Am 01.09.2026 kam `FrostedPanel.qml` dazu und landete ueberall ausser im
DankDash-Verzeichnis -- dessen Liste steht in `daemon/btcfeed-dashtab`, nicht in
`tools/install-links.sh`. Folge: `FeedPanel` liess sich dort nicht mehr laden
("FrostedPanel is not a type"), der Bitcoin-Tab scheiterte, und **das ganze
Dashboard liess sich nicht mehr oeffnen**. Im Journal stand der Grund
sauber drin -- die laufende Instanz meldete aber nichts mehr, weil der Fehler
beim Laden des Tabs auftrat, nicht im Betrieb.

**Behoben, indem beide Skripte die Liste nicht mehr fuehren**: `install-links.sh`
und `btcfeed-dashtab` lesen jetzt aus `ui/qml/`, was dort liegt. Einzig
`app/CMakeLists.txt` braucht den Eintrag weiterhin von Hand -- CMake muss die
Dateien zur Bauzeit kennen.

Nach einer neuen Datei also:

    tools/install-links.sh          # verteilt alles
    python3 daemon/btcfeed-dashtab  # baut die Ueberlagerung neu
    systemctl --user restart dms


## Stolperfalle: ohne `clip` regnet es ueber den ganzen Bildschirm

Fallende Kacheln starten **oberhalb** des Bereichs -- `fromY` ist negativ
(`-side - random * height * 0.5`). QML zeichnet Kinder ausserhalb der Grenzen
ihres Elternitems weiter, solange niemand beschneidet.

Im eigenen Fenster faellt das nicht auf, weil das Fenster selbst beschneidet.
Im **Dashboard-Popup** dagegen regnete es am 01.09.2026 ueber den ganzen
Bildschirm. Nirgends war `clip` gesetzt -- weder in `BitcoinTab.qml` noch in
`FeedPanel` oder `FeedCanvas`. Jetzt steht `clip: true` auf dem Wurzel-Item von
`FeedCanvas`; rechteckiges Beschneiden ist ein Scherentest und praktisch
kostenlos.

## Die Untergrenze der Blockdarstellung, und warum sie physisch ist

Ein Block mit 105 Rasterzellen Breite braucht **mindestens 210 px**, damit jede
Kachel ein Bildpunkt und jede Luecke ein Bildpunkt sein kann. Weniger geht
nicht -- ganze Zahlen unter zwei lassen keinen Platz fuer beides.

Der Dashboard-Tab ist 410 px hoch, und `blockSide = min(Breite * 0,72,
Hoehe / 2,5, poolTop * 0,86)` -- die **Hoehe bindet** und ergibt rund 156 px.
Dort sind knackige Einzelquadrate also nicht erreichbar, egal wie gerundet
wird:

    Blockseite   Zelle   Kachel   Luecke   Darstellung
           156    1,49     0,74     0,74   gebrochen + geglaettet
           195    1,86     0,93     0,93   gebrochen + geglaettet
           210    2,00     1,00     1,00   ganzzahlig, hart
           260    2,00     1,00     1,00   ganzzahlig, hart

Deshalb wird unter zwei Bildpunkten je Zelle **nicht gerundet und mit
Kantenglaettung gezeichnet** (`blockPad` liefert dort `g/4`, das Verhaeltnis des
Originals). So entsteht eine Textur statt harter Kleckse -- genau wie im
Original, das in WebGL ohnehin mit gebrochenen Groessen zeichnet. Ueberall
sonst bleibt die Grafik bewusst hart.

Wer im Dashboard echte Einzelquadrate will, muss dem Tab mehr Hoehe geben:
`implicitHeight` in `BitcoinTab.qml` (Vorlage in `daemon/btcfeed-dashtab`)
muesste von 410 auf rund 545 steigen, damit `Hoehe / 2,5` ueber 210 px kommt.


## Tooltip: Raeumen ueber den Abstand, nicht ueber das Verlassen

Zwischen zwei Kacheln liegt eine Luecke von wenigen Bildpunkten. Faellt der
Zeiger darauf, soll die letzte Angabe stehen bleiben statt zu flackern -- das
war der Grund, warum urspruenglich nur `onExited` geraeumt hat.

Im **Dashboard** faellt das auf die Fuesse: dort liegen grosse leere Bereiche
**innerhalb** der Flaeche (der Block fuellt sie nicht aus). Man verlaesst die
MouseArea also nie, und der Tooltip blieb stehen, bis der Zeiger das ganze
Popup verliess.

Massstab ist jetzt der **Abstand zur zuletzt getroffenen Kachel**, mit einer
Rasterzelle Nachsicht (`clearHoverIfAway`). Nachgerechnet an einer 4-px-Kachel
bei Rasterweite 6:

    auf der Kachel                     bleibt stehen
    2 px Luecke daneben                bleibt stehen
    6 px daneben (Rand der Nachsicht)  bleibt stehen
    12 px daneben                      raeumt
    leere Flaeche weit weg             raeumt

`onExited` bleibt als zweite Absicherung bestehen.


## Der Daemon als Benutzerdienst -- zwei Fallen dabei

`packaging/systemd/btcfeed.service`, eingerichtet von `tools/install-links.sh`.
Vorher lief btcfeed als loser Prozess: er starb mit der Sitzung, und nach einem
Absturz belebte ihn nur zufaellig der Waechter im DMS-Plugin.

**(1) `ProtectSystem=strict` macht auch `$XDG_RUNTIME_DIR` schreibgeschuetzt.**
btcfeed scheiterte schon an seiner Sperrdatei:

    OSError: [Errno 30] Read-only file system: '/run/user/1000/btcfeed/btcfeed.lock'

Richtig ist `RuntimeDirectory=btcfeed` -- systemd legt genau das Verzeichnis an,
das btcfeed ohnehin benutzt, und macht es beschreibbar.
`RuntimeDirectoryPreserve=restart` erhaelt es ueber einen Neustart hinweg, damit
`block.json` (rund 460 kB) nicht jedes Mal neu geholt wird.

**(2) `Restart=always` plus ein zweiter Verwalter ergibt eine Endlosschleife.**
btcfeed beendet sich **mit 0**, wenn schon eine Instanz die Sperre haelt
("btcfeed laeuft bereits"). Der Waechter im DMS-Plugin hatte parallel eine
eigene Instanz gestartet; der Dienst startete, fand die Sperre, beendete sich
sauber -- und systemd startete ihn wieder. 16 Runden in einer Minute.

Behoben an beiden Enden:
- `Restart=on-failure` statt `always`
- **Die Waechter starten jetzt den Dienst statt eines eigenen Prozesses.**
  `BitcoinFeedDaemon.qml` und `btcfeed-window` rufen
  `systemctl --user start btcfeed.service` und fallen nur dann auf das Programm
  zurueck, wenn die Unit nicht eingerichtet ist.

Gegengeprueft: nach einem `kill -9` auf den Hauptprozess kam der Dienst
selbstaendig zurueck (eine Instanz, ein Neustart, Daten sofort wieder da).

**Nebenbei:** `systemctl show -p MainPID --value` liefert waehrend eines
Neustarts `0`. Ein `kill -9 0` trifft dann die **ganze Prozessgruppe** --
also immer auf Plausibilitaet pruefen, bevor man die Zahl an `kill` gibt.


## BlockClock und Miner-Ansicht

Zwei zusaetzliche Ansichten in `ui/qml/`, umschaltbar mit 1/2/3; die Auswahl
merkt sich `Settings` (damit ein Tablet nach dem Einschalten gleich wieder als
BlockClock hochkommt). Beide importieren nur `QtQuick` und laufen damit auch
unter Android.

**`ClockView.qml`** -- Blockhoehe gross, dazu Gebuehr, Kurs, Mempool und
Hashrate, ein Fortschrittsbalken bis zur naechsten Schwierigkeitsanpassung, der
Halving-Abstand und eine Hashrate-Kurve ueber einen Monat. Vorbild ist der
unveroeffentlichte Zweig `display-mode` aus dem Fork (03.04.2023).

**`MinerView.qml`** -- Hashrate des eigenen Geraets und, als eigentliche Zahl
beim Solomining, die **beste Freigabe gegen die Netzschwierigkeit**. Angezeigt
als "1 zu N" statt als Prozentzahl mit acht Nullen. Dazu Temperatur, Leistung,
Freigaben, Laufzeit. Drei Zustaende: nicht eingetragen, nicht erreichbar, in
Betrieb -- der Miner ist meistens schlicht aus, das ist kein Fehler.

### Datenseite

`btcfeed` holt die langsamen Kennzahlen **in einem eigenen Faden**
(`run_extras`): die WebSocket-Schleife blockiert auf `ws.recv()`, dort haetten
HTTP-Abfragen den Feed bis zu 15 Sekunden angehalten.

    /v1/difficulty-adjustment      alle 5 Minuten
    /v1/mining/hashrate/1m         alle 5 Minuten -- 31 Messpunkte, 2,2 kB
                                   (/3d liefert nur drei, zu wenig fuer eine Kurve)
    <bitaxe>/api/system/info       alle 5 Sekunden, nur wenn eingetragen

Die Miner-Adresse steht in `~/.config/btcfeed/sources.json`:

    { "bitaxe": "http://192.168.1.42" }

`BTCFEED_BITAXE` in der Umgebung schlaegt die Datei. Ohne Eintrag passiert
nichts -- die Quelle ist damit abschaltbar wie alles andere. Die Datei ist
bewusst getrennt von `btcfeed.conf`, die den QSettings der Anwendung gehoert.

### qmllint: `pragma ComponentBehavior: Bound`

Beide Ansichten benutzen einen `Repeater`, dessen Delegat auf `root` zugreift.
Dafuer will Qt 6 die Zeile `pragma ComponentBehavior: Bound` -- und dann muss
auch `modelData` im Delegaten ausdruecklich angefordert werden
(`required property var modelData`, Zugriff ueber `parent.modelData`). Ohne
beides meckert `qmllint`, und die Bindung waere tatsaechlich nicht garantiert.
