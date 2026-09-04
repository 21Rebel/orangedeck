# OrangeDeck — Live-Mempool-Ansicht (Bitfeed-Nachbau)

Nachbau der Ansicht von [bitfeed.live](https://bitfeed.live): der zuletzt
gefundene Block in der Mitte, der Mempool als Halde unten, neue Transaktionen
fallen von oben hinein.

## Aufbau

| Teil | Ort | Zweck |
|---|---|---|
| Feed-Daemon | `~/.local/bin/orangedeck` | haengt am WebSocket von mempool.space, schreibt den Zustand |
| Zustand | `$XDG_RUNTIME_DIR/orangedeck/state.json` | ~7 kB, alle 0,4 s neu geschrieben — **tmpfs**, nicht die SSD |
| Sperre | `$XDG_RUNTIME_DIR/orangedeck/orangedeck.lock` | `flock`, es laeuft immer nur **eine** Instanz |
| Grafik | `~/.local/share/orangedeck/qml/` | `FeedState`, `FeedCanvas`, `FeedPanel` — reines QtQuick |
| Packung | `~/.local/share/orangedeck/qml/mondrian.js` | Portierung des Mondrian-Layouts aus bitfeed |
| Farben | `~/.local/share/orangedeck/qml/colors.js` | HCL-Farbmodell aus bitfeed, nach sRGB gerechnet |
| Blockdaten | `$XDG_RUNTIME_DIR/orangedeck/block.json` | Kacheln des letzten Blocks, ~10 kB, nur bei Blockwechsel |
| DMS-Plugin | `~/.config/DankMaterialShell/plugins/OrangeDeck/` | Leisten-Pille, Control-Center-Kachel, Desktop-Widget, Daemon |
| Eigenes Fenster | `~/.config/quickshell/OrangeDeckApp/` | eigenstaendige Quickshell-Konfiguration |
| Fensterstarter | `~/.local/bin/orangedeck-window` | holt ein offenes Fenster nach vorn statt ein zweites zu oeffnen |
| Dashboard-Tab | `~/.local/bin/orangedeck-dashtab` | legt die DMS-Ueberlagerung an, die den Tab einhaengt |

Die drei QML-Dateien liegen **einmal** unter `~/.local/share/orangedeck/qml/` und
sind in Plugin- und App-Verzeichnis hineinsymlinkt. Eine Aenderung wirkt damit
ueberall.

## Bedienung

- **Leistenpille** (rechts neben der RAM-Anzeige): Linksklick oeffnet das
  Popout, Rechtsklick oeffnet direkt das eigene Fenster.
- **Popout**: das Symbol oben rechts (`open_in_new`) oeffnet die grosse Ansicht.
- **Control-Center**: Kachel "Bitcoin", aufklappbar.
- **Desktop-Widget**: Instanz `orangedeck-1`. Verschieben/Groesse aendern im
  Bearbeitungsmodus (Knopf unten rechts am Bildschirm).
  Ein-/Ausschalten: `dms ipc call desktopWidget toggleEnabled orangedeck-1`
- **Eigenes Fenster**: `orangedeck-window`, oder ueber den Starter "OrangeDeck".
  Tasten im Fenster: `c` Farbe (Alter/Gebuehr), `s` Groesse (Wert/vBytes),
  `i` Blockangaben, `l` Legende. Die Auswahl steht in
  `~/.local/state/orangedeck/view.json`.
- **Einstellungen** der DMS-Oberflaechen: Einstellungen -> Plugins ->
  OrangeDeck (Farbe, Groesse, Blockangaben, Legende, Deckkraft,
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

Faellt der WebSocket aus, schaltet `orangedeck` selbsttaetig auf REST-Polling um
(gaenger, aber die Ansicht lebt weiter) und versucht den WebSocket mit
wachsender Wartezeit erneut.

## Stolperfallen, die Zeit gekostet haben

1. **Leistenpille**: Die Pille darf **kein** `StyledRect` mit eigener Breite
   sein — DMS setzt Hintergrund und Groesse selbst. Mit eigener Breite ueberlappt
   sie die Nachbarwidgets. Richtig ist ein blosses `Row { ... }`.
2. **Widget-ID**: In `barConfigs[].rightWidgets` heisst der Eintrag schlicht
   `orangedeck`, in `controlCenterWidgets` dagegen `plugin_orangedeck`.
   Zwei verschiedene Konventionen im selben Programm.
3. **Dashboard-Tab braucht einen Umweg**: `Modules/DankDash/DankDashPopout.qml`
   hat die fuenf Tabs fest verdrahtet, es gibt dort keinen Plugin-Haken. Statt
   in `/usr/share` zu schreiben (Root noetig, beim Paketupdate weg) legt
   `orangedeck-dashtab` unter `~/.config/quickshell/dms-custom` eine
   **Ueberlagerung aus Symlinks** an; nur drei Dateien sind echte Kopien
   (`SettingsData.qml`, `DankDashPopout.qml`, `DMSShellIPC.qml`). Gestartet wird
   ueber ein systemd-Drop-in mit `dms run -c <pfad>`. DMS-Updates fliessen durch
   die Symlinks weiter; aendern sich die drei gepatchten Dateien, einmal
   `orangedeck-dashtab` aufrufen (`--check` sagt, ob noetig, `--remove` macht es
   rueckgaengig).
4. **Desktop-Widget** braucht einen Eintrag in `desktopWidgetInstances`
   (`{id, widgetType, enabled, config}`) — die IPC-Befehle `desktopWidget enable`
   arbeiten nur auf bereits vorhandenen Instanzen. Die Standardgroesse kommt aus
   `defaultWidth`/`defaultHeight` am Widget selbst.
5. **`qs -p <dir>` startet beliebig viele Instanzen** desselben Fensters. Daher
   der Umweg ueber `orangedeck-window`.
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
   `~/.local/state/orangedeck/`.

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
orangedeck --print                     # Zustand einmalig per REST holen und zeigen
dms ipc call orangedeck status     # was das Plugin gerade liest
dms ipc call orangedeck restart    # Feed neu starten
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

Nebenbei vier Fallen beim Nachmessen selbst:
- `/usr/bin/qml` ist hier **Qt 5.15**. Versionslose Importe sind Qt-6-Syntax,
  deshalb meldet es nur "Did not load any objects". Der Qt6-Laeufer liegt unter
  `/usr/lib/qt6/bin/qml`.
- **`/usr/bin/qmllint` ist ebenso die Qt5-Fassung** (aus `qt5-declarative`,
  meldet sich als `qmllint 1.0`) und gibt **gar nichts** aus -- auch nicht bei
  einer absichtlich kaputten Datei. Ein "keine Meldungen" von dort beweist
  nichts. Die richtige liegt unter `/usr/lib/qt6/bin/qmllint`; mit `-I ui/qml`
  findet sie auch die geteilten Bausteine.
- **Qt schweigt, weil stderr kein Terminal ist.** Das ist der Grund fuer die
  verschluckten Meldungen, nicht ein Fehler in Qt. `QT_ASSUME_STDERR_HAS_CONSOLE=1`
  vor den Aufruf gesetzt, und die QML-Fehler stehen da -- am 04.09.2026 wurde
  so aus einem stummen `rc=1` in einer Zeile "Cannot assign to non-existent
  property". `Qt.exit(<code>)` als Umweg braucht es damit nicht mehr.
- **Ein gezeichnetes Bild geht ohne Bildschirm.** Xvfb plus `import`; die
  Wayland-Variable muss weg, sonst geht das Fenster auf dem echten Compositor
  auf und der Abzug bleibt schwarz:

      xvfb-run -a --server-args="-screen 0 1400x900x24" bash -c '
          env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb ./build/orangedeck-app --view 6 &
          sleep 10; import -window root /tmp/bild.png; pkill -f orangedeck-app'


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

    ~/.local/share/orangedeck/qml/                          (der eine echte Ort)
    ~/.config/DankMaterialShell/plugins/OrangeDeck/     (Plugin)
    ~/.config/quickshell/OrangeDeckApp/                 (eigenes Fenster)
    ~/.config/quickshell/dms-custom/Modules/DankDash/    (Dashboard-Tab)
    app/CMakeLists.txt                                   (eigenstaendige App)

Am 01.09.2026 kam `FrostedPanel.qml` dazu und landete ueberall ausser im
DankDash-Verzeichnis -- dessen Liste steht in `daemon/orangedeck-dashtab`, nicht in
`tools/install-links.sh`. Folge: `FeedPanel` liess sich dort nicht mehr laden
("FrostedPanel is not a type"), der Bitcoin-Tab scheiterte, und **das ganze
Dashboard liess sich nicht mehr oeffnen**. Im Journal stand der Grund
sauber drin -- die laufende Instanz meldete aber nichts mehr, weil der Fehler
beim Laden des Tabs auftrat, nicht im Betrieb.

**Behoben, indem beide Skripte die Liste nicht mehr fuehren**: `install-links.sh`
und `orangedeck-dashtab` lesen jetzt aus `ui/qml/`, was dort liegt. Einzig
`app/CMakeLists.txt` braucht den Eintrag weiterhin von Hand -- CMake muss die
Dateien zur Bauzeit kennen.

Nach einer neuen Datei also:

    tools/install-links.sh          # verteilt alles
    python3 daemon/orangedeck-dashtab  # baut die Ueberlagerung neu
    systemctl --user restart dms

### Am 04.09.2026 ein drittes Mal, und diesmal war die **Reihenfolge** das
### Problem

`MarketLiq.qml` wurde angelegt, `MarketView.qml` verwies darauf -- und die
Verteilung lief erst sieben Minuten spaeter. In diesen sieben Minuten war das
Dashboard des Nutzers kaputt:

    MarketView.qml:1212:5: MarketLiq is not a type
    FeedTabs.qml:251:5:    Type MarketView unavailable
    OrangeDeckWidget.qml:  Type FeedTabs unavailable

**Die Shell liest per Symlink direkt ins Repo.** Eine neue geteilte Datei
bricht das laufende Dashboard also in dem Augenblick, in dem eine andere
Datei auf sie verweist -- nicht erst beim naechsten Neustart, nicht erst nach
einem Bau. Zwischen "angelegt" und "verteilt" darf nichts liegen; im Zweifel
verteilt man, bevor der Verweis geschrieben wird.

**Und `plugin-scan reload` reicht dafuer nicht.** Nachgemessen: nach
`dms ipc call plugin-scan reload orangedeck` stand derselbe Fehler wieder da,
obwohl der Symlink laengst existierte. Der Reload haengt ein `?t=<zeit>` an
die Plugin-Datei und umgeht damit deren Puffer -- die **Typentabelle des
Verzeichnisses** wird davon nicht neu gelesen. Eine neu hinzugekommene Datei
sieht die laufende Shell erst nach `systemctl --user restart dms`. Eine
geaenderte sieht sie sofort; nur das Hinzukommen ist der Sonderfall.

Zum Nachsehen gibt es jetzt einen Schalter, der nichts aendert:

    tools/install-links.sh --check

Er meldet jede Datei aus `ui/qml/`, die an einem der vier Orte oder in
`app/CMakeLists.txt` fehlt, und gibt einen Rueckgabewert ungleich null.


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
`implicitHeight` in `BitcoinTab.qml` (Vorlage in `daemon/orangedeck-dashtab`)
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

`packaging/systemd/orangedeck.service`, eingerichtet von `tools/install-links.sh`.
Vorher lief orangedeck als loser Prozess: er starb mit der Sitzung, und nach einem
Absturz belebte ihn nur zufaellig der Waechter im DMS-Plugin.

**(1) `ProtectSystem=strict` macht auch `$XDG_RUNTIME_DIR` schreibgeschuetzt.**
orangedeck scheiterte schon an seiner Sperrdatei:

    OSError: [Errno 30] Read-only file system: '/run/user/1000/orangedeck/orangedeck.lock'

Richtig ist `RuntimeDirectory=orangedeck` -- systemd legt genau das Verzeichnis an,
das orangedeck ohnehin benutzt, und macht es beschreibbar.
`RuntimeDirectoryPreserve=restart` erhaelt es ueber einen Neustart hinweg, damit
`block.json` (rund 460 kB) nicht jedes Mal neu geholt wird.

**(2) `Restart=always` plus ein zweiter Verwalter ergibt eine Endlosschleife.**
orangedeck beendet sich **mit 0**, wenn schon eine Instanz die Sperre haelt
("orangedeck laeuft bereits"). Der Waechter im DMS-Plugin hatte parallel eine
eigene Instanz gestartet; der Dienst startete, fand die Sperre, beendete sich
sauber -- und systemd startete ihn wieder. 16 Runden in einer Minute.

Behoben an beiden Enden:
- `Restart=on-failure` statt `always`
- **Die Waechter starten jetzt den Dienst statt eines eigenen Prozesses.**
  `OrangeDeckDaemon.qml` und `orangedeck-window` rufen
  `systemctl --user start orangedeck.service` und fallen nur dann auf das Programm
  zurueck, wenn die Unit nicht eingerichtet ist.

Gegengeprueft: nach einem `kill -9` auf den Hauptprozess kam der Dienst
selbstaendig zurueck (eine Instanz, ein Neustart, Daten sofort wieder da).

**Nebenbei:** `systemctl show -p MainPID --value` liefert waehrend eines
Neustarts `0`. Ein `kill -9 0` trifft dann die **ganze Prozessgruppe** --
also immer auf Plausibilitaet pruefen, bevor man die Zahl an `kill` gibt.


## Uhr und Miner-Ansicht

Zwei zusaetzliche Ansichten in `ui/qml/`, umschaltbar mit 1/2/3; die Auswahl
merkt sich `Settings` (damit ein Tablet nach dem Einschalten gleich wieder als
Uhr hochkommt). Beide importieren nur `QtQuick` und laufen damit auch
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

`orangedeck` holt die langsamen Kennzahlen **in einem eigenen Faden**
(`run_extras`): die WebSocket-Schleife blockiert auf `ws.recv()`, dort haetten
HTTP-Abfragen den Feed bis zu 15 Sekunden angehalten.

    /v1/difficulty-adjustment      alle 5 Minuten
    /v1/mining/hashrate/1m         alle 5 Minuten -- 31 Messpunkte, 2,2 kB
                                   (/3d liefert nur drei, zu wenig fuer eine Kurve)
    <bitaxe>/api/system/info       alle 5 Sekunden, nur wenn eingetragen

Die Miner-Adresse steht in `~/.config/orangedeck/sources.json`:

    { "bitaxe": "http://192.168.1.42" }

`ORANGEDECK_BITAXE` in der Umgebung schlaegt die Datei. Ohne Eintrag passiert
nichts -- die Quelle ist damit abschaltbar wie alles andere. Die Datei ist
bewusst getrennt von `orangedeck.conf`, die den QSettings der Anwendung gehoert.

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

    orangedeck --discover-miners           auflisten
    orangedeck --discover-miners --write   in sources.json eintragen

Der Suchlauf geht ueber die eigenen /24-Netze und probiert je Adresse HTTP :80
und TCP :4028. Virtuelle Bruecken (`virbr`, `docker`, `br-`, `veth`, `tun`,
`tailscale`) bleiben draussen -- dort steht kein Miner.

**Der Dienst sucht nicht von selbst.** Ein Durchlauf ueber alle Adressen des
Netzes gehoert nicht in einen Hintergrunddienst; er passiert nur auf Zuruf.

### Am echten Geraet geprueft (01.09.2026)

Bitaxe Gamma 601, AxeOS v2.14.2, im Heimnetz erreichbar:

    Hashrate     1060 GH/s geglaettet, 1048 im Moment, 1071 erwartet
    beste Freigabe 295.580.247  ->  1 zu 425.627
    Sitzungsbestwert 1.092.084, Pool-Schwierigkeit 8.192
    56,5 C, 16,8 W, Luefter 5927 U/min, Fehlerquote 6,6 %
    Netzschwierigkeit laut Geraet 125.807.076.547.197
      -- deckt sich exakt mit dem Wert von mempool.space

`orangedeck --discover-miners` fand es von selbst im WLAN.

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

`ViewTabs.qml` ist der Umschalter zwischen Feed, Uhr und Miner --
bewusst ein eigenes Bauteil, weil ihn **beide** Oberflaechen benutzen: das
eigene Fenster (`app/qml/Main.qml`) und der Dashboard-Tab (Vorlage in
`daemon/orangedeck-dashtab`). Nur `import QtQuick`, laeuft also auch unter
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

    orangedeck --watch-add <xpub|ypub|zpub> [Name]
    orangedeck --watch-list
    orangedeck --watch-remove <Nummer|Name>
    systemctl --user restart orangedeck

Der Eintrag landet in `~/.config/orangedeck/sources.json`, die Datei wird dabei
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


## Blockhistorie und Transaktionsliste (`BlockHistory.qml`, `TxList.qml`)

Zwei Ansichten, die dieselbe Luecke schliessen: aus dem Explorer kam man
bisher nur so weit zurueck, wie die Leiste auf der Startseite reicht, und
innerhalb eines Blocks gab es die Transaktionen nur als Kachelgrafik -- schoen
auf einen Blick, aber nicht der Reihe nach lesbar.

**`TxList`** zeigt dieselben Daten als Liste, 25 je Seite: Nummer im Block,
TXID, Betrag, Groesse, Gebuehrenrate und -- wenn die Kacheln nach Art gefaerbt
sind -- denselben Farbpunkt. Es wird **nichts nachgeladen**: `blocktiles` und
`projectedtiles` liefern je Kachel schon eine Zeile
`[txid, vsize, fee, value, rate]`. Ist die Liste ausgeduennt (`tileStep > 1`
bei mehr als 8000 Transaktionen), steht das dabei -- sonst zaehlt jemand mit
und wundert sich.

**`BlockHistory`** blaettert die Kette rueckwaerts, fuenfzehn Bloecke je Seite.
Der Daemon kann das laengst: `blocks/recent` fuer die neuesten,
`blocks/<hoehe>` fuer die fuenfzehn davor (am 02.09.2026 nachgeprueft:
`/v1/blocks/965000` liefert 965.000 bis 964.986). Geblaettert wird mit den
**echten Hoehen** der angezeigten Bloecke, nicht mit einer angenommenen
Seitenlaenge.

### Der Fehler, den die Historie ans Licht gebracht hat

Die neue Seite blieb leer. Nachgemessen statt geraten -- eine Debugzeile mit
den Groessen aller Kinder der Spalte:

    kind=[history] bodyH=3352
    home sichtbar=false h=1814
    hist sichtbar=true h=707 w=1072 y=2645
    ldBlock y=58 h=2571

**Ein abgeschalteter `Loader` behaelt die Hoehe seines letzten Inhalts.** Die
Blockansicht war 2571 Pixel hoch; danach stand ein ebenso hohes Nichts vor der
naechsten Seite. Eine `Column` laesst nur **unsichtbare** Kinder aus, keine
leeren -- `active: false` allein genuegt also nicht.

Der Fehler ist aelter als die Historie und traf jeden Wechsel von einer
Blockansicht zu einer anderen Seite. Behoben mit einer Zeile an allen vier
Loadern:

    visible: active

**Merksatz: `active` steuert den Inhalt, `visible` die Flaeche. Wer einen
Loader in einen Positionierer haengt, braucht beides.**


## Einstellungen mit denselben Reitern (`SettingsView.qml`)

Bisher gab es Einstellungen nur als Tastenkuerzel und im DMS-Plugin. Jetzt hat
jedes Fenster einen Reiter "Einstellungen", und der ist genauso gegliedert wie
die Ansichten: Allgemein, Feed, Uhr, Miner, Explorer, Wallet.

**Die Werte gehoeren dem Wirt, nicht der Ansicht.** `SettingsView` liest `opts`
und meldet jede Aenderung ueber `changed(key, value)` zurueck; wo sie liegen
bleiben, entscheidet der Wirt: die eigenstaendige Anwendung ueber `Settings`
aus `QtCore`, das Quickshell-Fenster in `view.json`, der Dashboard-Tab in den
Plugin-Einstellungen von DMS. So gibt es **eine** Oberflaeche und drei
Ablagen, statt dreimal derselben Oberflaeche.

Die Bedienelemente sind selbstgebaut (`Schalter`, `Wahl`, `Regler`, `Haken`) --
`QtQuick.Controls` waere eine weitere Abhaengigkeit, und der Rest des Programms
kommt mit `import QtQuick` aus. Das soll so bleiben, damit dieselben Dateien im
Fenster, im DMS-Plugin und spaeter unter Android laufen.

**Falle dabei:** in einem `Row` darf ein Kind kein `anchors.fill` haben. Die
Beruehrungsflaeche eines Kaestchens braucht aber genau das -- also ein `Item`
um die Zeile herum, `Row` darin, `MouseArea` daneben.

**Mehrfachauswahl: leere Liste heisst alle.** Wer keine Kennzahl abwaehlt,
speichert eine leere Liste, und die zeigt alles. Eine spaeter hinzukommende
Kennzahl erscheint dadurch von selbst, statt bei allen Bestandsnutzern
stillschweigend zu fehlen.

### Die Wallet-Ansicht ist zugesperrt

Der Reiter "Wallet" **erscheint gar nicht**, bis er in den Einstellungen
ausdruecklich eingeschaltet wird -- nach einer Warnung, die dasteht und gelesen
werden will. Grund ist nicht das Guthaben: watch-only ist es vollstaendig
geschuetzt, das Programm kann nicht signieren. Grund ist die **Verkettung**.
Es ist der einzige Teil des Programms, bei dem der Benutzer etwas ueber sich
preisgibt, und das gehoert vor die Tuer und nicht dahinter.

Der Schalter gilt in allen drei Wirten. Wird er ausgeschaltet, waehrend die
Ansicht offen ist, springt das Fenster zurueck.

### Was die Einstellungen jetzt koennen

    Allgemein   Deckkraft, Kachelgroesse, Startansicht
    Feed        Farbe (Alter/Gebuehr/Art), Groesse, Blockangaben, Legende,
                Trennlinie, Weichzeichnung
    Uhr         welche Kennzahlen, Waehrung (Euro/Dollar), Balken
    Miner       welche Kennzahlen
    Explorer    Farbe der Kachelgrafiken
    Wallet      der Schalter samt Warnung

**Moscow Time** ist dazugekommen: wie viele Satoshi es fuer eine Einheit der
Waehrung gibt (`1e8 / Kurs`). Die Zahl steigt, wenn der Kurs faellt -- sie
misst Bitcoin in Geld statt Geld in Bitcoin, und genau darum geht es dabei.

### Noch offen

Ein **Kursverlauf** mit Schieber (wie bei einer Boerse) braucht eine Datenreihe,
die der Daemon bisher nicht holt -- `/api/v1/historical-price` waere die
Quelle. Ebenso die **freie Waehrungswahl**: geliefert werden zurzeit nur Euro
und Dollar. Und die **Wahl der Datenquelle** je Ansicht ist noch nicht
eingebaut; umgestellt wird bis auf Weiteres ueber `host` in
`~/.config/orangedeck/sources.json`, was den ganzen Feed umzieht.


## Die Einstellungen, ausgebaut (02.09.2026, zweiter Durchgang)

Jeder Reiter hat jetzt seine eigenen Einstellungen, und dazu einen Reiter
"Allgemein" fuer alles, was ueberall gilt.

### Waehrung: sieben statt zwei

Der WebSocket liefert **sieben** Kurse in derselben Nachricht mit -- USD, EUR,
GBP, CAD, CHF, AUD, JPY. Der Daemon warf fuenf davon weg. Sie kosten nichts
extra, also liegen jetzt alle im Zustand, und die Waehrung ist eine
Einstellung.

Umgerechnet wird an **einer** Stelle: `money.js` kennt Zeichen, Namen, Kurs und
das Ausschreiben grosser Betraege. Vorher stand das Euro-Zeichen an fuenf
Stellen im Quelltext. Fehlt die gewaehlte Waehrung im Zustand, wird der Reihe
nach ausgewichen -- lieber eine andere Waehrung als ein Strich.

### Was sich jetzt ein- und ausblenden laesst

    Allgemein   Waehrung, Sprache, Deckkraft, Kachelgroesse, Startansicht
    Feed        Farbe, Groesse, Kopfzeile, Fusszeile, Blockangaben,
                Kachelgrafik des Blocks, Legende, Trennlinie, Weichzeichnung
    Uhr         fuenf Kennzahlen einzeln, Schwierigkeit/Halving,
                Hashrate-Kurve, Uhrzeit
    Miner       sechs Kennzahlen einzeln, Verlaufskurve, Rechenwerke,
                Bestenliste
    Explorer    Farbe, fuenf Abschnitte der Startseite, vier Tafeln,
                geplanten Block mitverfolgen
    Wallet      der Schalter samt Warnung

### Falle: QSettings kann keine leere Liste

Eine leere Liste wird als `@Invalid()` geschrieben und als **ungueltiger
Wert** zurueckgelesen -- nicht als leere Liste und nicht als `undefined`. Die
Ansicht bekam dann etwas, das weder `length` noch `indexOf` hat, und der Filter
lief auf einen Fehler.

Zwei Griffe dagegen:

1. Die Anwendung legt Listen als **Zeichenkette** ab (`explorerPartsRaw`) und
   spaltet sie beim Lesen. Das Quickshell-Fenster braucht das nicht -- JSON
   kann leere Listen.
2. Jeder Filter prueft nicht nur auf leer, sondern auch darauf, **ob ueberhaupt
   eine Liste vorliegt**:

       if (!f || !f.length || typeof f.indexOf !== "function")
           return true;      // heisst: alles zeigen

**Merksatz: eine leere Liste ueberlebt QSettings nicht.** Wer Mehrfachauswahl
speichert, speichert eine Zeichenkette.

### Sprache: bewusst nicht eingebaut

In den Einstellungen steht die Zeile, aber mit nur einem Eintrag. Eine
Umschaltung muesste rund 300 Textstellen in fuenfzehn Dateien erfassen. Das ist
ein eigener Arbeitsgang -- und halb uebersetzt waere schlechter als gar nicht:
ein englisches Einstellungsfenster vor deutschen Ansichten hilft niemandem.

Der Weg dafuer stuende fest: eine `strings.js` mit `t(key, lang)` und ein
`lang` an jeder Ansicht, so wie schon `textColor` und `uiFont` durchgereicht
werden. Ein Singleton ginge nicht ohne Weiteres, weil dieselben Dateien in drei
Wirten laufen und ein `qmldir` nur im CMake-Modul entsteht.


## Dreizehn Sprachen (`strings.js`)

Die Oberflaeche spricht Deutsch, Englisch, Spanisch, Franzoesisch,
Italienisch, Niederlaendisch, Polnisch, Portugiesisch (Portugal **und**
Brasilien getrennt), Tschechisch, Russisch, Japanisch und Chinesisch --
dieselbe Auswahl, die auch mempool.space fuehrt, und dieselbe Wortwahl:
"Mempool", "Hashrate", "Coinbase" und "RBF" bleiben ueberall stehen, weil sie
in jeder Sprache so heissen.

**Portugiesisch ist zweigeteilt**, weil sich die beiden Fassungen dort
unterscheiden, wo diese Oberflaeche redet: "Definições" gegen "Configurações",
"a carregar" gegen "carregando", "deteta" gegen "detecta". Eine gemeinsame
Spalte haette in einem der beiden Laender falsch geklungen.

### Aufbau

Ein Schluessel je Textstelle, dahinter eine Zeile mit einem Eintrag je Sprache
in der Reihenfolge von `LANGS`:

    "blockHeight": ["Blockhöhe", "Block height", "Altura del bloque", …]

Kompakter als geschachtelte Objekte, und eine neue Sprache ist eine Spalte
statt dreihundert neuer Zeilen. Rund 300 Schluessel.

**Neue Sprachen kommen hinten dazu**, nicht an ihren alphabetischen Platz --
sonst muesste jede der dreihundert Zeilen umgeschrieben werden. Wie sie in den
Einstellungen erscheinen, steht getrennt in `LANG_ORDER`: dort stehen sie so,
wie man sie sucht, und die beiden portugiesischen Fassungen nebeneinander.

### Warum eine Funktion und kein Singleton

`t(key, lang)` ist eine **reine Funktion**. Gibt man `lang` mit, haengt die
Bindung daran und wird beim Umschalten von selbst neu gerechnet -- ohne
Neustart, ohne Signal.

Ein QML-Singleton waere der uebliche Weg, geht hier aber nicht: dieselben
Dateien laufen in drei Wirten, und ein Singleton braucht ein `qmldir`, das nur
im CMake-Modul entsteht. Also bekommt jede Ansicht `lang` durchgereicht, genau
wie `textColor` und `uiFont` auch.

### Zahlen gehoeren zur Sprache

Das ist keine Kosmetik: **"1.234" heisst je nach Sprache tausendzweihundert
oder eins Komma zwei.** `Tr.group(n, lang)` und `Tr.fixed(n, stellen, lang)`
setzen Tausender- und Dezimaltrenner nach Sprache -- Punkt im Deutschen und
im Portugiesischen, Komma im Englischen, **schmales Leerzeichen** im
Franzoesischen, Russischen, Polnischen und Tschechischen.

Falle dabei: das schmale Leerzeichen ist U+202F, kein gewoehnliches. Wer die
Bedingung spaeter erweitert und dabei ein normales Leerzeichen tippt, trifft
die Zeile nicht -- genau das ist beim Nachtragen von Polnisch passiert, und
der Fehler faellt erst am Bildschirm auf.

Vorher stand `.toFixed(2).replace(".", ",")` an vierzig Stellen im Quelltext.

### Zwei Fallen

**Ein `.import` in einer `.pragma library` traegt nicht.** `money.js` sollte
`strings.js` einbinden, um Betraege zu schreiben -- das Laden scheitert dann
**stumm**: die Datei meldet nur "Script … unavailable", und zwar erst zur
Laufzeit, nicht beim Uebersetzen. Aufgeloest, indem die Abhaengigkeit umgedreht
wurde: `money.js` kennt nur noch Kurs und Zeichen, geschrieben wird in
`strings.js`.

**Reguläre Ausdruecke taugen nicht zum Umbauen von Quelltext.** Der Versuch,
`x.toFixed(2).replace(".", ",")` maschinell durch `Tr.fixed(x, 2, lang)` zu
ersetzen, hat in acht Dateien Ausdruecke zerrissen -- der Ausdruck vor
`.toFixed` laesst sich mit einem Muster nicht zuverlaessig abgrenzen. Acht
Stellen mussten von Hand zurechtgerueckt werden. Beim naechsten Mal: die
Fundstellen auflisten und einzeln ersetzen.

### Was nicht uebersetzt wird

Einheiten und Eigennamen: `sat/vB`, `vByte`, `MB`, `BTC`, `₿`, `EH/s`, `°C`,
`Mempool`, `Hashrate`, `Coinbase`, `RBF`, `SegWit`, `Nonce`, `Sigops`,
`CoinJoin`. Ausnahme sind Umdrehungen je Minute: im Deutschen `U/min`, sonst
`RPM`.


## Schriften an einer Stelle (`fonts.js`)

`"monospace"` und `"sans-serif"` sind **fontconfig-Namen**. Unter Linux loest
fontconfig sie auf die vom Benutzer eingestellte Standardschrift auf, unter
Windows und macOS gibt es sie nicht -- dort faellt Qt auf irgendeine Schrift
zurueck, an einer Monospace-Stelle womoeglich auf eine proportionale, und dann
stehen Hashes und Betraege nicht mehr untereinander.

**`font.families` gibt es in QML nicht.** Der Wertetyp `font` kennt nur
`family`; Qt 6.11.2 lehnt die Zuweisung mit "Cannot assign to non-existent
property" ab. Der Fehler kostete einen ganzen Bau, weil er stumm blieb -- siehe
`QT_ASSUME_STDERR_HAS_CONSOLE` weiter oben.

`fonts.js` waehlt deshalb aus, statt aufzuzaehlen: auf Windows und macOS die
erste Schrift aus einer Liste, die `Qt.fontFamilies()` wirklich kennt, sonst
weiter der generische Name. **Unter Linux aendert sich damit nichts.**

Zwei Feinheiten:

- `Qt.fontFamilies()` liest die ganze Schriftdatenbank. Das gehoert nicht in
  eine Bindung, die je Zeile neu rechnet -- einmal ausgerechnet, dann gemerkt.
- Auf der Leinwand (`ctx.font`) gilt die CSS-Kurzschreibweise. Ein Name mit
  Leerzeichen gehoert dort in Anfuehrungszeichen, ein generischer ausdruecklich
  **nicht**: in Anfuehrungszeichen waere er ein gesuchter Schriftname statt
  einer Gattung, und dann findet Qt ihn nicht.


## Der CVD im Markt

Kauf minus Verkauf, aufsummiert, unter dem Kurs. Er beantwortet die Frage, die
eine Kerze offen laesst: **wer hat den Kurs bewegt**. Steigt der Kurs und
faellt der CVD, kauft niemand -- es wird nur nicht mehr verkauft.

Der Fund, an dem alles haengt: **die Sekundenfaecher des Dienstes werden fuer
die Kerzen gar nicht benutzt.** `Market.kerzen()` steht da, wird aber nirgends
gerufen -- gezeichnet wird immer aus den fertigen Kerzen von Binance. Die
Live-Stroeme speisen nur das Band, die Trade-Zaehlung und die
Verbindungsanzeige.

Der Kauf-Verkauf-Unterschied musste also aus den Boersenkerzen kommen, und er
kommt von dort: **Feld 9 einer Binance-Kerze ist das Volumen der Trades, die
in den Brief gegangen sind**, der Rest ist verkauft. Damit traegt der CVD jeden
Zeitraum von einer Stunde bis 2017, ohne eine einzige neue Verbindung.

Aufsummiert wird ueber das **gezeigte Fenster**, beginnend bei null. Ein
absoluter Stand haette keine Bedeutung: die Reihe faengt dort an, wo die Boerse
anfaengt, und niemand liest einen Wert von 2017 ab. Verglichen wird immer
innerhalb des Bildes.

Ein eigener Umschalter statt beides uebereinander: die Balken zaehlen von null
nach oben, der CVD hat seine Null in der Mitte. Zwei Massstaebe in einer
Flaeche liest niemand. Steht der CVD unten, nennt die Ablesezeile seinen Wert
am Zeiger -- sonst laege dort eine Linie ohne Achse.

Zwei Sachen fielen dabei mit ab:

- Die Volumenbalken zeigen jetzt auch bei Boersenkerzen Kauf und Verkauf
  getrennt. Die Aufteilung war vorher den Live-Faechern vorbehalten, und ein
  einzelner nach Richtung eingefaerbter Balken sagt weniger.
- Die Waehrungsumrechnung im Dienst **schnitt die Mengen ab**: sie baute jede
  Kerze aus sechs Feldern neu. In Euro waere der CVD ausgefallen.


## Der Schieber der Zeitachse zieht ohne Verzoegerung

Die Zahl, die den ganzen Entwurf bestimmt: **ein frisches Fenster kostet 1,1
bis 1,5 Sekunden**, weil der Dienst dafuer bei Binance nachfragt. Gepuffert
sind es 4 ms. Am Schieber liegen neun Jahre auf einer Leiste -- zehn
Bildpunkte sind schnell hundert Tage, und jede Stelle waere ein eigenes
Fenster. **Waehrend des Ziehens nachzuladen ist damit ausgeschlossen**, auch
mit jeder Bremse: sechzig Bilder je Sekunde gegen 1,2 Sekunden Antwortzeit
geht nicht auf, und Binance haette etwas dagegen.

Also muss das Bild aus etwas kommen, das schon da ist.

**`/market/overview` liefert die ganze Geschichte als Tageskerzen** -- rund
3.300 Stueck, 214 kB. Binance gibt hoechstens 1000 Kerzen je Abfrage, also
vier Seiten; der Dienst haelt sie eine halbe Stunde (erster Abruf 6 s, danach
18 ms). Bewusst ein **eigener Weg** und nicht Teil von `/market`: das wird
jede Sekunde geholt, die Uebersicht aendert sich einmal am Tag.

Die Ansicht holt sie einmal je Waehrung und zeichnet waehrend des Ziehens
daraus. `sicht` liefert dann `vorschauKerzen` statt der geholten Kerzen --
weil alle Geometrie an `sicht` haengt, genuegt dieser eine Griff.

**Die Vorschau sagt, dass sie eine ist**: gedaempft (`globalAlpha 0.55`) und
als Linie, auch wenn sonst Kerzen stehen. Tageskerzen in einem Fenster, das
Viertelstunden zeigt, waeren eine Genauigkeit, die die Daten nicht hergeben.
In der Ablesezeile steht "Uebersicht" und das Datum, auf dem man gerade steht.

Ein Tag traegt kein Fenster von 24 Stunden. Bleiben weniger als drei Kerzen
uebrig, zeigt die Vorschau die Umgebung -- zwei Monate. Ab zwei Monaten
Fensterbreite deckt sie sich mit dem, was nach dem Loslassen kommt.

### Zwei Fehler, die dabei ans Licht kamen

**`drag.target` zerreisst die Bindung.** Ein `MouseArea` mit
`drag.target: griff` schreibt `griff.x` unmittelbar -- und damit ist
`x: schieber.griffX` fuer immer weg. Der Griff folgte dem Fenster danach nicht
mehr: ein Klick neben den Griff verschob das Bild, aber nicht den Griff. Nach
jeder Geste wird sie mit `Qt.binding` neu geknuepft. **Das gilt fuer jede
gezogene Eigenschaft in QML**, nicht nur hier.

**Die Zeitachse las den gewaehlten Zeitraum statt des gezeigten.** `uhrzeit()`
entschied anhand von `sichtSekunden`, ob Uhrzeit, Datum oder Monat unter dem
Bild steht. In der Vorschau stehen zwei Monate im Bild, waehrend das Fenster
auf 24 Stunden steht -- also standen Uhrzeiten unter einem Bild von zwei
Monaten. Richtig ist die Spanne, die `sicht` **wirklich** abdeckt
(`gezeigteSekunden`); das stimmt fuer den Zoom genauso.

### Pruefstand ohne Maus

`ui/qml/PruefstandMarkt.qml` zeichnet den Markt allein, mit einem Stummel als
`feed`, und schaltet die Vorschau ueber die Befehlszeile -- damit laesst sich
im Bild nachsehen, was beim Ziehen passiert, ohne dass eine Maus im Spiel
sein muss. **Pruefstaende sind Werkzeug, kein Bestandteil**:
`tools/install-links.sh` nimmt `Pruefstand*` von der Verteilung aus.


## Die Einheit richtet sich nach der Groesse, nicht nach der Teilbarkeit

Im Feld des eigenen Zeitraums stand nach dem Zoomen "12215m". Das ist richtig
und trotzdem unbrauchbar -- niemand rechnet das in achteinhalb Tage um.

Der Grund war die Auswahlregel: `eigenText()` fragte, ob die Sekunden **glatt
teilbar** sind (`sek % 86400 === 0`), und nur dann kam die passende Einheit.
Beim Zoomen ist keine Zahl glatt, also fiel jede Spanne bis auf die Minuten
durch. Getippte Werte wie "7d" sahen gut aus, gezoomte nie.

Jetzt entscheidet die Groesse: Minuten unter einer Stunde, Stunden bis zwei
Tage, Tage bis zu einem Jahr, danach Jahre. Gerundet wird **nur die
Anzeige** -- ab zehn ganzzahlig, darunter eine Nachkommastelle, und die faellt
weg, wenn sie eine Null waere. Der Wert dahinter bleibt genau, das Bild
springt beim Zoomen also nicht.

Zwei Feinheiten, beide am Pruefstand gefunden:

- **Die erste Schwelle liegt knapp unter der Stunde, nicht auf ihr.** Bei
  genau 3600 rundete eine Spanne von 3599 Sekunden auf "60m" statt auf "1h".
  Wo gerundet wird, muss die Schwelle vor der Rundungsgrenze liegen.
- **Wochen kommen nicht mehr vor**, obwohl das Feld sie als Eingabe weiter
  annimmt. Die Zeitraeume der Ansicht heissen 1h, 12h, 24h, 7d, 30d und 1y --
  in dieser Sprache gibt es keine Wochen, und "26w" neben "30d" waeren zwei
  Masseinheiten fuer dieselbe Groessenordnung. Getipptes "12w" wird angenommen
  und als "84d" zurueckgegeben.

`ui/qml/PruefstandZeittext.qml` faehrt zwanzig Spannen von einer Minute bis
neun Jahre durch, zeigt die Beschriftung und liest sie mit `eigenSekunden()`
wieder ein -- die Abweichung liegt ueberall unter einem Prozent. Dass die
Ausgabe im Terminal ankommt, liegt an `QT_ASSUME_STDERR_HAS_CONSOLE=1`.


## Liquidationen und Positionierung (`MarketLiq.qml`)

Der zweite Unterreiter im Markt beantwortet zwei Fragen, die der Kurs nicht
beantwortet: **wie stehen die anderen** und **wo mussten Positionen
aufgeben**.

### Warum ein eigener Reiter und keine Spur unter dem Kurs

Der CVD laeuft von links nach rechts, weil er eine Frage ueber die **Zeit**
beantwortet. Das Liquidations-Histogramm liegt quer, weil es eine Frage ueber
den **Preis** beantwortet. Ein Balken auf Kurshoehe passt in kein Feld, das
eine Zeitachse hat -- deshalb eine eigene Flaeche, nicht ein dritter Eintrag
im Umschalter unten.

Der Umschalter steht **vor** dem Kurs in derselben Zeile und kostet damit
keine eigene Hoehe. Im Popout sind 409 Punkte alles, was es gibt.

### Bewusst keine Heatmap nach Art von Coinglass

Deren Bild ist **gerechnet, nicht gemessen**: aus offenem Interesse und
*angenommenen* Hebeln (5x, 10x, 25x, 50x, 100x) wird hochgerechnet, wo
Liquidationen laegen. Die echten Liquidationspreise offener Positionen kennt
nur die Boerse, und niemand veroeffentlicht sie. Hier steht deshalb nur, was
wirklich passiert ist: weniger Bild, aber jede Angabe belegbar.

### Was frei zu haben ist -- und was nicht

Gemessen am 04.09.2026:

| | |
|---|---|
| Binance Futures **WebSocket** | Handshake 101, danach **0 Bytes in 12 s** |
| Binance Futures **REST** | antwortet normal |
| OKX `liquidation-orders` | liefert, alle Swaps auf einmal |
| Bybit `allLiquidation.BTCUSDT` | liefert |
| Bybit `liquidation.BTCUSDT` | `error:handler not found` -- gibt es nicht mehr |
| BitMEX `liquidation` | verbindet, trennt nach 8 s |
| Deribit `trades.*.raw` | braucht Anmeldung |

Die Binance-Messung ist eindeutig: auch `markPrice@1s`, das jede Sekunde
sendet, brachte null Nachrichten, waehrend der Spot-Strom im selben Test 376
lieferte -- auf Byte-Ebene gegengeprueft, mit und ohne Browser-Kennung.
**Gesperrt ist der Strom, nicht die Boerse**: das Long/Short-Verhaeltnis von
`fapi.binance.com` kommt an.

### Vier Fallen, alle gemessen

**Ein Liquidationsstrom ist minutenlang still.** Ein Handelsstrom traegt sich
durch seinen eigenen Verkehr; hier passiert oft eine Viertelstunde nichts.
Bybit trennt eine untaetige Verbindung, und **ohne Ping merkt man das nicht
einmal** -- die Leseschleife laeuft ins Nichts. Der erste Versuch hier meldete
"fuenf Minuten keine Liquidation"; in Wahrheit war die Verbindung nach
dreissig Sekunden weg. `run_liquidationen` ist deshalb nicht `run_market` mit
anderem Parser, sondern hat einen eigenen Herzschlag.

**Bybit verwirft den ganzen Abo-Antrag, wenn ein Thema darin ungueltig ist.**
`allLiquidation` **und** `liquidation` zusammen angefragt: `success:false`,
und zwar fuer beide. Themen einzeln abonnieren oder wenigstens einzeln
pruefen.

**`sz` bei OKX sind Kontrakte, keine Bitcoin.** Fuer BTC-USDT-SWAP ist ein
Kontrakt 0,01 BTC (`ctVal` aus `/api/v5/public/instruments`, `ctMult` 1). Wer
das uebersieht, zeigt hundertfach zu grosse Betraege. Und der Filter
`instFamily` wird von OKX **stillschweigend ignoriert** -- die Bestaetigung
kommt ohne ihn zurueck, und es kommen weiter RIVER, CHIP und DASH. Gefiltert
wird auf `instId`.

**Die Seite steht bei beiden Boersen fuer die Position, nicht fuer die
Zwangsorder.** Das stand hier erst falsch herum und fiel nur auf, **weil eine
zweite Quelle danebenlag**: waehrend einer Kaskade meldete OKX durchgehend
Longs, Bybit durchgehend Shorts -- bei fallendem Kurs, wo nur Longs
liquidiert werden. Am rohen Strom nachgesehen: Kurs faellt von 78.719 auf
78.651, jede Bybit-Nachricht traegt `S: "Buy"`, und die Liquidationspreise
(78.460, 78.454, ...) liegen **unter** dem Markt -- so wird ein Long
glattgestellt. Mit nur einer Quelle waere die Anzeige jahrelang verkehrt
herum gestanden.

### Auch die leeren Preisstufen gehen mit

Der Dienst schickt alle 24 Stufen, auch die ohne Treffer. Wer nur die vollen
schickt, macht aus der Preisachse eine **Liste**: die Oberflaeche verteilt
zwei Treffer ueber die halbe Flaeche, und die Hoehe im Bild sagt nichts mehr
ueber den Preis. Eine Achse hat gleiche Abstaende oder sie ist keine.

Die Beschriftung der Achse wird ausgeduennt, nicht verkleinert: `jedeWievielte`
rechnet aus der Zeilenhoehe, wie viele Beschriftungen nebeneinanderpassen --
lieber jede dritte lesbar als jede unleserlich. Die Stufe am laufenden Kurs
steht immer da, sie ist der Bezugspunkt.

### Gehalten wird nach Zeit, und mitgeschrieben

An einem ruhigen Tag sind es ein paar Dutzend Liquidationen, in einer Stunde
Panik tausende. Ein Ring fester Laenge deckte im ersten Fall Tage ab und im
zweiten Minuten -- also zwei Tage nach Zeit, mit `LIQ_KEEP` nur als Notbremse
gegen Speicherwuchs.

**Und sie werden mitgeschrieben** (`liquidations.json` im Cache-Verzeichnis,
alle dreissig Sekunden, aber nur wenn sich etwas geaendert hat). Der Grund ist
nicht Bequemlichkeit: Liquidationen gibt es **nirgends rueckwirkend zu
kaufen**. Ein Neustart ohne diese Datei waere echter Datenverlust, kein
blosses Neuladen.

Das Aufraeumen alter Eintraege schneidet nur vorn ab (`popleft`, solange der
aelteste zu alt ist). Das genuegt, weil die Marken im Wesentlichen der Reihe
nach kommen; eine Marke mit altem Zeitstempel, die hinten angehaengt wird
(OKX schiebt beim Verbinden Zurueckliegendes nach), bleibt bis `LIQ_KEEP`
greift. Gefiltert wird ohnehin beim Lesen und beim Laden, das Bild stimmt
also -- es liegt nur mehr im Speicher als noetig.

### Das Verhaeltnis ist ein Konten-Anteil

Alle drei Boersen nennen den Anteil der **Konten**, nicht des Kapitals. "53 %
long" heisst, dass jedes zweite Konto long steht, nicht dass dort das halbe
Geld liegt. Der Satz steht in der Ansicht, weil man es sonst als Uebergewicht
liest.

Dass die drei auseinanderliegen (04.09.2026: OKX 50,7 %, Bybit 53,4 %,
Binance 50,2 %), ist kein Fehler, sondern der Punkt -- es sind drei
verschiedene Nutzerschaften. Ein Mittelwert daraus waere eine Erfindung,
deshalb stehen sie einzeln.


## Die Liquidations-Heatmap (`MarketHeat.qml`) -- ein Modell, kein Messwert

Der dritte Unterreiter zeigt, was Coinglass unter diesem Namen zeigt:
waagerechte Baender, je heller desto mehr, die dort abbrechen, wo der Kurs
sie durchschritten hat.

**Der Unterschied zum Reiter daneben ist grundsaetzlich.** "Liquidationen"
zeigt, wo liquidiert *wurde* -- gemessen, aus dem eigenen Strom. "Heatmap"
zeigt, wo Positionen *laegen* und wo sie sterben *wuerden*. Die hellen
Baender liegen deshalb **vor** dem Kurs, und eine Messung kann das
prinzipiell nicht: sie kennt keine Zukunft.

### Was Coinglass verkauft, und was frei ist

Nachgesehen am 04.09.2026:

| | |
|---|---|
| `futures/liquidation/heatmap/model1` | **Professional-Tarif, 699 $/Monat** |
| `futures/liquidation/liquidation-order` (7 Tage) | Standard-Tarif, 299 $/Monat |
| ohne Schluessel | `{"code":"401","msg":"API key missing."}` |
| Verlauf des offenen Interesses | **frei** bei Binance, OKX und Bybit |

Ihr eigenes Feld heisst `liquidation_leverage_data`, nicht
`liquidation_data` -- der Name sagt schon, dass darin gerechneter Hebel
steht und keine Ereignisse. Die Zutaten sind frei, also wird hier selbst
gerechnet.

### Der Gedanke in drei Schritten

1. **Waechst das offene Interesse, wurden Positionen eroeffnet** -- zum Kurs,
   der gerade galt. Faellt es, wurden welche geschlossen; das interessiert
   nicht.
2. Eine Long-Position mit Hebel L stirbt rund bei `Kurs * (1 - 1/L)`, eine
   Short bei `Kurs * (1 + 1/L)`. Die **Erhaltungsmarge ist weggelassen** --
   sie schoebe die Schwelle ein Stueck naeher an den Einstieg und ist je
   Boerse und Positionsgroesse verschieden.
3. **Ein Niveau lebt, bis der Kurs es durchschreitet.** Danach ist es
   abgeraeumt. Daher brechen die Baender im Bild dort ab, wo der Kurs war --
   das ist die Regel, an der man dem Modell beim Arbeiten zusehen kann.

### Zwei erfundene Annahmen, und warum sie oben stehen

`HEBEL_STUFEN` (5x 30 %, 10x 30 %, 25x 20 %, 50x 13 %, 100x 7 %) und
`LONG_ANTEIL` (0,5) sind **nicht gemessen**. Niemand veroeffentlicht, mit
welchem Hebel fremde Positionen laufen. Sie stehen deshalb als Konstanten
ganz oben, der Dienst schickt sie in der Antwort mit, und die Ansicht nennt
sie im Klartext -- neben einer Marke "SCHAETZUNG", die Teil der Ansicht ist
und keine Fussnote.

Das Konten-Verhaeltnis waere die naechstliegende Verfeinerung des
Long/Short-Splits. Es zaehlt aber **Konten und nicht Kapital** und waere
damit eine zweite Annahme auf der ersten.

### Grenzen, die aus den Daten kommen

**Dreissig Tage.** Binance haelt den Verlauf des offenen Interesses nur so
lange vor -- gemessen: `5m` reicht 1,7 Tage, `1h` 20,8 Tage, `1d` 30,0 Tage.

Der erste Anlauf **lehnte** ein laengeres Fenster ab und zeigte nur eine
Begruendung. Das war zu streng: der Nutzer hatte einen eigenen Zeitraum von
5,2 Jahren stehen und bekam damit eine leere Flaeche, ohne zu wissen, was er
tun soll. Jetzt wird **zurechtgeschnitten** -- gezeigt werden die letzten
dreissig Tage --, und die Antwort sagt es mit `clamped`, die Ansicht mit einer
Zeile in Akzentfarbe. Verschwiegen waere es eine Luege: Baender von dreissig
Tagen liest man sonst als Baender von fuenf Jahren.

**Merksatz: wo eine Grenze erreicht ist, zeigt man das Moegliche und nennt
die Grenze -- nicht nichts.**

### Aufwand

Das Rechnen kostet **5 ms** (96 Kerzen, 500 OI-Punkte). Teuer ist nur das
Holen des offenen Interesses (1,6 s), deshalb vier Minuten Puffer. Die
Antwort ist ein **duennes** Gitter: nur Zellen ueber 0,4 % des hoechsten
Werts -- 2.545 Zellen und 41 kB fuer 24 Stunden statt 64 mal 96 Zahlen, von
denen die meisten null sind.

Die Oberflaeche holt sie **einmal pro Minute und nur im Heatmap-Reiter**.
`/market` wird jede Sekunde geholt; ein gerechnetes Bild, das sich nur mit
dem offenen Interesse aendert, gehoert dort nicht hinein.

Gezeichnet wird mit einer **Wurzelkennlinie** (`^0.45`), nicht linear: die
Betraege gehen ueber drei Groessenordnungen, und linear waere alles ausser
der hellsten Zelle schwarz.

Die Spaltenzahl ist bewusst kleiner als beim Kurs: `raster_fuer` zielt auf bis
zu 400 Kerzen, hier ist aber jede Spalte 64 Zellen breit. 360 Spalten waren
249 kB fuer ein Bild, das in kein Popout so fein hineinpasst; mit rund 180
sind es 105 kB.

### Die Legende zeichnet aus derselben Funktion wie das Bild

`farbeFuer(anteil)` steht einmal da und wird von der Leinwand **und** vom
Farbstreifen der Legende benutzt. Zweimal dieselbe Rechnung waere eine
Legende, die irgendwann nicht mehr zum Bild passt -- und eine falsche Legende
ist schlimmer als keine. Dazu ein Strich in Weiss mit der Beschriftung
"Kurs", damit die Linie im Bild nicht geraten werden muss.


### Long oder Short steht in der **Lage**, nicht in der Farbe

Die naheliegende Frage: warum nicht rot fuer Long-Niveaus und gruen fuer
Short-Niveaus, wie im Reiter daneben?

Weil es nichts hinzufuegen wuerde. **Jedes ueberlebende Long-Niveau liegt
unter dem Kurs und jedes Short-Niveau darueber** -- und das ist keine
Konvention, sondern folgt zwingend aus der Abraeum-Regel des Modells:

> Ein Long-Niveau liegt unter seinem Eroeffnungskurs. Laege der Kurs heute
> darunter, muesste er es durchschritten haben -- dann waere es abgeraeumt
> und stuende nicht mehr im Bild. Fuer Shorts gilt es spiegelbildlich.

Nachgemessen statt nur behauptet: ueber 24 Stunden, 7 Tage und 30 Tage --
letzteres samt einem Kurssprung von 64.000 auf 78.000, der die Regel haette
brechen muessen, wenn sie nur eine Faustregel waere:

| Fenster | belegte Stufen | Lageregel falsch | Betrag falsch eingeordnet |
|---|---|---|---|
| 24h | 23 | 0 | 0,0 % |
| 7d | 26 | 0 | 0,0 % |
| 30d | 49 | 0 | 0,0 % |

Coinglass macht es aus demselben Grund einfarbig: ihre Schnittstelle liefert
je Zelle nur **einen** Betrag, keine Seite, und ihre eigene Anleitung sagt
"Cluster ueber dem Kurs sind Short-Liquidationen, darunter Long".

Was gefehlt hat, war nicht Farbe, sondern dass man die Regel **sieht**. Also
eine Marke auf Kurshoehe mit "▲ Shorts" darueber und "▼ Longs" darunter, und
derselbe Satz in der Legende. Die laufende Kurslinie sagt es ohnehin fuer
jeden Zeitpunkt -- was ueber ihr liegt, ist Short, was darunter liegt, Long.

**Nebenbei ein Argument gegen Rot/Gruen, das unabhaengig davon gilt:** rot
gegen gruen ist das schlechteste Paar fuer Farbenblinde. Wo die Information
schon in der Geometrie steht, ist sie dort besser aufgehoben.


## Der Griff des Schiebers liess sich nie ziehen

Am 04.09.2026 mit einem **echten Zeiger** gefunden, nachdem die Geste im
Standbild monatelang richtig aussah.

Im `schieber` stand die Klickflaeche ("neben den Griff geklickt: dorthin
springen") als **letztes** Kind, hinter dem Griff. In QML bekommt das spaetere
Geschwister die Ereignisse zuerst -- sie hat damit jeden Druck auf den Griff
geschluckt. Der Griff liess sich deshalb nie ziehen: **jede Geste wurde zu
einem Klick an der Loslass-Stelle**, samt Sprung.

Im Bild sah man es nicht, weil das Ergebnis plausibel ist -- man zieht nach
links, das Fenster wandert nach links. Nur eben in einem Satz statt
mitlaufend, und die ganze Vorschau aus der Tagesuebersicht wurde nie
angeschaltet.

Behoben, indem die Klickflaeche **vor** den Griff gezogen wurde. Danach am
Zeiger nachgesehen:

| | |
|---|---|
| waehrend der Geste | "Uebersicht 24.03.2020", gedaempfte Linie, Achse 24.01.–23.03.20 |
| nach dem Loslassen | 16-Stunden-Fenster vom 23.03.2020, echte Kerzen |

Dieselbe Familie wie die Falle vom 03.09.2026 (`z` ordnet nur unter
Geschwistern). **Merksatz: wer oben liegt, bekommt zuerst -- und "oben" ist in
QML, wer spaeter steht.**

### Was daraus fuers Pruefen folgt

Ein Standbild zeigt Geometrie, kein Verhalten. Alles, was an einem Zeiger
haengt -- Ziehen, Rad, Halten --, braucht einen Zeiger.

**Das geht ohne den Bildschirm des Nutzers**: `python-xlib` liegt hier
ohnehin, dazu `libXtst`. Damit lassen sich in den Xvfb, in dem ohnehin
abgebildet wird, echte Ereignisse einspeisen -- Bewegung, Druck, Rad, und
Abzuege **waehrend** eine Taste gehalten wird. `tools/xtest.py` ist der
Helfer dazu; er kann ausserdem das Fenster auf eine gewuenschte Groesse
setzen, womit sich die Breite des Popouts nachstellen laesst.

So gefunden: der Griff oben, und der Ueberlappungsfehler in der Kopfzeile
bei 695 Punkten Breite.


## Android im Emulator -- und das TLS-Loch, das er aufgedeckt hat

Am 04.09.2026 eingerichtet. Damit braucht der Android-Test **kein Telefon,
kein Kabel und kein `usermod`**.

### Der Aufbau

Alles war schon da ausser Emulator und Systemabbild:

    sdkmanager "emulator" "system-images;android-34;google_apis;x86_64"
    avdmanager create avd -n orangedeck -k "system-images;android-34;google_apis;x86_64" -d pixel_6
    emulator -avd orangedeck -no-window -no-audio -gpu swiftshader_indirect -port 5556

**Das x86_64-Abbild uebersetzt ARM.** `ro.product.cpu.abilist` meldet
`x86_64,arm64-v8a` -- unsere arm64-APK laeuft dort mit KVM, in voller
Geschwindigkeit. Ein arm64-Abbild waere nicht noetig.

Das APK muss **signiert** sein, sonst lehnt Android es ab
(`INSTALL_PARSE_FAILED_NO_CERTIFICATES`). Fuer den Emulator genuegt der
Debug-Schluessel:

    apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android ...

### Zwei Fehler im Bau

Der alte Baubaum zeigte auf `/home/satoshoe/Schreibtisch/btcfeed/app` -- den
Pfad gibt es seit der Umbenennung nicht mehr.

Und ohne `ANDROID_NDK_ROOT` richtet CMake **gar nicht auf Android aus**.
Die Meldung fuehrt dabei in die Irre: sie lautet "Target ... is not a valid
android executable target" und "only works on Module targets", waehrend die
Ursache eine leere ABI-Liste ist. Die muss stehen, **bevor** das Ziel angelegt
wird -- sonst wird daraus eine gewoehnliche ausfuehrbare Datei statt der
Bibliothek, die die Java-Huelle laedt.

### `dataSource` stand auf Android auf "daemon"

Der Dienst ist ein Benutzerdienst auf einem Linux-Rechner. Auf einem Telefon
kann er nicht laufen, und 127.0.0.1:21021 antwortet dort nie. Wer die App
frisch startete, bekam **"keine Verbindung zum Feed" als Willkommensgruss**
und musste die Einstellung erst finden. Der Direktbezug ist dort kein
Sonderfall, sondern der Regelfall -- jetzt die Vorgabe
(`Qt.platform.os === "android"`).

### Das eigentliche Loch: kein TLS

Danach stand die App immer noch leer da, und erst `logcat` sagte warum:

    qt.network.ssl: No functional TLS backend was found
    QSslSocket::connectToHostEncrypted: TLS initialization failed

**Qt liefert fuer Android kein OpenSSL mit.** Ohne es ist die App auf einem
Geraet vollstaendig funktionslos -- mempool.space spricht nur https und wss.
Auf dem Schreibtisch faellt es nie auf, weil dort das System-OpenSSL benutzt
wird. Das APK war damit seit dem 02.09.2026 unbrauchbar, ohne dass es jemand
sehen konnte.

`tools/openssl-android.sh` baut es aus dem **offiziellen Quelltext**
(openssl.org, 3.5.8 LTS), Pruefsumme **vor** dem Auspacken gegen die Angabe
des Projekts. Qts eigene Doku verweist auf vorkompilierte Bibliotheken von
Dritten; die wandern dann in eine veroeffentlichte App und lassen sich kaum
pruefen. Das passt nicht zu dem, was fuer die Wallet-Ansicht gilt.

### Die Namen sind nicht frei waehlbar

Beim ersten Anlauf lagen `libssl.so` und `libcrypto.so` im APK -- und Qt fand
sie trotzdem nicht. **Das TLS-Plugin sucht `libssl_3.so` und
`libcrypto_3.so`**; der Name haengt an `ANDROID_OPENSSL_SUFFIX`, dessen
Vorgabe `_3` ist. Ein leerer Wert der Variablen hilft nicht: Qt nimmt dann
wieder die Vorgabe.

Umbenennen waere die naheliegende Abkuerzung und eine schlechte: SONAME und
`NEEDED` blieben auf den alten Namen stehen. Man muesste beides mit
`patchelf` nachziehen -- oder **beide** Namenspaare mitliefern, und dann
laegen zwei OpenSSL-Instanzen im selben Prozess, mit getrennten
Fehlerschlangen und getrenntem Zufallszustand. Bei einer Kryptobibliothek ist
das keine Kleinigkeit.

Deshalb wird der **erzeugte Makefile umgeschrieben, bevor gebaut wird**.
Danach stimmt alles von selbst:

    libcrypto_3.so   SONAME=libcrypto_3.so
    libssl_3.so      SONAME=libssl_3.so   NEEDED=libcrypto_3.so

**Und `build-android/android-build` muss vor dem Neupacken weg.**
androiddeployqt raeumt dort nicht auf: nach dem Umbenennen lagen beide Paare
im APK, genau der Zustand, den die ganze Muehe vermeiden sollte.

### Ergebnis

Android 14, Direktbezug, kein Dienst: Block 965.505, 93.592 im Mempool,
5,34 sat/vB, die Halde faellt voll. APK 52 MB, null TLS-Meldungen.

Eine Beobachtung fuer spaeter: auf dem hohen, schmalen Bildschirm steht die
Halde als schraege Flaeche statt als Rechteck. Das ist keine Fehlfunktion,
aber ein Seitenverhaeltnis, das die Packung so noch nicht gesehen hat.


## Zwei Flatpak-Bauplaene, und warum es zwei sein muessen

Bis zum 04.09.2026 gab es nur einen, und der baute aus dem Arbeitsverzeichnis
(`type: dir`, `path: ../..`). Der Kommentar darin nannte den Grund: *solange
es kein oeffentliches Verzeichnis gibt.* **Diese Bedingung ist seit dem
03.09. hinfaellig** -- das Repo ist oeffentlich --, der Bauplan war es aber
noch.

Zwei Dinge waeren daran gescheitert:

- **Flathub nimmt so einen Bauplan nicht an.** Dort muss die Quelle ein
  festgenagelter Commit sein. Ein Zweigname genuegt nicht: dann baut jeder
  Lauf etwas anderes, und niemand kann sagen, welcher Quelltext in einem
  ausgelieferten Paket steckt.
- **Ein CI-Laeufer hat kein Arbeitsverzeichnis.** Er klont das Repo; `path:
  ../..` zeigt dort ins Leere. Ein Windows- oder macOS-Workflow waere sofort
  darauf gelaufen, ebenso ein Flatpak-Bau in Actions.

Jetzt liegen zwei nebeneinander:

| | |
|---|---|
| `store._21rebel.orangedeck.dev.yml` | zum **Arbeiten** -- aus dem Verzeichnis, Aenderung sofort sichtbar, ohne Push |
| `store._21rebel.orangedeck.yml` | zum **Ausliefern** -- aus dem oeffentlichen Repo, auf einen Commit festgenagelt |

**Den kanonischen Namen traegt der zum Ausliefern**, und das ist kein Zufall:
Flathubs Pruefer verlangt, dass die Datei so heisst wie die Kennung
(`appid-filename-mismatch`). Hiesse sie hier anders, muesste man sie vor der
Einreichung umbenennen -- ein Handgriff, den man vergisst, und dann kann die
eingereichte Datei von der geprueften abweichen. So ist sie byteweise
dieselbe.

**Wer einen aendert, muss den anderen mitziehen.** Der Hinweis steht in beiden
Dateien; eine gemeinsame Grundlage waere schoener, aber flatpak-manifest
kennt kein Einbinden.

Gegengeprueft am 04.09.2026: der Auslieferungs-Bauplan baut aus nichts als
Repo-Adresse und Commit durch (43 MB, `orangedeck`, `orangedeck-app`,
`orangedeck-launch`), und **Flathubs eigener Pruefer meldet keinen Fehler**:

    flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        manifest packaging/flatpak/store._21rebel.orangedeck.yml

Uebrig bleibt ein Hinweis: `org.kde.Platform 6.10` gibt es inzwischen. Ein
Wechsel ist nicht umsonst -- die Fassung von `layer-shell-qt` haengt an Qt
und ECM der Laufzeit (siehe der Kommentar im Bauplan), also muesste sie
mitziehen.

### Zwei Fallen dabei

**Die Skip-Liste vergisst man.** Sie zaehlt auf, was `type: dir` **nicht**
mitkopieren soll. Neue Baubaeume stehen nicht von selbst darin, und dann
wandern Gigabyte in jeden Flatpak-Bau -- `build-flatpak-repo`,
`build-android`, `build-openssl-android` sind jetzt drin. Dieselbe Luecke hat
am selben Tag 200 OSTree-Objekte ins Git-Repo gespuelt, weil `.gitignore` nur
`build-flatpak/` kannte und nicht `build-flatpak-repo/`.

**Zustands- und Zielverzeichnis muessen auf demselben Dateisystem liegen.**
Sonst bricht flatpak-builder mit "The state dir is not on the same filesystem
as the target dir" ab. Beim Bauen in `/tmp` (hier tmpfs) also
`--state-dir=` mitgeben.


## Baulaeufe fuer Linux, Windows, macOS und Flatpak

Seit 04.09.2026, `.github/workflows/build.yml`. Vier Jobs, ohne Signatur
(Nutzerentscheidung vom 02.09.: das Projekt darf nichts kosten). Die
Artefakte heissen deshalb UNSIGNIERT -- SmartScreen und Gatekeeper werden
meckern, und das soll niemanden ueberraschen.

### Drei Fehler, die schon das Schreiben zutage foerderte

Alle drei koennen auf dem Entwicklungsrechner **nicht** auffallen.

**`dataSource` fragte nach dem Geraet statt nach dem Dienst.** Der Fix vom
Nachmittag lautete `Qt.platform.os === "android"`. Richtig ist die Frage nach
dem **Dienst**: `orangedeck` ist ein systemd-Benutzerdienst und laeuft nur
unter Linux. Die erste Windows-Fassung waere mit "keine Verbindung zum Feed"
gestartet -- derselbe Willkommensgruss, denselben Tag zum zweiten Mal, weil
ein Symptom behandelt worden war statt der Ursache.

**`MACOSX_BUNDLE` und `WIN32_EXECUTABLE` waren nicht gesetzt.** Ohne sie gibt
es unter macOS kein `.app` (weder doppelklickbar noch mit `macdeployqt` zu
packen) und unter Windows ein Konsolenfenster neben der Anwendung.

**`install(TARGETS)` lief auf allen Nicht-Android-Systemen.** Die
`.desktop`-Datei und das Symbol im hicolor-Baum sind Linux-Begriffe, und ein
`MACOSX_BUNDLE`-Ziel verlangt bei `install(TARGETS)` ein BUNDLE-Ziel -- es
braeche schon beim Einrichten ab.

### Und drei, die erst der erste Lauf zeigte

**Windows: die CMakeLists gehoert in die Wurzel.** Die geteilten QML-Dateien
liegen unter `ui/qml/`; von `app/` aus heissen sie `../ui/qml/...`, und Qt
baut daraus den Namen des Zwischenverzeichnisses fuer den QML-Puffer. **Linux
macht aus dem `..` stillschweigend ein `_`, Windows nicht:**

    ninja: error: mkdir(.rcc/qmlcache/orangedeck-app_../ui): No such file

Qt empfiehlt ausdruecklich, QML-Dateien innerhalb des Modulverzeichnisses zu
halten. Aus der Wurzel gebaut heissen sie `ui/qml/...`, der Puffername lautet
`orangedeck-app_ui_qml_...` und die Frage stellt sich nicht mehr. **Gebaut
wird seitdem mit `cmake -S . -B build`**; Bauplaene, Workflow und die
Android-Anleitung sind mitgezogen.

**macOS: nicht Qt 6.8.** Die Reihe verlinkt dort noch das Framework AGL, und
das SDK von macOS 15 hat es nicht mehr: `ld: framework 'AGL' not found`. Mit
6.9 geht es durch.

**Flatpak: kein fertiges Container-Abbild.**
`bilelmoussaoui/flatpak-github-actions:kde-6.9` gibt es nicht ("manifest
unknown"), und welche Marken existieren, muesste man raten. Der Job richtet
flatpak selbst ein -- ein paar Zeilen mehr, dafuer haengt er an nichts, was
sich unter uns aendern kann.

### Zwei Entscheidungen im Workflow

**Der Linux-Job bricht ab, wenn QtWebSockets fehlt.** Ohne das Modul faellt
der Direktbezug weg, und ausserhalb von Linux gibt es keinen Dienst, der
einspraenge -- das waere wieder ein Paket, das erst beim Nutzer versagt. Nach
dem OpenSSL-Fund desselben Tages sollen solche Loecher laut sein, nicht
still.

**Der Flatpak-Job stellt den Auslieferungs-Bauplan auf den Commit dieses
Laufs.** Festgenagelt zu sein ist zum Ausliefern richtig und zum Pruefen
falsch: sonst baut der Lauf einen alten Stand und sagt nichts ueber den
neuen. Die Datei im Repo bleibt unangetastet, geaendert wird nur die Kopie im
Laeufer.

### Ergebnis des zweiten Laufs

    Linux    2 MB    Windows  52 MB    macOS  133 MB    Flatpak  1 MB

## Screenshots fuer Flathub

Flathub verlangt mindestens einen. Aufgenommen mit demselben Pruefstand wie
alles andere: Xvfb, Fenster ueber `tools/xtest.py` **genau auf die
Bildschirmgroesse gesetzt** (1280x800), damit kein schwarzer Rand mitkommt --
`import -window root` liefert dann exakt das Fenster.

**Der Feed braucht Vorlauf.** Die Halde fuellt sich nur mit echten
Transaktionen und ist erst nach einer Viertelstunde voll; ein Bild direkt
nach dem Start zeigt eine leere Flaeche. Die uebrigen Ansichten stehen
sofort.

Die Bilder liegen im Repo und werden von dort geladen. **Kein doppelter
Bindestrich im XML-Kommentar** daneben: XML verbietet ihn, und
`appstreamcli` bricht daran ab.
