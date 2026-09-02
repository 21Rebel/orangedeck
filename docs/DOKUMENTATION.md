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

**`MinerView.qml`** -- **nicht auf ein Geraet festgelegt.** Gesamthashrate
ueber alle erreichbaren Geraete und, als eigentliche Zahl beim Solomining, die
**beste Freigabe gegen die Netzschwierigkeit**, angezeigt als "1 zu N" statt
als Prozentzahl mit acht Nullen. Darunter jedes Geraet einzeln mit Zustand,
Hashrate, Temperatur und Laufzeit. Drei Zustaende: nicht eingetragen, keines
erreichbar, in Betrieb -- die Geraete sind meistens schlicht aus, das ist kein
Fehler.

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


## Miner: zwei Protokollfamilien und eine Netzsuche

Der Daemon spricht zwei Familien und deckt damit praktisch alle ueblichen
Geraete ab. Beide Adapter liefern **denselben Satz Felder**, Hashrate immer in
H/s -- die Ansicht muss nichts ueber das Geraet wissen.

    axeos     HTTP, /api/system/info
              Bitaxe, NerdAxe und die uebrigen ESP-Miner-Abkoemmlinge (AxeOS).
              Meldet GH/s und die Bestleistung als Text ("1.23M").
    cgminer   TCP 4028, JSON-Befehl {"command":"summary"}
              Antminer, Avalon, Whatsminer und Nachbauten. Meldet MH/s, haengt
              ein Nullbyte an die Antwort und schliesst ohne Content-Length --
              also bis zum Verbindungsende lesen und hinten abschneiden.

### Suchen statt eintragen

Die Geraete haengen ueblicherweise im WLAN und bekommen ihre Adresse per DHCP;
ein fest eingetragener Wert haelt selten lange. Deshalb:

    btcfeed --discover-miners           auflisten
    btcfeed --discover-miners --write   in sources.json eintragen

Der Suchlauf geht ueber die eigenen /24-Netze und probiert je Adresse HTTP :80
und TCP :4028. Virtuelle Bruecken (`virbr`, `docker`, `br-`, `veth`, `tun`,
`tailscale`) bleiben draussen -- dort steht kein Miner.

**Der Dienst sucht nicht von selbst.** Ein Durchlauf ueber alle Adressen des
Netzes gehoert nicht in einen Hintergrunddienst; er passiert nur auf Zuruf.

### Am echten Geraet geprueft (01.09.2026)

Bitaxe Gamma 601, AxeOS v2.14.2 unter `http://192.168.100.9`:

    Hashrate     1060 GH/s geglaettet, 1048 im Moment, 1071 erwartet
    beste Freigabe 295.580.247  ->  1 zu 425.627
    Sitzungsbestwert 1.092.084, Pool-Schwierigkeit 8.192
    56,5 C, 16,8 W, Luefter 5927 U/min, Fehlerquote 6,6 %
    Netzschwierigkeit laut Geraet 125.807.076.547.197
      -- deckt sich exakt mit dem Wert von mempool.space

`btcfeed --discover-miners` fand es von selbst im WLAN.

Zwei Dinge dabei gelernt:

- **`bestDiff` kommt als Zahl**, nicht als Text mit Einheit wie erwartet.
  `parse_diff` nimmt beides.
- **Die Momentanrate schwankt um rund zehn Prozent.** Angezeigt wird deshalb
  `hashRate_10m`; die Momentanrate steht daneben. Ohne das springt die grosse
  Zahl staendig.
- **`stratumUser` enthaelt beim Solomining die Auszahlungsadresse.** Sie wird
  bewusst **nirgends** uebernommen -- weder in den Zustand noch in die Anzeige
  noch ins Protokoll. Vom Pool wird nur der Wirt gezeigt.

### Vorher gegen nachgestellte Geraete geprueft

Solange kein Miner erreichbar war, gegen nachgebaute Antworten (HTTP und TCP):

    AxeOS    1204,7 GH/s -> 1,20 TH/s, "1.23M" -> 1.230.000, Temp/Freigaben/Laufzeit
    cgminer  95.000.000 MH/s -> 95,00 TH/s, Best Share 123.456.789
    nicht erreichbar -> online=false, Fehler wird gemeldet

Danach die ganze Kette: nachgestelltes Geraet -> Daemon -> Loopback -> FeedState
-> MinerView, mit zwei Geraeten zugleich und richtiger Summe (96,17 TH/s).
**Gegen echte Geraete steht die Probe noch aus.**


## Miner: Verlauf, Bestenliste, Rechenwerke

Die Weboberflaeche des Geraets bleibt der Ort fuer **Einstellungen** -- hier
wird nur angezeigt. Ein Knopf oben rechts oeffnet sie
(`Qt.openUrlExternally`).

### Der Verlauf wird selbst mitgeschrieben

AxeOS hat zwar `/api/system/statistics`, aber die Aufzeichnung haengt an
`statsFrequency`; am Testgeraet stand die auf **0**, die Antwort war leer. Die
Kurve der Weboberflaeche baut sich der Browser selbst zusammen. Und die
cgminer-Schnittstelle kennt gar keinen Verlauf.

Deshalb schreibt der **Daemon** mit: 180 Punkte im Fuenfsekundentakt, also eine
Viertelstunde, je Geraet (`minerHistory` im Zustand). Gerundet abgelegt --
Hashrate in GH/s mit einer Stelle -- weil der Zustand zweieinhalbmal pro
Sekunde geschrieben wird. Das funktioniert bei **jedem** Geraetetyp gleich und
braucht am Geraet keine Einstellung.

`MinerChart.qml` zeichnet daraus Hashrate und Temperatur uebereinander, mit
zwei Achsen -- die Groessen haben nichts miteinander zu tun.

Gezeichnet werden **drei** Linien: der Momentanwert der Hashrate duenn und
blass, der Zehnminutenwert kraeftig darueber (beide orange, gemeinsame Achse),
und die Temperatur hell auf eigener Achse rechts.

Das war nicht immer so. Zuerst stand nur der geglaettete Wert da -- und der ist
so ruhig, dass er wie eine Temperaturkurve aussieht, waehrend die Temperatur
auf einer Achse von nur gut einem Grad durch die 0,1-Grad-Stufen des Sensors
zackig wirkt. Genau andersherum als in der Weboberflaeche des Geraets, wo der
**Momentanwert** gezeichnet wird. Nachgemessen:

    Hashrate (geglaettet)  Spanne 1063,5 bis 1073,5 GH/s, Sprung 0,19 ->  2 % der Spanne
    Temperatur             Spanne   55,1 bis   56,2 C,    Sprung 0,10 ->  9 % der Spanne
    Hashrate (Moment)      156-mal groessere Spanne als der geglaettete Wert

**Die Achsenbeschriftung traegt die Farbe ihrer Kurve** (Hashrate orange links,
Temperatur hell rechts). Grau beschriftet liess sich nicht erkennen, welche
Linie zu welcher Achse gehoert -- eine Legende waere zusaetzlicher Platz fuer
dieselbe Auskunft.

Die Hashrate wird **ab 1025 GH/s in TH/s** angezeigt (`teraFrom`). Bewusst
etwas ueber 1000, damit die Einheit bei einem Geraet, das um die Marke herum
schwankt, nicht staendig hin und her springt.

### Bestenliste

`/api/system/scoreboard` liefert die 20 hoechsten Freigaben mit `difficulty`,
`ntime` und `nonce`. Alle 30 Sekunden geholt (sie aendert sich kaum), in der
Ansicht die besten fuenf, jeweils mit dem Abstand zur Netzschwierigkeit als
"1 zu N". Nur AxeOS hat so etwas; bei anderen Geraeten bleibt der Abschnitt weg.

### Rechenwerke (Hash-Domaenen) -- und warum sie geglaettet werden muessen

Der BM1370 ist **ein** Chip (`asicCount: 1`), intern aber in **vier
Hash-Domaenen** geteilt (`hashDomains: 4`). Die 2040 kleinen Kerne verteilen
sich darauf, jede Domaene mit eigener Spannungs- und Taktversorgung. AxeOS
misst je Domaene, wie viele Nonces von dort kommen -- das ist eine Diagnose:
faellt eine Domaene **dauerhaft** ab, ist dieser Teil des Chips instabil.

**Die Einzelmessungen rauschen erheblich.** Am 01.09.2026 ueber zwoelf
Messungen im Sekundentakt nachgemessen:

    Domaene 0   Mittel 260,4   Spanne 225,5 bis 304,9   Streuung 27,3 GH/s
    Domaene 1   Mittel 274,3   Spanne 221,3 bis 317,8   Streuung 24,5 GH/s
    Domaene 2   Mittel 275,7   Spanne 240,4 bis 320,1   Streuung 32,3 GH/s
    Domaene 3   Mittel 263,9   Spanne 231,9 bis 343,6   Streuung 31,7 GH/s

Ueber 10 % Streuung auf den Mittelwert. Ein einzelnes Bild gaukelt damit
Unterschiede vor, die keine sind -- und die erste Fassung dieser Ansicht
skalierte die Balken auf den groessten Wert des Augenblicks, stellte also
Rauschen als Defekt dar.

Der Daemon mittelt deshalb ueber `DOMAIN_SMOOTH` Messungen (12, also eine
Minute) und liefert `domainsAvg`; die Ansicht zeigt diesen Wert und schreibt
den Zeitraum dazu. Wirkung am Geraet gemessen: Spreizung **17,4 % momentan
gegen 9,8 % geglaettet** -- und die 9,8 % decken sich mit den echten
Mittelwertunterschieden, sind also Struktur statt Rauschen.

### Platz

Kurve und Bestenliste erscheinen erst ab 330 bzw. 460 Bildpunkten Hoehe -- im
Dashboard-Tab ist dafuer kein Platz, dort bleiben die Kennzahlen.


## Ansichten und Tabs

`ViewTabs.qml` ist der Umschalter zwischen Feed, BlockClock und Miner --
bewusst ein eigenes Bauteil, weil ihn **beide** Oberflaechen benutzen: das
eigene Fenster (`app/qml/Main.qml`) und der Dashboard-Tab (Vorlage in
`daemon/btcfeed-dashtab`). Nur `import QtQuick`, laeuft also auch unter
Android. Die Beruehrungsflaeche ist hoeher als die Schrift -- mit dem Finger
trifft man sonst schlecht.

Im Fenster geht das Umschalten weiterhin auch mit 1/2/3; die Auswahl merkt sich
`Settings`, im Dashboard `SettingsData.setPluginSetting`.


## Legende hinter einem "i"-Knopf (`InfoPopup.qml`)

Erklaerungen gehoeren an **einen** Ort, nicht in die Flaeche. `InfoPopup`
legt sich ueber eine Ansicht, zeigt oben rechts einen "i"-Knopf und blendet
darunter ein Feld mit Eintraegen ein -- jeweils Ueberschrift, Text und
optional ein Farbstrich, der die Zuordnung zur Kurve herstellt (kraeftig fuer
den geglaetteten Wert, duenn und blass fuer den Momentanwert).

Das Item faengt Eingaben nur dort ab, wo der Knopf sitzt; ist das Feld offen,
schliesst ein Klick daneben es wieder.

**Falle:** ein Geschwister kann sich **nicht** per Anker an den Knopf haengen
(`Cannot anchor to an item that isn't a parent or sibling`) -- der Knopf ist
ein Kind des InfoPopup. Deshalb gibt es `buttonWidth`, ueber das sich weitere
Knoepfe per `anchors.rightMargin` danebensetzen.

## Rollbare Ansichten

Der Inhalt der Miner-Ansicht wird hoeher als die Flaeche, sobald Kurve,
Rechenwerke und Bestenliste zusammenkommen -- im Dashboard-Tab (410 px) stand
er ueber den Rand hinaus.

`ClockView` und `MinerView` legen ihren Inhalt deshalb in eine `Flickable` mit
`clip: true`. Der Trick fuers Verhalten steckt in einer Zeile:

    y: Math.max(0, (flick.height - implicitHeight) / 2)

Passt alles, steht der Inhalt mittig wie zuvor; passt es nicht, beginnt er oben
und laesst sich schieben. Rechts erscheint ein schmaler Balken, aber nur
solange es etwas zu rollen gibt.

Damit muessen Kurve und Bestenliste nicht mehr wegen Platzmangel wegbleiben --
die Schwellen (`roomForChart`, `roomForBoard`) halten nur noch das ganz kleine
Desktop-Widget frei.


## Explorer

Vierte Ansicht (`ExplorerView.qml`), Taste 4 oder der Tab. Suchen, Einzelheiten
ansehen, dem Weg des Geldes folgen -- und ein Klick auf eine Kachel im Feed
fuehrt direkt hierher (`FeedCanvas` meldet `txActivated`, `FeedPanel` reicht es
weiter).

### Die Datenquelle steckt an **einer** Stelle

Die Oberflaeche fragt **nicht** selbst bei mempool.space an, sondern beim
Daemon: `/lookup/<art>/<wert>`. Drei Gruende:

1. Nur eine Stelle weiss, woher die Daten kommen -- der Wechsel auf einen
   eigenen Node ist `{"host": "mempool.eigenes.netz", "scheme": "http"}` in
   `sources.json`, und Feed, Kennzahlen und Explorer folgen alle.
2. Das Tablet spricht ohnehin nur mit dem Daemon.
3. Ein Zwischenspeicher (45 s, fuer Unbestaetigtes 8 s) verhindert, dass jeder
   Klick eine Anfrage nach draussen ausloest.

**Kein freier Durchgriff:** nur acht Formen werden weitergereicht (`tx`,
`txstatus`, `outspends`, `block`, `blocktxids`, `blockheight`, `address`,
`addresstxs`), jede gegen ein eigenes Muster geprueft. Alles andere kommt mit
400 zurueck.

### Was gezeigt wird

    Transaktion   Status, Groesse, Gewicht, Gebuehr und Rate; Ein- und
                  Ausgaenge nebeneinander. Jeder Eingang bringt Adresse und
                  Betrag mit (`prevout`) und fuehrt per Klick zur
                  Vorgaengertransaktion -- der Weg rueckwaerts. Jeder Ausgang
                  zeigt, ob er schon ausgegeben wurde (`outspends`), und fuehrt
                  entweder zur ausgebenden Transaktion oder zur Adresse.
    Block         Hoehe, Hash, Zeit, Anzahl, Groesse; vor und zurueck.
    Adresse       Guthaben, Anzahl, empfangen und gesendet, letzte
                  Transaktionen.

Ein Zurueck-Knopf fuehrt den Weg wieder heraus (`trail`).

### Zwei Fallen

- **`data` ist in QML belegt.** Es ist die Standard-Eigenschaft, in der die
  Kindelemente liegen; eine eigene Eigenschaft dieses Namens bringt den Baum
  durcheinander. Die Antwort heisst deshalb `result`.
- **`parent.parent.parent.x` in Repeater-Delegaten ist bruechig.** Sobald ein
  Element dazwischenkommt, zeigt die Kette woandershin. Die Bauteile haben
  jetzt Namen (`txBox`, `blockBox`, `addrBox`) und werden direkt angesprochen.


## Der Fluss einer Transaktion (`TxFlow.qml`)

Eingaenge links, Ausgaenge rechts, die Hoehe jedes Bandes im Verhaeltnis zum
Betrag. Aufbau nach dem Vorbild von mempool.space
(`frontend/src/app/components/tx-bowtie-graph/tx-bowtie-graph.component.ts`,
am 01.09.2026 nachgelesen). Drei Dinge daraus uebernommen:

**Keine Verjuengung -- die Taille entsteht aus den Luecken.** Ein Band behaelt
seine Dicke von links nach rechts. Am Rand stehen die Baender mit Abstand, im
Strang lueckenlos; **genau die Luecken fehlen dort, und darum ist er schmaler**.
Aussen breit, in der Mitte schmal, rechts wieder auffaechernd -- ohne dass ein
einziger Betrag verfaelscht wird.

Zwei Irrwege dahin, beide lehrreich:

1. *Taille durch Skalieren* (`waistFrac`, jedes Band im Strang auf 62 %). Sah
   geschwungen aus, stellte aber jeden Betrag kleiner dar, als er ist.
2. *Baender im Strang auf volle Hoehe hochskalieren.* Dann ist die Mitte so
   hoch wie die Raender -- und alles bleibt ein Rechteck.

Richtig ist: **ein Band hat ueberall dieselbe Dicke.** Der Massstab ist fuer
beide Seiten derselbe. Am Rand kommen nur die Luecken dazu, die den Rest
auffuellen. Bei **einem** Band gibt es keine Luecke und damit keine Taille; da
ist auch nichts zusammenzufuehren.

### Der Strang ist ein fester Wert, keine Quote

Der wichtigste Kniff aus dem Original, und der schwerste zu sehen. Dort steht:

    combinedWeight = min(maxCombinedWeight /* 100 */, floor((txWidth - 2*midWidth) / 6))
    innerTop       = height / 2 - combinedWeight / 2
    spacing        = max(4, (height - visibleWeight) / gaps)
    maxStrands     = 24   // "number of inputs/outputs to keep fully on-screen"

`combinedWeight` ist eine **Pixelzahl**, die unabhaengig von der Bandzahl
gleich bleibt -- die Zeichenflaeche waechst stattdessen mit der Zahl der
Baender. Dadurch bleibt der Strang immer gleich dick, waehrend sich die Luecken
am Rand immer weiter aufziehen: satt und ruhig bei einem Eingang, weit
aufgefaechert bei zwanzig.

Eine feste **Quote** kann das nicht. Bei ihr ist das Verhaeltnis von Luecke zu
Band immer `(1 - q) / q`, egal wie viele Baender es sind -- die Rundung waere
bei zwei wie bei zwanzig dieselbe. Genau daran hing der erste Versuch mit
`waistTarget`.

Mit festem Strang (`trunkPx`) und mitwachsender Flaeche, nachgerechnet:

    Baender   Flaeche   Strang   Band     Luecke   Verhaeltnis
       1        91 px    40 px   40,3 px    --         --
       2        91 px    40 px   20,2 px   34,3 px    1,7
       5       137 px    40 px    8,1 px   17,9 px    2,2
      10       221 px    40 px    4,0 px   15,7 px    3,9
      24       338 px    48 px    2,0 px   10,0 px    5,0

Das Original kommt bei 24 Baendern auf 5,2 -- dieselbe Groessenordnung.

`bandLimit` begrenzt zusaetzlich auf 24 Baender (im Original `maxStrands`),
gekoppelt an die Hoehe: unter etwa sieben Bildpunkten je Band bleibt fuer die
Luecken nichts mehr uebrig.

### Die Mitte muss exakt treffen

Zwei Fehler, die dort einen sichtbaren Versatz erzeugten:

1. **Massstab je Seite getrennt.** Ergab bei 1 Eingang und 3 Ausgaengen links
   18..182 px, rechts 41..159 px -- **23 px Versatz** und eine Stufe in der
   Mitte. Beide Seiten tragen denselben Gesamtbetrag (die Gebuehr zaehlt als
   Ausgang) und brauchen deshalb denselben Massstab.
2. **Die Mindestdicke treibt die Summen auseinander.** Bei 400 Eingaengen
   kommen 61 Baender zu je gut zwei Bildpunkten zusammen und sprengen den
   Strang, waehrend die Gegenseite mit einem Ausgang weit darunter bleibt --
   wieder 22 px. `fit()` bringt daher beide Seiten zum Schluss auf denselben
   Strang.

Nachgerechnet ueber 1/1, 1/2, 3/2, 30/1, 400/1 und 60/60: **Versatz 0,00 px**.

### Schwung, Verlauf, Pfeilspitze

**`swing`** (0,78) steuert die Kontrollpunkte der Bezierkurven: sie liegen bei
`x0 + d` und `x1 - d` mit `d = (x1 - x0) * swing`. Ab 0,5 ueberschneiden sie
sich, wodurch die Baender flacher ansetzen und in der Mitte steiler laufen.
Nachgemessen an 60 px Hoehenunterschied auf 100 px Breite:

    swing   Steigung in der Mitte
     0,50           1,98x
     0,65           2,74x
     0,78           3,88x
     0,90           5,33x

**Der Farbuebergang** sass frueher in der Strangflaeche. Die gibt es nicht mehr,
also tragen ihn die Baender selbst: die Eingaenge laufen zur Mitte hin in
`midColor` (das Mittel aus beiden Farben), die Ausgaenge setzen dort an. Ohne
das bricht die Farbe in der Mitte hart um.

**Die Pfeilspitze** laeuft innerhalb der Bandbreite zusammen. Ein Ueberstand an
den Ecken -- der erste Versuch hatte einen -- sieht nach Fehler aus, nicht nach
Absicht.

Ihre Laenge haengt an der **Banddicke** (`tipFor`, `tipRatio`). Eine feste
Laenge ergibt bei dicken Baendern eine spitze Nadel und bei duennen einen
stumpfen Klotz:

    Banddicke   feste Laenge   an die Dicke gekoppelt   Winkel fest / gekoppelt
        2 px       10,5 px            3,0 px                11° / 37°
        4 px       10,5 px            3,0 px                22° / 67°
       10 px       10,5 px            4,2 px                51° / 100°
       25 px       10,5 px           10,5 px               100° / 100°
      110 px       10,5 px           10,5 px               158° / 158°

Alle Baender enden an derselben Stelle; nur die Spitze ist unterschiedlich
lang, dazwischen ein gerades Stueck.

### Rand, Anschluesse

Oben und unten bleibt Platz (`padY`), damit der Fluss frei liegt statt am
Bildrand zu kleben. An beiden Enden ein gerades Anschlussstueck (`connector`),
dazwischen die Kurve. **Kein Rechteck in der Mitte** -- Ein- und Ausgaenge
treffen sich in einem Punkt; eine gezeichnete Strangflaeche erzeugte dort sonst
eine harte senkrechte Kante. Jeder Ausgang endet in einer Pfeilspitze
(`arrowLen`).

**Die Gebuehr ist ein Ausgang wie jeder andere**, nur in eigener Farbe und an
erster Stelle (im Original `voutWithFee.unshift({ type: 'fee', value: tx.fee })`).
Damit geht die Rechnung von selbst auf -- Summe links gleich Summe rechts --
und der frueher noetige Sonderweg mit eigenem Streifen faellt weg.

**Mindestdicke**, damit kleine Betraege nicht verschwinden (`minBand`; im
Original `minWeight = 2` mit `Math.max(minWeight - 1, weight) + 1`). Eine
uebliche Gebuehr ist ein Bruchteil eines Promille: 385 sat von 646.354 sind
0,06 %, auf 220 Bildpunkte also 0,13 Pixel.

Ab `maxBands` (60) werden die uebrigen zu einem Band zusammengefasst; das
Original erlaubt 250, hier ist weniger Platz.

Dass alle Eingaenge zu einem Strang zusammenlaufen, ist keine Vereinfachung:
welcher Eingang welchen Ausgang bezahlt, laesst sich in Bitcoin **nicht**
sagen. Einzelverbindungen waeren erfunden.

**Nachgerechnet** (200 px, mit Gebuehr als Ausgang): Rand plus Luecken ergibt
200 px, der Strang ebenfalls 200 px, und das Verhaeltnis Strang zu Rand ist
fuer jedes Band identisch (Streuung 0,0000) -- es wird also keines bevorzugt
oder benachteiligt.

massstabsgetreu.

Ueber einem Band steht sein Betrag; ein Klick folgt dem Weg weiter (Eingang zur
Vorgaengertransaktion, Ausgang zur ausgebenden Transaktion oder zur Adresse).

### Zwei Rechenfallen

**Mehr Baender als Bildpunkte.** Ab `maxBands` (40) werden die uebrigen zu
einem Band zusammengefasst ("weitere 80"), sonst ist nichts mehr zu erkennen.

**Die Mindesthoehe summiert sich.** Jedes Band bekommt mindestens einen
Bildpunkt; bei 120 Eingaengen auf 220 px Hoehe lief der Stapel dadurch gut zwei
Pixel unten aus dem Bild. Zum Schluss wird deshalb einmal auf die verfuegbare
Hoehe normiert. Nachgerechnet ueber 1 bis 500 Eingaenge: immer exakt 220,00 px.

Die Betraege gehen ebenfalls exakt auf -- links die Summe der Eingaenge, rechts
die Ausgaenge plus Gebuehr, beide auf dieselbe Hoehe.


## Bedienelemente skalieren nicht mit

`ExplorerView` hat neben `scaleUnit` ein eigenes `uiFont`
(`min(scaleUnit * 0.78, 15)`). Der **Inhalt** darf mit der Flaeche wachsen, die
**Bedienelemente** nicht -- die Suchleiste wurde in einem grossen Fenster sonst
albern gross. Der Hinweis rechts im Feld bleibt zudem leer, solange nichts
eingegeben ist: dort staende sonst dasselbe wie im Platzhalter.

**Zeichen wie `‹` sitzen nicht zuverlaessig mittig.** Sie bringen je nach
Schrift eine eigene Seiten- und Grundlinienlage mit; `anchors.centerIn` zentriert
das Textfeld, nicht das sichtbare Zeichen. Der Zurueck-Pfeil ist deshalb mit
zwei Strichen auf einer kleinen Leinwand gezeichnet -- schriftunabhaengig und
immer dort, wo er sein soll.


## Platz fuer grosse Flussgrafiken

Die Hoehe der Flussgrafik richtet sich nach der **tatsaechlichen Zahl der
Baender** -- auf der Ausgangsseite zaehlt die Gebuehr mit, sonst wird es dort
zu eng. Vorher wurde nur `max(vin.length, vout.length)` gezaehlt, wodurch bei
einem Eingang und zwei Ausgaengen (also drei Ausgangsbaendern) das unterste
Band an der Kante klebte und die Beschriftung darunter beruehrte.

    Baender   vorher   jetzt
        1       91 px   117 px
        3      103 px   124 px
       10      221 px   260 px
       24      338 px   442 px

Dazu mehr Rand (`padY` von 9 auf 11 %) und ein Deckel bei 34 statt 26
Einheiten. Wird der Inhalt dadurch laenger als das Fenster, rollt der Explorer
-- er hat wie die Miner-Ansicht einen schmalen Balken rechts, der nur
erscheint, solange es etwas zu rollen gibt.


## Farben nicht im RGB-Raum mischen

Blau (H 216°) und Orange (H 33°) liegen **177° auseinander** -- praktisch
gegenueber. Ihre RGB-Mitte faellt dadurch auf **28 % Saettigung** und wirkt
grau; der Verlauf sah in der Mitte aus wie ausgewaschen.

Ueber den Farbkreis gemischt bleibt die Saettigung erhalten. Aufwaerts fuehrt
der Weg ueber **Magenta (H 305°)**, abwaerts ueber Gruen (H 125°). Magenta
passt zum Orange und entspricht dem, was das Original tut, das von Violett nach
Blau laeuft. `mixHue()` interpoliert deshalb in HSV entlang des gewaehlten
Bogens (`hueUp`), `flowColor(t)` liefert die Farbe an der Stelle t; die
Verlaeufe bekommen fuenf Stufen statt zwei.

## Die Naht in der Mitte

Ein- und Ausgaenge stossen bei `w/2` aneinander. Durch die Kantenglaettung
blieb dort ein feiner Strich stehen, und das Bild sah nach **zwei Formen** aus
statt nach einem Fluss. Beide Seiten ueberlappen jetzt um einen dreiviertel
Bildpunkt (`seam`).

## Wie viele Faeden gezeigt werden

`maxStrands = 24` im Original meint nur, wie viele **vollstaendig** auf den
Schirm passen sollen -- gezeichnet werden bis zu `lineLimit = 250`. Mit 24 als
harter Grenze fehlten hier sichtbar Eingaenge.

Jetzt bis zu 250, begrenzt durch die Hoehe (`bandLimit`), und die Mindestdicke
ist von 2,0 auf 1,2 Bildpunkte gesenkt. Der Deckel der Zeichenflaeche liegt bei
48 statt 34 Einheiten:

    Eingaenge   Flaeche   gezeigte Baender   frueher
        60       624 px         60             24
       120       624 px        120             24
       250       624 px        250             24
       400       624 px        250             24

## Kopieren

QtQuick hat keine eigene Schnittstelle zur Zwischenablage. Der uebliche Weg ist
ein unsichtbares `TextEdit`, dessen Inhalt man auswaehlt und kopieren laesst.
TxID, Blockhash und Adresse sind anklickbar; daneben steht "kopieren" und fuer
anderthalb Sekunden "kopiert".


## Lage und Strichstaerke sind zwei verschiedene Dinge

Der Kern der ganzen Darstellung, und lange falsch gemacht:

    Gewicht   der echte Anteil am Betrag. Alle Gewichte zusammen ergeben genau
              `trunkH`. Danach richtet sich die **Lage** im Strang.
    Dicke     womit gezeichnet wird, mindestens `minBand`. Ist ein Band duenner
              als das Minimum, **ueberlappt** es seine Nachbarn im Strang.

Genau diese Ueberlappung haelt den Strang schmal, obwohl zweihundertfuenfzig
Faeden hineinlaufen. Im Original steht dazu:

    thickness = min(combinedWeight + 0.5, max(minWeight - 1, w) + 1)
    innerY    = min(innerBottom - thickness/2,
                    max(innerTop + thickness/2, lastInner + weight/2))

Die Lage kommt aus `weight`, die Dicke aus `thickness`. Vorher wurde beides
gleichgesetzt und der Strang ueber `fit()` auf die **Summe der Mindestdicken**
aufgezogen -- bei 250 Baendern zu je 1,2 px waren das 300 px statt der
vorgesehenen 40. Der Ausgang wurde dadurch ein fetter Klotz statt eines Bandes.

    Eingaenge   Strang   Dicke je Faden   Summe Dicken   Ueberlappung
          1      40 px      40,3 px           40 px       nein
         10      40 px       4,0 px           40 px       nein
         60      40 px       1,3 px           77 px       ja, 1,9-fach
        250      40 px       1,3 px          322 px       ja, 8,0-fach

## Die Naht in der Mitte, zweiter Anlauf

Die Ueberlappung der beiden Seiten allein reichte nicht. Solange mit
**Deckkraft unter 1** gezeichnet wird, ist die doppelt bemalte Stelle dichter
als ihre Umgebung -- der Strich bleibt sichtbar, nur andersherum. Die Baender
werden deshalb voll deckend gezeichnet; das Hervorheben beim Ueberfahren
geschieht ueber `Qt.lighter()` statt ueber die Deckkraft.


## Der Hoehenversatz in der Mitte

Ist ein Band **dicker als sein Gewicht** (weil die Mindestdicke greift), steht
es oben und unten ueber den Strang hinaus. Wie weit, haengt davon ab, wie viele
Baender betroffen sind -- und das ist auf beiden Seiten verschieden: bei 250
Eingaengen greift die Mindestdicke ueberall, bei einem einzigen Ausgang
nirgends. Dadurch sass die eine Seite ein paar Bildpunkte hoeher als die andere.

Die Rechnung war also richtig und das Bild trotzdem versetzt. Behoben wird das
nicht in der Rechnung, sondern beim Ausrichten: zum Schluss wird die
**gezeichnete** Flaeche mittig gesetzt (kleinstes `midY` bis groesstes
`midY + hMid`), nicht die gerechnete. Damit stimmt es unabhaengig davon, wie oft
die Mindestdicke zuschlaegt.

## Pfeilspitzen gleich lang, kurz, mit Randabstand

Drei Anlaeufe, jeder mit einem eigenen Fehler:

1. **Laenge an die Banddicke gekoppelt** (`tipRatio`). Machte die rechte Kante
   unruhig, weil jedes Band anders weit hinausragte.
2. **Feste, aber zu lange Spitze.** Das Band wirkt dadurch vorn duenner, als es
   ist -- die Dicke laeuft ueber die halbe Spitze aus.
3. **Kein Randabstand.** Die Spitze klebte an der Kante der Flaeche.

Jetzt: fuer alle Baender gleich lang, deutlich kuerzer (`arrowLen` von 8,9 auf
6,4 px bei 1240 px Breite) und mit `edgeMargin` (8,1 px) vom Rand abgeruckt.
Davor laeuft das Band ein gerades Stueck, damit seine Dicke bis zum Pfeil
erkennbar bleibt.

    Banddicke   Winkel der Spitze vorher / jetzt
        10 px          59° /  76°
        40 px         132° / 144°
       120 px         163° / 168°

Groesserer Winkel heisst stumpfer, also gleichmaessigere Dicke bis zum Ende.

## Duennere Faeden, mehr Luft

Bei 250 Eingaengen blieben zwischen 1,29 px dicken Faeden nur 0,66 px Luecke --
der Kamm am Rand wirkte gedrungen. Mit 0,81 px sind es 1,15 px:

    Faeden   Dicke   Luecke   Verhaeltnis Luecke zu Faden
       60    1,29 ->  0,81     6,94 ->  7,43 px    5,4 -> 9,2
      120    1,29 ->  0,81     2,79 ->  3,28 px    2,2 -> 4,1
      250    1,29 ->  0,81     0,66 ->  1,15 px    0,5 -> 1,4


## Baender als Strich, nicht als gefuellte Flaeche

Der letzte grosse Fehler in der Flussgrafik, und ein grundsaetzlicher: ich habe
zwischen **zwei** Kurven gefuellt, die denselben *senkrechten* Abstand haben.
In einem steilen Abschnitt ist der *rechtwinklige* Abstand aber kleiner --
das Band wird dort duenner:

    Steigung   senkrechter Abstand   tatsaechliche Dicke   Verlust
        0°            40 px               40,0 px            0 %
       20°            40 px               37,6 px            6 %
       40°            40 px               30,6 px           23 %
       60°            40 px               20,0 px           50 %
       75°            40 px               10,4 px           74 %

Bei 60 Grad bleibt die Haelfte -- genau der Eindruck "dick, in der Rundung
schmal, unten wieder dick".

Das Original loest es, indem es die Baender **streicht** statt sie zu fuellen
(`stroke-width: combinedWeight`). Ein Strich hat per Definition ueberall
dieselbe Dicke. Genau so wird es jetzt gezeichnet: eine Mittellinie je Band,
`lineWidth` gleich der Banddicke. Die Pfeilspitze kommt als eigenes Dreieck
dazu, weil ein Strich nicht spitz zulaufen kann.

Nebenwirkung, angenehm: der Code wurde kuerzer, und die Naht in der Mitte ist
kein Sonderfall mehr.

## Kopieren als Zeichen

`CopyButton.qml` zeichnet zwei versetzte Blaetter, beim Kopieren fuer kurze Zeit
einen Haken. Gezeichnet statt gesetzt -- ein passendes Schriftzeichen gibt es
nicht ueberall, und auf Symbolschriften ist kein Verlass.


## Pfeile am Anfang der Eingaenge

Im Original sind das SVG-Marker (`input-arrow`, `output-arrow`) mit
`markerUnits="strokeWidth"` -- sie **wachsen mit der Banddicke**. An duennen
Faeden sieht man sie kaum, an dicken deutlich; deshalb sah es zunaechst aus,
als haetten nur manche Baender einen Pfeil.

Hier ebenso: `headFor(thickness)` skaliert mit der Dicke (`headRatio`), gedeckelt
durch die Breite des Anschlussstuecks. Der Strich beginnt hinter dem Pfeil,
damit sich beide nicht ueberlagern.

## Einzelheiten zur Transaktion

Virtuelle Groesse (Gewicht durch vier), Gewicht, Groesse, Version, Sperrzeit
und Sigops -- alles aus der Antwort von `/api/tx/:txid`, kein zusaetzlicher
Abruf noetig.

## Die Blockkette (`BlockChain.qml`)

Die letzten fuenfzehn Bloecke als waagerecht rollbare Kette, neuester links:
Hoehe, mittlere Gebuehrenrate, Belohnung, Anzahl der Transaktionen, Groesse,
Alter und Mining-Pool. Ein Klick oeffnet den Block im Explorer.

Sie erscheint, solange nichts gesucht ist -- so ist die Ansicht nicht leer und
man kommt mit einem Klick hinein. Nach einem neuen Block laedt sie sich nach
(ueber das Signal `blockMined` aus `FeedState`, mit vier Sekunden Verzug, damit
die Daten drueben schon stehen).

Datenquelle ist `/lookup/blocks/recent` im Daemon -- `/api/v1/blocks` liefert
fuenfzehn Bloecke samt `extras` (Pool, Belohnung, mittlere Gebuehr). Mit einer
Hoehe statt `recent` kommen die fuenfzehn davor.


## Die Blockansicht im Explorer

Dieselbe Kachelgrafik wie im Feed, nur fuer einen **beliebigen** Block
(`BlockTiles.qml`). Sie benutzt dieselben Bausteine -- `mondrian.js` fuer die
Packung, `colors.js` fuer die Farben -- damit beide Ansichten wirklich gleich
aussehen und nicht nur aehnlich. Auch die Geometrieregeln gelten dort: ganze
Rasterweite ab zwei Bildpunkten je Zelle, darunter gebrochen mit
Kantenglaettung.

Ein Klick auf eine Kachel oeffnet die Transaktion.

### Aufbereitung an einer Stelle

`write_block_summary()` im Daemon war auf den zuletzt gefundenen Block
zugeschnitten. Herausgeloest ist daraus `summarize_block(bid, base)`: sie holt
`/v1/block/<hash>/summary` und dampft jede Transaktion auf **zwei Ziffern** ein
(Kantenlaenge 1-5, Gebuehrenklasse 0-9). Ein voller Block wird so von rund
700 kB auf etwa 8 kB Kacheldaten; mit den Angaben fuer den Tooltip sind es rund
390 kB, die aber nur ueber die Loopback-Schnittstelle gehen.

Der Feed schreibt das Ergebnis nach `block.json`, der Explorer holt es ueber
`/lookup/blocktiles/<hash>` -- **dieselbe Funktion, zwei Abnehmer.** Bestaetigte
Bloecke aendern sich nicht mehr, ihre Kacheldaten liegen deshalb eine Stunde im
Zwischenspeicher statt der ueblichen 45 Sekunden.

### Was der Block hergibt

Ueber `/v1/block/<hash>` (Abfrage `blockinfo`) kommen neben den Kopfdaten:
Mining-Pool, Belohnung, Gebuehren gesamt, mittlere Rate und Gebuehrenspanne,
UTXO-Aenderung, SegWit-Anteil, mittlere Transaktionsgroesse, Coinbase-Angaben.
Alles davon steht jetzt in der Ansicht.


## Startseite des Explorers (`ExplorerHome.qml`)

Vorher stand dort nur ein Hinweistext und darunter die Blockkette -- und aus
einer geoeffneten Transaktion kam man nur durch wiederholtes Zurueckgehen
wieder heraus. Jetzt:

    Kennzahlen        Blockhoehe, Mempool, Gebuehr, Hashrate,
                      Schwierigkeitsaenderung, Kurs -- alles aus `FeedState`,
                      also ohne zusaetzlichen Abruf
    Geplante Bloecke  was aus dem Mempool als naechstes in Bloecke passen
                      wuerde (`/v1/fees/mempool-blocks`, Abfrage
                      `mempoolblocks`), in eigener Farbe
    Blockkette        die letzten bestaetigten Bloecke
    Letzte Transaktionen  aus dem laufenden Feed, anklickbar

Von jedem dieser Punkte fuehrt ein Klick weiter hinein.

**Startknopf.** Links in der Suchleiste, sichtbar sobald man in der Tiefe ist;
er raeumt Verlauf und Ergebnis und fuehrt zurueck. Wie der Zurueck-Pfeil ist
das Haus gezeichnet, nicht gesetzt -- Schriftzeichen sitzen nicht zuverlaessig
mittig.

**Falle bei den Feldnamen:** die Transaktionen im Feed heissen kurz --
`t` TxID, `v` **virtuelle Groesse**, `a` Betrag in sat, `f` Gebuehr, `r` Rate,
`n` laufende Nummer. `v` ist also nicht der Wert; der erste Entwurf zeigte
deshalb die vsize als Betrag an.


## Farbe der Bloecke

Die Farbe trennt den **Zustand**, nicht die Gebuehr -- so macht es auch das
Original, und man erkennt auf einen Blick, was schon feststeht und was noch
aussteht:

    geplante Bloecke     gruen   (aus dem Mempool, noch nicht bestaetigt)
    bestaetigte Bloecke  violett (in der Kette)

Innerhalb der **geplanten** wird zusaetzlich nach Gebuehr abgestuft, im selben
Gruenton -- der naechste Block traegt die hoechsten Gebuehren und leuchtet am
staerksten (`feeShade`, Saettigung 0,45 bis 0,75 und Helligkeit 0,34 bis 0,64
ueber die Spanne 0 bis 12 sat/vB). Bei den **bestaetigten** hebt sich nur der
neueste leicht ab.

Die raeumliche Wirkung kommt aus einer dunkleren Flaeche, die rechts und unten
hinter der vorderen hervorschaut -- billiger als echte Schraegkanten und im
Ergebnis dasselbe.

Auf farbigem Grund werden die Beschriftungen ueber Weiss mit Deckkraft gesetzt
statt ueber die Themenfarben; sonst verschwinden sie je nach Blockfarbe.


## Eine Leiste fuer beide Zustaende

Geplante und bestaetigte Bloecke standen zuerst in zwei getrennten
Abschnitten untereinander -- damit sah man zwar beides, aber nicht, **welcher
Block als naechster kommt**. Jetzt stehen sie in einer Leiste, getrennt durch
einen senkrechten Strich:

    [ferner ... naechster geplanter] │ [neuester bestaetigter ... aelter]

Die geplanten laufen also von aussen nach innen; der naechste steht direkt an
der Grenze, gleich neben dem zuletzt gefundenen Block. Das entspricht der
Anordnung im Original.

Die Leiste rollt beim Aufbau selbst an die Grenze -- dort spielt die Musik, und
bei acht geplanten plus fuenfzehn bestaetigten Bloecken waere sie sonst am
falschen Ende.

## Blockkachel mit Glasoptik (`BlockCard.qml`)

Ein Bauteil fuer beide Zustaende, damit sie sich nicht auseinanderentwickeln.
Drei Lagen ergeben den Eindruck:

    Rueckflaeche   dunkel, schaut rechts und unten hervor -- die Tiefe
    Vorderflaeche  Farbverlauf von hell oben ueber die Grundfarbe nach dunkel
    Glanz          heller, schraeg gedrehter Verlauf ueber die obere Haelfte

Der Glanz macht den Glaseindruck. Er liegt in einem Item mit `clip: true` --
ohne das steht der gedrehte Verlauf ueber die abgerundeten Ecken hinaus. Dazu
eine helle Kante oben und ein durchgehender heller Rahmen mit geringer
Deckkraft.

Die Farbe kommt von aussen (`tone`): gruen fuer geplante, violett fuer
bestaetigte. `highlighted` hebt den neuesten Block leicht ab, `hovered` die
Kachel unter dem Zeiger.


## Die vier Tafeln der Startseite (`MainPanels.qml`)

    TRANSAKTIONSGEBUEHR       vier Stufen (keine / niedrige / mittlere / hohe
                              Prioritaet) aus economy, hour, halfHour, fastest
    SCHWIERIGKEITSANPASSUNG   Fortschrittsbalken, durchschnittliche Blockzeit,
                              Aenderung mit Vorzeichen, Ziel und Restzeit
    MEMPOOL                   Mindestgebuehr, Belegung, unbestaetigte Anzahl
                              und die Kurve der eingehenden Transaktionen
    ERSETZTE TRANSAKTIONEN    RBF: alte gegen neue Gebuehrenrate

Bis auf die Ersetzungen kommt alles aus `FeedState` -- ohne zusaetzlichen
Abruf. Die Tafeln stehen zweispaltig, unterhalb von etwa 62 Schriftgroessen
Breite einspaltig.

### Woher der Zulauf kommt

Fuer die Kurve schreibt der Daemon einen Verlauf mit (`sample_stats`, 240
Punkte im Fuenfsekundentakt, also zwanzig Minuten): Fuellstand, vByte je
Sekunde und **Zulauf**. Letzterer ergibt sich aus dem Fortschritt der laufenden
Nummer -- `seq` zaehlt jede gesehene Transaktion, die Differenz zwischen zwei
Messungen geteilt durch die Zeit ist der Zulauf je Sekunde. Es braucht dafuer
also keine eigene Abfrage.

Die Kurve ist **nach Hoehe eingefaerbt**: ruhige Abschnitte gruen, Spitzen rot
(Farbton von 0,33 nach 0 ueber den Anteil am Hoechstwert). Dazu eine
gestrichelte Linie auf dem Mittelwert -- so sieht man auf einen Blick, ob
gerade mehr los ist als sonst.

### Farbe der Gebuehrenstufen

Dieselbe Logik wie bei den geplanten Bloecken: derselbe Gruenton, nach oben
kraeftiger. Hoehere Prioritaet, saftigeres Gruen.


## Transaktionsarten und ihre Farben (`txtype.js`)

**Bitcoin kennt keine Typen.** Was hier steht, ist eine Deutung anhand der
Struktur -- nuetzlich, aber nie sicher: eine Wallet kann jedes Muster auch aus
anderen Gruenden erzeugen. Die Ansicht nennt deshalb die Art und keine
Gewissheit, und schreibt eine Erklaerung daneben.

    Zahlung          orange   ein bis zwei Eingaenge, ein Ziel, meist Rueckgeld
    Konsolidierung   tuerkis  viele Eingaenge auf wenige Ausgaenge
    Sammelzahlung    blau     wenige Eingaenge auf viele Ausgaenge
    CoinJoin         magenta  viele Beteiligte, mehrere gleich grosse Ausgaenge
    Datenablage      grauviolett  enthaelt einen OP_RETURN-Ausgang
    Blockbelohnung   gold     die Coinbase-Transaktion eines Blocks
    Umschichtung     indigo   alles auf einen Ausgang, ab zwei Eingaengen

Warme Toene fuer alltaegliche Zahlungen, kuehle fuer Umschichtungen, ein
eigener Ton fuer Datenablage.

**Reihenfolge der Pruefung** ist wichtig: Coinbase und OP_RETURN sind eindeutig
und gehen vor; CoinJoin braucht viele Beteiligte **und** mindestens drei gleich
grosse Ausgaenge; erst danach die Zaehlregeln.

**An echten Daten geprueft** (Block 965080, 70 Transaktionen):

    Zahlung          55  (79 %)
    Umschichtung      9  (13 %)
    Sammelzahlung     2  ( 3 %)
    Datenablage       2  ( 3 %)
    Blockbelohnung    1  ( 1 %)
    Konsolidierung    1  ( 1 %)

Der erste Entwurf zaehlte jede Transaktion mit einem einzigen Ausgang als
Umschichtung und kam damit auf 33 % -- eine Zahlung ohne Rueckgeld ist aber
keine Umschichtung. Mit der Bedingung "ab zwei Eingaengen" sind es 13 %.


## Gleich hohe Tafeln, Luft ueber der Kurve

Die beiden unteren Tafeln waren verschieden hoch -- die eine fest, die andere
nach Inhalt. Nebeneinander wirkt das wie ein Versehen. Jetzt teilen sie sich
`lowerHeight`, die sich nach der volleren von beiden richtet und mindestens
19 Schriftgroessen betraegt (rund 247 statt 214 Bildpunkten). Die Kurve bekommt,
was uebrig bleibt -- gut 135 statt 91 Bildpunkten.

**Die hohen Spitzen wurden abgeschnitten.** Die Achse endete genau beim
Hoechstwert, also beruehrte die hoechste Spitze die Oberkante und wurde durch
die Strichstaerke angeschnitten; die oberste Beschriftung hatte dort ebenfalls
keinen Platz.

Die Achse reicht deshalb bis zum **1,12-fachen** des Hoechstwerts. Beschriftet
wird weiterhin der echte Wert, nicht der erhoehte -- sonst stuende an der Achse
eine Zahl, die nie vorkommt. Eine Spitze endet damit bei rund 89 % der Hoehe.


## Geplante Bloecke: die Inhalte kommen ueber den WebSocket

**Ueber REST gibt es sie nicht** -- alle plausiblen Pfade geben 404:

    /api/v1/mempool-blocks/0    /api/v1/mempool-block/0
    /api/v1/fees/mempool-blocks/0    /api/v1/projected-block/0

Ueber den WebSocket schon, und der erste Versuch scheiterte an der **Form der
Nachricht**: der Befehl geht nicht ueber `action`, sondern als eigener
Schluessel.

    falsch:   {"action": "track-mempool-block", "index": 0}
    richtig:  {"track-mempool-block": 0}

Die Antwort heisst `projected-block-transactions` und enthaelt `index`,
`sequence` und `blockTransactions` -- die Transaktionen in Kurzform, Reihenfolge
wie in `uncompressTx` des Originals:

    [txid, fee, vsize, value, rate, flags, time]

**Nach der Vollform folgen fortlaufend Aenderungen** (`delta`). Die brauchen wir
nicht, also wird direkt wieder abbestellt (`{"track-mempool-block": -1}`) --
sonst laeuft im Hintergrund dauerhaft ein Strom mit.

Gemessen: 5940 Transaktionen, 692 kB roh, aufbereitet 572 kB. Die
Aufbereitung ist dieselbe wie bei bestaetigten Bloecken (zwei Ziffern je
Transaktion), damit die Kachelgrafik in beiden Faellen gleich aussieht.

**Die Reihenfolge bestaetigt, wonach sortiert wird:** die teuerste Transaktion
steht vorn (120,63 sat/vB im Beispiel). Wer mehr zahlt, draengt andere in einen
spaeteren Block.

### Wie das im Daemon zusammenspielt

Der WebSocket laeuft in einem eigenen Faden, die Abfrage kommt aus dem
HTTP-Faden. Ueber den Umweg zweier Felder bleibt das Senden dort, wo die
Verbindung lebt:

    feed.want_track   was abonniert werden soll (aus der Abfrage gesetzt)
    feed.tracked      was tatsaechlich abonniert ist (vom WebSocket-Faden)

Die Schleife vergleicht beide nach jeder Nachricht und meldet an oder ab. Die
Abfrage setzt `want_track` und wartet bis zu 25 Sekunden auf das Ergebnis.

### Die Zeitschaetzung

Grundlage ist die **gemessene** durchschnittliche Blockzeit aus der
Schwierigkeitsanpassung (`timeAvg`), nicht die nominellen zehn Minuten. Gerade
sind das 9,9 Minuten, also 10 / 20 / 30 / 39 Minuten fuer die ersten vier
Bloecke. Ueber der Kachel steht die Schaetzung mit.


## Der Feed rechnete weiter, obwohl niemand hinsah

Am Abend des 01.09.2026 gemeldet: der Luefter dreht hoch, obwohl nur der
Browser offen ist. Nachgemessen an der DMS-Shell:

    Dashboard offen         13,9 % CPU
    Dashboard geschlossen     7,4 % CPU   <- die Haelfte lief weiter

**Die Ursache ist eine QML-Falle: `Item.visible` wird nicht falsch, wenn das
Fenster verschwindet.** Die Sichtbarkeit eines Fensters ist keine Eigenschaft
der Elementkette. Der Dashboard-Tab hielt sich deshalb fuer sichtbar, holte
weiter Daten und liess seine Leinwand mit dreissig Bildern je Sekunde laufen.

`active: root.visible` war also wirkungslos. `Window.window.visible` half
ebenfalls nicht -- in einem Quickshell-Popout bleibt auch das wahr.

**Der Popout kennt seinen Zustand selbst** (`dashVisible`). Der Patch reicht ihn
jetzt an den Tab durch:

    onLoaded: item.live = Qt.binding(function () { return root.dashVisible })

Der Tab haengt daran seine Datenbeschaffung **und** die Sichtbarkeit seiner
Ansichten -- letzteres haelt auch die Zeitgeber von `FeedCanvas` an, die an
`root.visible` haengen.

Dazu die Leistenpille: sie zeigt nur Text und fragte trotzdem zweimal je
Sekunde. Sie ist **immer** sichtbar -- was sie kostet, kostet sie den ganzen
Tag. Jetzt alle zwei Sekunden.

    Dashboard offen          ~8,0 % CPU
    Dashboard geschlossen     0,0 % CPU

**Merksatz:** in QML sagt `visible` nichts darueber, ob jemand wirklich
hinsieht. Wer Zeitgeber oder Leinwaende daran haengt, muss die Sichtbarkeit des
Fensters getrennt beschaffen.


## Der geplante Block, lebendig (`ProjectedBlock.qml`)

Auf der Startseite des Explorers steht jetzt der naechste Block als
Kachelgrafik, und er veraendert sich mit dem Zulauf: neue Transaktionen blitzen
weiss auf, verdraengte verschwinden, darueber steht, wie viele es waren.

Drei Entscheidungen dahinter, jede aus einer Messung.

### 1. Nicht neu packen, sondern nachfuehren

Der erste Entwurf holte alle zwei Sekunden die Liste und packte sie neu. Das
Ergebnis war Flimmern. Nachgemessen (`mondrian.js` in Python nachgebaut, zwei
Abfragen im Abstand von 1,5 s):

    neu 582, raus 617, geblieben 4242
    davon an anderer Stelle: 4231 = 99,7 %

**Fast jede Kachel wechselt ihren Platz**, weil die Liste nach Gebuehrenrate
sortiert ist: eine eingefuegte Transaktion schiebt alles dahinter weiter. Bei
den heutigen Gebuehren liegen tausende Transaktionen dicht beieinander, die
Reihenfolge unter ihnen ist entsprechend unstet.

Richtig ist deshalb: **bekannte Kacheln bleiben liegen**, Abgaenge geben ihre
Flaeche zurueck (`MondrianLayout.remove`), Zugaenge fuellen die Luecken. Genau
dafuer fuehrt `mondrian.js` eine exakte Belegungskarte statt der Slot-Liste des
Originals. Ueber fuenf Aktualisierungen gemessen:

    Start      Hoehe 91, freie Zellen 0,7 %
    Runde 4    Hoehe 96, freie Zellen 3,0 %  -- fast alle in den obersten Zeilen

Die Packung bleibt also dicht, und die Loecher sitzen an der Oberkante, wo sie
nicht auffallen. Neu gepackt wird nur, wenn es sich lohnt: weniger als ein
Viertel der Kacheln wiedererkannt (nach einem Blockfund) oder die Rasterbreite
weicht um mehr als 15 % ab.

**Der Preis dafuer ist sichtbar und gewollt:** nach der ersten Packung sagt die
Lage einer Kachel nichts mehr ueber ihren Rang. Eine teure Transaktion, die
spaeter hereinkommt, fuellt die naechste freie Luecke -- deshalb sitzen
einzelne violette Kacheln mitten im tuerkisen Feld. Den Rang traegt die
**Farbe**, nicht der Platz. Anders herum ginge es nur, indem bei jeder
Aenderung alles verschoben wird, und genau das sind die 99,7 %.

### 2. Nur die Aenderungen holen, nicht die Liste

Die Vollform ist **634 kB**. Alle zwei Sekunden geholt und in QML durch
`JSON.parse` geschickt kostete das allein **6 % CPU**.

Der Daemon fuehrt deshalb ein **Aenderungsbuch** je Rang: jede `delta`-Nachricht
vom Server bekommt eine laufende Nummer, Zu- und Abgaenge werden aufgehoben
(`PROJECTED_LOG_KEEP = 200` Schritte). Die Abfrage kennt zwei Formen:

    /lookup/projectedtiles/0         die Vollform, mit "seq"
    /lookup/projectedtiles/0-1234    nur, was sich seit Nummer 1234 tat

Gemessen an derselben Stelle:

    Vollform            634 043 Bytes
    Aenderung, ruhig            123 Bytes
    Aenderung, lebhaft       86 058 Bytes

Die Vollform kommt zurueck, wenn der Rueckstand groesser ist als das Buch, die
Liste ausgeduennt ist (ueber `MAX_TILES`) oder die Aenderungen zusammen mehr als
60 % der Vollform ausmachen wuerden. Die Oberflaeche merkt sich `seq` und faellt
bei einem Fehlschlag von selbst auf die Vollform zurueck.

### 3. Eine dauernde Animation kostet hier 5 % CPU

Der erste Entwurf hatte einen pulsierenden Punkt neben der Ueberschrift --
sechs Pixel Kantenlaenge, `SequentialAnimation on opacity` mit
`loops: Animation.Infinite`. **Er kostete 5 % CPU.** Eine laufende Animation
haelt die Bildwiederholung bei sechzig Bildern je Sekunde, und jedes Bild kostet
in dieser Ansicht rund 0,8 ms. Der Punkt steht jetzt still.

Dasselbe gilt fuer das Aufblitzen der neuen Kacheln. Es laeuft ueber einen
Zeitgeber statt ueber eine `NumberAnimation`, in **fuenf Stufen ueber 750 ms**,
und zeichnet nur den **Umriss der frischen Kacheln** neu (`markDirty` plus
`clearRect` statt `ctx.reset()`). Ohne diese beiden Griffe kostete allein das
Ausblenden 4 % -- eine 510x510 grosse Leinwand zwanzigmal je Aktualisierung
abzuraeumen und zur Grafikkarte zu schieben.

Die frischen Kacheln liegen auf einer **eigenen Leinwand** ueber der Grafik,
dieselbe Aufteilung wie im Feed (Halde unten, fallende Kacheln darueber). Sonst
muessten fuer jedes Bild des Ausblendens alle 6900 Rechtecke neu.

Bilanz der Startseite mit laufender Verfolgung. Die Zwischenstaende sind mit
`top` gemessen -- untereinander vergleichbar, aber grob:

    Grundlast der Seite                    5,0 %
    erster Entwurf (Vollform + Puls)      16,0 %
    nach den drei Griffen                  5,6 %

Genauer nachgemessen ueber je 60 Sekunden aus `/proc/<pid>/stat` (utime+stime)
statt aus Momentaufnahmen -- deshalb liegen die Werte etwas hoeher:

    Grundlast ohne Mitverfolgen            6,3 %
    mit Mitverfolgen                       6,9 %  und  7,6 % im zweiten Lauf

Das Mitverfolgen kostet also weniger als einen Prozentpunkt und geht im
Rauschen der Mempool-Aktivitaet fast unter. **Merksatz zum Messen:
`top`-Momentaufnahmen taugen zum Vergleichen zweier Bauformen, nicht als
absolute Zahl** -- dafuer die Rechenzeit ueber eine Minute aus `/proc` holen.

### Nebenbei: die Zellzuordnung wird erst gebaut, wenn jemand hinsieht

`cellIdx` ordnet jeder Rasterzelle ihre Kachel zu und traegt Tooltip und Klick
-- rund 7000 Eintraege. Sie bei jeder Aktualisierung neu aufzubauen ist reine
Vorratshaltung; jetzt setzt eine Aenderung nur `__idxDirty`, und `at()` baut sie
beim ersten Mausdurchgang.

### Was sonst noch daran haengt

- Die **Kennzahlen** (Anzahl, mittlere Gebuehr, Groesse) kommen nicht mehr aus
  einer eigenen REST-Abfrage, sondern aus dem Zustand: `set_next_block` legt
  jetzt die ganze Reihe der geplanten Bloecke ab (`snap.projected`, acht
  Stueck, rund 1,3 kB). Der WebSocket schickt sie ohnehin bei jeder Aenderung
  mit. Damit lebt auch die **Leiste auf der Startseite** ohne Zutun, und die
  Ansicht des einzelnen geplanten Blocks zeigt nicht mehr den Stand vom Klick.
- **Nur solange jemand hinsieht.** Die Abfrage haelt das Abonnement beim Server
  am Leben (`PROJECTED_LINGER`, 20 s). `ExplorerHome.live` haengt an
  `visible && root.visible` der Explorer-Ansicht, und die haengt im
  Dashboard-Tab an `dashVisible`. Nachgemessen: 18 Sekunden nach dem Beenden
  der Anwendung meldet sich der Daemon von selbst ab.
- **Gebuehren unter 10 sat/vB mit einer Nachkommastelle.** Gerundet stand in
  ruhigen Zeiten an jedem Block "~0 sat/vB" und als Spanne "0 – 0".


## Mempool-Goggles: dieselben Kacheln nach Art (`TileGoggles.qml`)

Ueber jeder Kachelgrafik im Explorer steht jetzt ein Umschalter:

    Gebuehr   teal bis violett nach sat/vB -- die Farben des Originals
    Art       was die Transaktion tut

Dazu eine Legende mit den Anteilen, und darunter der Satz, dass eine Deutung
eine Deutung bleibt.

### Woher die Art kommt: das Bitfeld `flags`

`txtype.js` konnte Arten bisher nur aus Ein- und Ausgaengen bestimmen
(`classify`), und die hat die Kachelgrafik nicht -- sie kennt je Transaktion
nur zwei Ziffern. **mempool.space liefert aber ein Bitfeld mit**, in beiden
Quellen:

    /api/v1/block/<hash>/summary     Feld "flags"
    projected-block-transactions     Stelle 5 der Kurzform
                                     [txid, fee, vsize, value, rate, flags, time]

Die Bitlage steht in `frontend/src/app/shared/filters.utils.ts`
(`TransactionFlags`) und ist **nicht geraten, sondern geholt und
gegengeprueft**: Bit 24 (`op_return`) war bei einer Stichprobe gesetzt, die
tatsaechlich einen OP_RETURN-Ausgang hatte, und bei einer ohne nicht.

    rbf 0   no_rbf 1   v1 2   v2 3   v3 4   nonstandard 5
    p2pk 8  p2ms 9  p2pkh 10  p2sh 11  p2wpkh 12  p2wsh 13  p2tr 14
    cpfp_parent 16  cpfp_child 17  replacement 18  acceleration 19
    op_return 24  fake_pubkey 25  inscription 26  fake_scripthash 27  annex 28
    coinjoin 32  consolidation 33  batch_payout 34
    sighash_all 40 ... sighash_acp 44

**Falle: `>>` rechnet in JavaScript mit 32 Bit.** Die Flags reichen bis 2^44 --
mit `flags >> 40 & 1` kommt Unsinn heraus. `hasFlag()` teilt deshalb durch
Zweierpotenzen.

### Eine Ziffer je Kachel

Der Daemon legt die Art als **eigene Zeichenkette** neben die Kacheln:

    "tiles":  zwei Ziffern je Kachel  (Kantenlaenge, Gebuehrenklasse)
    "types":  eine Ziffer je Kachel   (Art)

Bewusst getrennt und nicht als dritte Ziffer in `tiles`: `FeedCanvas` liest
dieselbe Datei (`block.json`) und haette sonst nichts mehr davon verstanden.
Wer `types` nicht kennt, ignoriert es.

Die Rangfolge bei mehreren gesetzten Bits -- seltener und aussagekraeftiger
geht vor: Blockbelohnung, CoinJoin, Inschrift, Datenablage, Konsolidierung,
Sammelzahlung, Zahlung. **Die Blockbelohnung steht in keinem Bit**; sie ist an
ihrer Lage erkennbar, als erste Transaktion des Blocks.

`TX_KINDS` im Daemon und `KINDS` in `txtype.js` **muessen dieselbe Reihenfolge
haben** -- die Ziffer ist der Index in diese Liste.

### Was dabei herauskommt

Ein geplanter Block am 02.09.2026:

    Zahlung          58,4 %
    Datenablage      37,3 %
    Sammelzahlung     2,6 %
    Konsolidierung    1,5 %
    Inschrift         0,2 %

Und ein bestaetigter Block wenige Minuten spaeter mit umgekehrtem Verhaeltnis
(67,9 % Datenablage). Dass jede dritte bis zweite Transaktion einen
OP_RETURN-Ausgang traegt, ist keine Fehldeutung -- eine Stichprobe daraus hatte
den Ausgang wirklich. Genau dafuer sind die Goggles da.

Kleinigkeit mit Wirkung: was vorkommt, aber unter ein halbes Prozent faellt,
steht als "<1 %" da und nicht als "0 %". Die seltenen Arten sind der Grund,
ueberhaupt umzuschalten.

### Wo es (noch) nicht geht: die Halde

Die Halde im Feed lebt aus den `transactions`-Nachrichten des WebSocket, und
**die fuehren kein `flags` mit** (am 02.09.2026 nachgesehen: nur `txid`, `fee`,
`vsize`, `value`, `rate`, `time`). Die Goggles gelten deshalb fuer die
Kachelgrafiken im Explorer -- geplanter wie bestaetigter Block --, nicht fuer
die Halde. Fuer den **Block** im Feed waeren sie moeglich (`block.json` traegt
jetzt `types`), aber ein Bild mit zwei Farblogiken gleichzeitig waere
irrefuehrend.

### Nebenbei behoben: die Suche nach einer Blockhoehe

Beim Gegenpruefen der Blockansicht aufgefallen: eine Blockhoehe einzugeben
endete immer in "Antwort nicht lesbar". `/api/block-height/<n>` antwortet mit
dem **blanken Hash**, nicht mit JSON; der Daemon reichte ihn unveraendert
durch, deklarierte ihn aber als `application/json`, und `JSON.parse` in
`FeedState.lookup` scheiterte. Der Daemon verpackt ihn jetzt als
JSON-Zeichenkette.


## Beobachtete Wallets, watch-only (`WatchView.qml`)

Die Anwendung zeigt Guthaben und Verlauf einer Wallet, ohne sie anzufassen.
Eingetragen wird ein erweiterter **oeffentlicher** Schluessel -- xpub, ypub
oder zpub.

### Der Grundsatz zuerst, weil er den Bau bestimmt

Verbindlich seit 01.09.2026 (`ZIELBILD.md`): **die Anwendung bekommt nie etwas
in die Hand, mit dem sich Geld bewegen liesse.** Daraus folgt hier dreierlei:

1. **Nur oeffentliche Rechnung.** Im Daemon steht Punktarithmetik auf
   secp256k1 und sonst nichts. Gehaertete Ableitung ist nicht moeglich -- sie
   braeuchte den privaten Schluessel. Es gibt im ganzen Programm keine Zeile,
   die signieren koennte.
2. **Der xpub verlaesst das Geraet nie.** Die Adressen werden hier abgeleitet
   und **einzeln** ueber `/api/address/<addr>` abgefragt. Wer den xpub an einen
   Dienst gibt, zeigt ihm schlagartig die ganze Wallet -- jede vergangene und
   jede kuenftige Adresse.
3. **Der Dienst nimmt nichts entgegen.** Eingetragen wird ueber die
   Kommandozeile, nicht ueber die Oberflaeche. Ein Schreibweg in die
   Loopback-Schnittstelle waere die erste Angriffsflaeche des Programms.

Ein `xprv`/`yprv`/`zprv` wird **vor** jeder weiteren Pruefung abgewiesen, mit
einer Meldung, die sagt warum -- sonst kaeme nur "unbekannte Fassung" heraus.

### Die Mathematik, und wie sie geprueft wurde

Rund 150 Zeilen ohne fremde Abhaengigkeit: Punktaddition und
Skalarmultiplikation auf secp256k1, Base58Check, Bech32/Bech32m, HMAC-SHA512
fuer CKDpub aus BIP32.

    xpub  0x0488b21e  ->  P2PKH          1…    (BIP44)
    ypub  0x049d7cb2  ->  P2WPKH in P2SH 3…    (BIP49)
    zpub  0x04b24746  ->  P2WPKH         bc1…  (BIP84)

Die Versionsbytes stammen aus SLIP-0132, nicht aus dem Gedaechtnis.

**Zwei unabhaengige Gegenproben, beide bestanden:**

1. Die Testvektoren aus SLIP-0132 (xpub/ypub/zpub, je erste Adresse) und
   BIP-0084 (zwei Empfangs-, eine Wechseladresse und der oeffentliche
   Schluessel als Hex). Sechs von sechs.
2. **101 echte Ausgaenge aus der Kette**: aus dem `scriptpubkey` eines
   Transaktionsausgangs dieselbe Adresse erzeugen, die mempool.space unter
   `scriptpubkey_address` nennt -- p2pkh, p2sh, v0_p2wpkh, v0_p2wsh und
   v1_p2tr, keine einzige Abweichung. Das prueft die Kodierung gegen die
   Wirklichkeit statt gegen eine Fassung derselben Erwartung.

### Abtasten mit Luecke

`WATCH_GAP = 20` wie in BIP44: nach zwanzig unbenutzten Adressen in Folge gilt
die Kette als zu Ende. Beide Ketten (Empfang und Wechselgeld) werden getrennt
abgetastet.

**`WATCH_SPACING = 0.35` Sekunden zwischen den Abfragen -- nicht aus Ruecksicht
auf den Server, sondern auf den Benutzer.** Hundert Adressen im Stakkato von
derselben Herkunft zeigen dem Betreiber unmissverstaendlich, dass sie
zusammengehoeren. Das ist das Restrisiko dieser Ansicht, und es ist eines der
**Privatsphaere, nicht der Sicherheit**: Guthaben sind watch-only vollstaendig
geschuetzt. Ganz aufloesen laesst sich die Verkettung nur mit eigenem electrs.

Ein Lauf dauert dadurch: gemessen an der Testwallet aus BIP-0084 (40 benutzte
Adressen, 276 Transaktionen) rund 100 Sekunden. Abgetastet wird alle fuenf
Minuten und ausserdem nach jedem Blockfund -- vorher aendert sich nichts.

### Zwei Bauentscheidungen, die aus Messungen kommen

**Der Abtaster hat einen eigenen Faden.** Im Faden der uebrigen Nebenquellen
haette ein Lauf von hundert Sekunden die Mempool-Kurve loechrig gemacht und die
Miner-Abfrage angehalten.

**Die Wallet-Angaben stehen nicht im Zustand.** Sie sind rund 8 kB und aendern
sich alle fuenf Minuten; der Zustand wird 2,5-mal je Sekunde geschrieben und
ebenso oft geholt. Im Zustand steht nur die Kurzfassung (Saldo, Anzahl), das
Ganze unter dem eigenen Pfad `/wallets`, den die Ansicht alle fuenf Sekunden
holt -- und nur, solange sie zu sehen ist.

    /state    23 kB -> 31 kB mit Wallet-Angaben, 2,5x je Sekunde
    /wallets   8 kB, alle fuenf Sekunden, nur bei offener Ansicht

### Eigene Transaktionen in der Halde

Der Daemon fuehrt die TXIDs der beobachteten Wallets mit und setzt an der
Kachel das Feld `m`. `FeedCanvas` zeichnet darum einen hellen Rahmen -- **nur
einen Rahmen, keine eigene Farbe**: die Fuellung soll weiter Gebuehr oder Alter
zeigen. Bei vier Pixeln Kantenlaenge bleibt ein Kern von zwei Pixeln stehen,
das genuegt zum Finden. Der Strich sitzt auf halben Bildpunkten
(`+ 0.5`), sonst liegt er je zur Haelfte auf beiden Nachbarpunkten und wird
grau statt weiss. Im Tooltip steht es zusaetzlich in Worten.

### Bedienung

    btcfeed --watch-add <xpub|ypub|zpub> [Name]
    btcfeed --watch-list
    btcfeed --watch-remove <Nummer|Name>
    systemctl --user restart btcfeed

Der Eintrag landet in `~/.config/btcfeed/sources.json`, die Datei wird dabei
auf `0600` gesetzt. Die Ansicht nennt diese Befehle selbst, solange nichts
eingetragen ist.

### Was fehlt

- **Taproot (BIP86)** ist nicht dabei. Fuer P2TR gibt es kein eigenes
  Praefix -- ein xpub allein sagt nicht, dass Taproot gemeint ist. Das
  braeuchte eine ausdrueckliche Angabe der Adressform beim Eintragen.
- **Testnetz** (tpub/upub/vpub) ist nicht vorgesehen.
- Die Transaktionsliste fragt hoechstens `WATCH_TX_REQUESTS = 15` Adressen ab
  und behaelt die 30 juengsten Vorgaenge. Fuer eine grosse Wallet ist das ein
  Ausschnitt, kein Kontoauszug.
