# Uebergabe 17.09.2026: was die Desktop-Optik-Sitzung an OrangeDeck geaendert hat

Geschrieben aus der Sitzung in `~/Schreibtisch/desktop-optik`, damit die
OrangeDeck-Sitzung den Stand kennt. Alles unten ist **erledigt und vom Nutzer
abgenommen**, bis auf den letzten Abschnitt.

## 1. Was im Projekt selbst liegt (uncommittet)

`ui/qml/FeedPanel.qml`, der Tooltip ueber dem Kachelfeld:

- Untergrund war `lineColor` mit 0,97 -- auf dem orangen Kachelfeld zu hell,
  die Schrift verlor an Kontrast. Jetzt `frostedTint` mit 0,88 und der Rand
  eine Spur weniger aufgehellt (1,4 statt 1,6).
- Dazu ein `FrostedPanel` hinter dem Tooltip (`content: tip`,
  `backdropSource: canvasView`, `pad: 0`, `z: 199`) -- derselbe Aufbau, den
  Kopfzeile, Infozeile, Legende und Umschalter schon haben. Der Tooltip liegt
  damit auf demselben weichgezeichneten Untergrund wie die uebrigen Angaben.

Sicherungskopie des Vorzustands: `~/.config/DankMaterialShell/plugins/OrangeDeck/.FeedPanel.qml.vor-tooltip-20260917`
(der Ordner ist eine Linksammlung, die Datei selbst zeigt auf `ui/qml/FeedPanel.qml`).

**Nicht von mir**: die offenen Aenderungen in `shell/dms/OrangeDeckSettings.qml`
(14 Zeilen) lagen schon vorher im Arbeitsbaum. Ich habe nichts committet, damit
nichts Halbfertiges mitgeht.

Wunsch des Nutzers war „gleiche Optik wie das Terminalfenster, sodass der
Kontrast von Hintergrund und Schrift groesser ist". Wenn es noch dunkler soll:
die 0,88 hoeher ziehen oder den Ton fest auf Schwarz legen.

## 2. Zwei Fehler am Desktop-Widget, Ursache lag ausserhalb des Projekts

### Linke Maustaste verschob das Widget, statt Knoepfe zu treffen

Symptom: im Desktop-Widget liess sich mit links nichts anklicken, jeder
Linksklick zog das Fenster. Betraf Feed und Miner gleichermassen, an jeder
Stelle des Widgets.

Ursache liegt in DMS, nicht in OrangeDeck: der Weckmechanismus vom 15.09.
(`~/.local/bin/dms-leiste-patch`, Abschnitt 4) hatte einen `HoverHandler`
**in** die Ziehflaeche `dragArea` von `Modules/Plugins/DesktopPluginWrapper.qml`
gesetzt. Qt setzt jedes Element, an dem ein PointerHandler haengt, intern auf
`Qt.AllButtons` -- auch wenn im Quelltext `acceptedButtons: Qt.RightButton`
steht. Die Ziehflaeche nahm damit auch die linke Taste, und Klicks kamen nie
beim Inhalt an.

Zwischenschritt, der einen zweiten Fehler brachte: `hoverEnabled: true` direkt
auf der Ziehflaeche. Damit zog sie nicht mehr an der linken Taste, schluckte
aber das Ueberfahren fuer alles darunter -- der Tooltip im Feed blieb dann
stehen und wechselte nur noch beim Klick auf eine andere Transaktion.

Endstand: der `HoverHandler` sitzt jetzt direkt im Fenster (`widgetWindow`),
also neben `contentLoader` statt in der Ziehflaeche, und `_wachHover` liest
`wachHover.hovered`. Nachgezogen in der laufenden Oberflaeche **und** im
Patch-Skript, damit ein DMS-Update es nicht zurueckdreht. Sicherung des
Skripts: `~/.local/bin/.dms-leiste-patch.vor-hover-20260917`.

**Fuer OrangeDeck heisst das:** wer im Desktop-Widget etwas anklickbar macht,
sollte gegenpruefen, ob Klicks ueberhaupt durchkommen -- die Ziehflaeche liegt
ueber dem Inhalt. Rechte Taste zieht, linke gehoert dem Inhalt.

### Was im Desktop-Widget absichtlich aus ist

`shell/dms/OrangeDeckDesktop.qml` setzt `minerActions: false` und
`searchFocus: false`. Die Miner-Aktionsknoepfe fehlen dort also mit Absicht,
und das Suchfeld des Explorers holt sich keinen Tastaturfokus. Falls der Nutzer
nach Knoepfen im Miner fragt: das ist die Stelle.

## 3. Aussehen der beiden Desktop-Widgets

Auf Wunsch am 17.09. umgestellt, beides ausserhalb des Projekts:

- **Hintergrund weg**: `desktopOpacity` steht bei beiden OrangeDeck-Instanzen
  (`orangedeck-1` und `dw_1789572820890_l7pponxix`) auf **0**. Der Wert wirkt in
  `OrangeDeckDesktop.qml` auf das Rechteck hinter dem Inhalt.
- **Blur aus**: neue Layer-Regel in `~/.config/niri/config.kdl` fuer
  `^dms:desktop-widget:orangedeck:` mit `blur false`, gesetzt **nach** der
  allgemeinen Widget-Regel (spaetere Regel gewinnt). Sicherung:
  `config.kdl.bak-orangedeck-blur-20260917`.

Zu beachten: die Widget-Einstellungen gehoeren zum Optik-Profil (der
Profil-Schnappschuss enthaelt `desktopWidgetInstances`). Das aktive Profil
`serverracks` hat die 0 mitgespeichert, die uebrigen zehn Profile tragen noch
65 -- beim Wechsel dorthin kommt der Hintergrund also zurueck. Die Blur-Regel
dagegen ist global.

## 4. Zwei Fallen aus der Fehlersuche

- **QML-Zwischenspeicher.** Die laufende Oberflaeche fuehrte minutenlang alten
  kompilierten Code aus, obwohl die Datei laengst geaendert war. `rm -rf
  ~/.cache/quickshell/qmlcache` und Neustart. Wer an QML im laufenden DMS
  misst, sollte das im Verdachtsfall zuerst tun.
- **Protokoll ab Dienststart lesen.** `journalctl --since "3 min ago"` zeigte
  Zeilen von **vor** dem Neustart und fuehrte zweimal in die Irre. Richtig:
  `START=$(systemctl --user show dms.service -p ExecMainStartTimestamp --value)`
  und `--since "$START"`.

## 5. Offen

- Der Tooltip-Kontrast ist eine Geschmacksfrage, Wert steht bei 0,88.
- Die Aenderung in `ui/qml/FeedPanel.qml` ist uncommittet und wartet auf den
  naechsten Commit dieses Projekts.
- Ebenfalls uncommittet, aber nicht von mir: `shell/dms/OrangeDeckSettings.qml`.
