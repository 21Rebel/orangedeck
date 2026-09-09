# Stand und offene Punkte

> Der Abschnitt gleich hier darunter ist der **gueltige Stand** und der
> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei, und erklaert nur noch, wie es dazu kam.

<!-- **Warum die Datei geteilt ist.** Am 06., 07. und 08.09.2026 stand
     dreimal derselbe offene Punkt darin: sie war 117 kB gross, dann 130,
     dann 148 -- "als Einstieg noch brauchbar, als Datei laengst
     unhandlich". Ein Journal, das man nicht mehr oeffnen mag, wird nicht
     mehr gelesen, und dann ist die Sorgfalt beim Schreiben umsonst.

     Geteilt am 09.09.2026, Zeile fuer Zeile unveraendert uebernommen: die
     Zerlegung wurde gegen das Original zurueckgerechnet, bevor sie
     geschrieben wurde. Hier bleibt nur der neueste Tagesabschluss stehen.
     Wandert er morgen ins Journal, kommt der von morgen an seine Stelle;
     die Datei bleibt damit so lang, wie ein Einstieg sein darf. -->

## TAGESABSCHLUSS 09.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**Die Anwendung hat acht Homescreen-Widgets, und drei Darstellungsfehler aus
Geraet und Schreibtisch sind behoben** -- ausgeliefert ist weiterhin nichts,
und inzwischen liegen **34 Commits** ueber `origin/main`, ohne dass einer
davon gepusht waere.

### Was morgen als Erstes drankommt

**1. Pushen.** Vierunddreissig Commits liegen ueber `origin/main`, davon
einundzwanzig von heute. Ohne den Push kein Tag `v0.2.3`, kein Bauplan-Pin,
keine Auslieferung -- und der Durchgang wird mit jedem Tag groesser. Der
Bauplan-Pruefer steht zu Recht rot: der Baum sagt 0.2.3, der Pin zeigt auf
0.2.2.

**2. Die gedrueckte Schrift in den Blockkarten.** Zwei Anlaeufe daran
gescheitert: erst feste Zeilenabstaende, dann Faktoren auf das Schriftmass
aus `Paint.FontMetrics`. Beides hat das Bild veraendert, keines es behoben.
Auch die Kachel um eine Zeile hoeher zu machen half nicht, sondern liess
alles gestreckt wirken (wieder zurueckgenommen). **Die Ursache ist also eine
andere und noch nicht gefunden.** Mit frischem Blick ansehen, nicht weiter
an den Zahlen drehen.

**3. Die Sprachfrage entscheiden.** Die Widgets sind seit heute **alle
englisch**, auch auf einem deutschen Telefon -- das ist gegenueber gestern
ein Rueckschritt und muss weg. Drei Wege stehen im Abschnitt weiter unten;
die Empfehlung ist B.

**4. Dann die Auslieferung 0.2.3:** Tag setzen, Pin nachziehen, Flatpak
bauen, Pruef-VM (`tools/pruefvm.sh gast` gibt die Gast-Schritte jetzt am
Stueck aus), APK aus dem Tag, **eine** Signatur, Gerätelauf, Fingerabdruck
gegen `B3:CC:83:79:...`.

### Was heute dazugekommen ist

Einundzwanzig Commits, 54 Dateien, +5599/-2816 Zeilen. **Nichts davon ist
gepusht.**

| Was | Woher der Anstoss kam |
|---|---|
| Nummer auf 0.2.3 entschieden, drei Stellen nachgezogen | offener Punkt 1 von gestern |
| Bauplan-Pruefer liest die Fassung aus dem gepinnten Stand | offener Punkt 4, zweiter Tag |
| `pruefvm.sh gast` gibt die Gast-Schritte aus, Zeigerfrage beantwortet | offene Punkte 5 und 6 |
| Journal geteilt: eine Datei je Tag, STAND.md 148 kB -> 16 kB | offener Punkt 12, dritter Tag |
| Halde: Buchfuehrungsluecke in `shedBottomRow` | eigene Suche |
| Block liegt ueber dem Regen (`z: 20`) | Geraet |
| Kachel geht erst mit, wenn sie ganz unter der Kante liegt | Geraet |
| Weg ist erst, was nicht mehr zu sehen ist | Geraet |
| Miner-Graph ohne Durchschnittslinie | Anwender |
| Block weich unter vier Geraetepixeln je Zelle | Schreibtisch |
| **Acht Homescreen-Widgets**, vier einfach und vier ausfuehrlich | Anwender |
| Waehrung aus der Anwendung, Vorgabe ueberall USD | Anwender |

**Neu im Projekt:** `android/src/dev/orangedeck/OrangeDeck/` mit zehn
Java-Klassen (`DeckWidget`, `GraphWidget`, `Graph`, `Bloecke`, `Verlauf` und
fuenf Widgets), dazu vier Layouts, acht `appwidget-provider`-Dateien und
`res/values-de/`.

### Die Erkenntnis des Tages

**Zahlen aus der falschen Messstelle sind keine Messung, sondern eine
Verkleidung.**

Ich habe mehrere Stunden lang das grosse orange Quadrat in der Mitte des
Feeds fuer die Halde gehalten. Es ist der Block. Die Halde ist das Mosaik
ganz unten. Auf dieser Verwechslung habe ich gezaehlt, gefilmt, Statistiken
gebaut ("19 von 61 Bildern gegen 27 von 90") und einen Commit begruendet --
alles davon wertlos. Aufgeloest hat es erst eine Spur, die die tatsaechlichen
Koordinaten ausgab:

    blockCenterY = poolTop * 0,5 = 213 log.  ->  y 897   gemessen 890
    blockSide    = 256 log.                  ->  720 px  gemessen 708x702
    poolTop..height = 426..639 log.          ->  y 1496..2095
    Mosaik unten                                 y 1554..2091

Das ist die Steigerung von gestern. Gestern hiess es: *zwei flache Kurven aus
zwei Gruenden sehen gleich aus*. Heute: **eine Messung an der falschen Stelle
sieht aus wie eine Messung.** Der Ausweg war derselbe wie gestern -- nicht
schaerfer hinsehen, sondern die Groessen ausgeben lassen, an die man glaubt.

Dazu, alle aus demselben Holz:

- **Was man nicht nachsehen kann, ist eine Vermutung.** Der Pfad zu Qts
  Einstellungsdatei war geraten und falsch; das Miner-Widget meldete
  "Adresse nicht gesetzt", obwohl sie gesetzt war. `adb run-as` greift bei
  einem Release-Bau nicht. Statt eines zweiten Rateversuchs **sucht** das
  Widget die Datei jetzt im eigenen Verzeichnis -- das haelt auch, wenn Qt
  den Ort verlegt.
- **Eine Grenze, die man kennt, ist billiger als eine, gegen die man
  laeuft.** `historical-price` ohne Zeitstempel: 1.477.817 Byte. Mit
  Zeitstempel: 160. Zweimal je Stunde waeren das 72 MB am Tag gewesen -- fuer
  eine einzige Prozentzahl. Und `/v1/mining/hashrate/3d` brach nach **19,7
  Sekunden** ohne Antwort ab, waehrend ein Widget insgesamt rund zehn hat.
  Beide Zahlen haben eine Gestaltungsentscheidung getroffen, nicht der
  Geschmack.
- **Der Verlauf muss nicht herunterladbar sein, damit es einen gibt.** Beim
  Mempool und beim Miner gibt es keinen zum Holen. Also schreibt das Widget
  ihn mit, so wie der Daemon es fuer die Miner tut. Dass er anfangs leer ist,
  steht dann als Satz da ("Verlauf entsteht · 2 von 180 Punkten") statt als
  schwarze Flaeche, die wie ein Fehler aussieht.
- **Eine Vorgabe an fuenf Stellen ist eine Vorgabe und vier Fehler.**
  `"currency", "eur"` stand in SettingsView, FeedTabs, beiden DMS-Ansichten
  und im Dashtab. Eine davon zu aendern haette Reiter und Widget
  auseinanderlaufen lassen. Dasselbe Muster wie `ETAPPE=20m` neben
  `VORLAUF_GRENZE=2400` am 07.09. und die Schnapp-Funktion am 08.09.
- **Dieselbe Schwelle an vier Stellen ist dreimal zu oft.** `g * dpr < 2`
  stand dreimal so da und einmal als `blockUnit(...) < 2` -- letzteres in
  logischen Punkten, was ab dpr 2 etwas anderes bedeutet. Sie steht jetzt
  einmal (`zelleGanzAb`, `grobRaster()`).
- **`console.log` erreicht das Android-Protokoll nicht, `console.warn`
  schon** (Tag `qml`). Das hat einen ganzen Bau gekostet, bevor es auffiel,
  und es steht in keiner Doku.
- **Zum dritten und vierten Mal: kein `--` in XML-Kommentaren.** Die
  metainfo warnt seit dem 08.09. davor. Heute zweimal hineingelaufen, beim
  Anlegen der Widget-Ressourcen. Der Hinweis steht jetzt auch in
  `res/drawable/widget_grund.xml`.

### Was ein Widget kann und was nicht

Gemessen und nachgeschlagen, damit es niemand noch einmal versucht:

- **Kein Weichzeichnen.** RemoteViews kennt `setRenderEffect` nicht, ein
  Widget hat kein eigenes Fenster fuer `setBackgroundBlurRadius`, und der
  Umweg ueber das Hintergrundbild ist seit Android 13 zu
  (`WallpaperManager.getDrawable()` gibt Fremden nur das Standardbild). Was
  geht, ist getoentes Glas: Verlauf plus zarter Rand.
- **Kein kurzer Takt.** `updatePeriodMillis` rundet alles unter 30 Minuten
  auf 30 Minuten auf, WorkManager kommt auf 15. Fuenf Sekunden gibt es nur
  ueber einen Vordergrunddienst mit Dauerbenachrichtigung.
- **Aber Bilder.** `setImageViewBitmap` nimmt eine fertige Bitmap, und damit
  geht alles: Kurven, Blockkarten mit Verlauf und Glanz, runde Ecken. Der
  Weg dorthin ist `Canvas` und `Paint` in Java -- dieselben Mittel wie in
  QML.
- **RGB_565 statt ARGB_8888**, weil die Bitmap ueber Binder geht: 640x220
  kosten in ARGB_8888 rund 563 kB, in RGB_565 die Haelfte. **Und
  Durchsichtigkeit geht trotzdem** -- der Bitmap fehlt nur der Alphakanal zum
  *Speichern*, halbdurchsichtig aufgetragene Farbe mischt sich beim Zeichnen
  richtig. Das habe ich erst falsch kommentiert und dann gemessen.
- **Java ja, Kotlin nein.** Das von androiddeployqt erzeugte Gradle-Projekt
  legt zwar ein `kotlin.srcDirs` an, wendet aber kein Kotlin-Plugin an --
  Kotlin-Dateien fielen stillschweigend weg. Java aus `android/src/`
  uebersetzt es ohne Zutun.

### Und was ich selbst falsch gemacht habe

Das gehoert dazu, weil es Zeit gekostet hat:

- **Block und Halde verwechselt**, siehe oben. `5c7fff6` traegt eine
  Begruendung, die auf dieser Verwechslung steht; die Richtigstellung steht
  im naechsten Commit, aber der Text bleibt falsch.
- **Eine Simulation mit Pythons Rundung gebaut**, wo JavaScripts gilt.
  Pythons `round()` rundet bei genau ,5 zur geraden Zahl, JS immer auf. Das
  erzeugte eine Ungleichheit, die es in QML gar nicht gibt -- fast haette ich
  einen Fehler behoben, den es nicht gab.
- **`ls` ist hier auf `eza` gelegt**, mit Symbolen. Mein
  `$(ls -d .../ndk/*)` hat ein Icon-Zeichen in den NDK-Pfad geschmuggelt, und
  der Bau brach mit "CMAKE_CXX_COMPILER not set" ab -- eine Meldung, die auf
  etwas ganz anderes zeigt. (`tools/apk.sh` ist nicht betroffen: dort laeuft
  `ls` in einer nicht-interaktiven Bash ohne Aliase.)
- **Ein zu breites `grep` ins Protokoll** hat 4000 Zeilen
  WindowManager-Rauschen geliefert statt der gesuchten Ausnahme.
- **Zweimal Steuerzeichen in einen Heredoc geschrieben**, den das Werkzeug
  dann zu Recht abgelehnt hat.
- **Toten Code stehengelassen**: ein `if (false)`-Block, ein doppelter
  `setShader`, ein `"{}".equals("") ? ...`, eine abstrakte Methode, die nie
  gerufen wurde. Alle vier beim Nachlesen selbst gefunden und entfernt --
  aber sie waren erst einmal drin.
- **Beim Nachmessen wiederholt den falschen Ausschnitt gegriffen**, weil die
  Widgets ihre Plaetze wechselten.

### Was sonst noch offen ist

1. **Die gedrueckte Schrift in den Blockkarten** (siehe oben, Punkt 2).
2. **Die Sprache der Widgets.** Sie sind seit heute alle englisch, auch auf
   einem deutschen Telefon. Ursache: in der von androiddeployqt erzeugten
   `build.gradle` steht `defaultConfig { resConfig "en" }` -- Qt beschraenkt
   die Ressourcen auf Englisch, `values-de/` wird beim Bauen verworfen. Am
   Geraet gemessen: Systemsprache `de-AT`, im APK **keine einzige**
   Sprachkonfiguration. Drei Wege:

        A   eigene build.gradle mitliefern. Eine Zeile anders, aber wir
            besitzen dann die ganze Datei und ziehen sie bei jedem
            Qt-Sprung nach.
        B   die Sprachen zur Laufzeit in Java fuehren, wie `strings.js`
            es tut: Tabelle, Auswahl ueber `Locale.getDefault()`,
            Rueckfall auf Englisch. Umgeht `resConfig` ganz und koennte
            alle dreizehn Sprachen der Anwendung uebernehmen. Preis: die
            Beschriftung in der Auswahlliste des Starters bliebe englisch.
        C   A plus eine Pruefung, die meldet, wenn Qts erzeugte Fassung
            von unserer abweicht.

   **Empfehlung: B.** Die Uebersetzungen liegen ohnehin im Projekt, und wir
   haengen uns keine Datei ans Bein, die uns nicht gehoert.
3. **Die Miner-Bruecke** ist besprochen und freigegeben, aber nicht gebaut:
   die Anwendung fragt den Miner ohnehin alle fuenf Sekunden ab
   (`DirectMiner.qml`); wenn sie jeden Punkt in dieselbe Datei schreibt, aus
   der das Widget liest, ist der Graph dicht fuer jeden Zeitraum, in dem die
   Anwendung offen war. Braucht eine kleine C++-Bruecke (QML kann keine
   Dateien schreiben) und eine hoehere Punktzahl -- 180 sind bei fuenf
   Sekunden nur fuenfzehn Minuten. Ehrlicher Preis: der Verlauf wird dicht,
   wo die Anwendung lief, und duenn dazwischen.
4. **Einstellungen je Widget** (Konfigurations-Activity beim Platzieren):
   Waehrung je Kachel, Deckkraft, welche Zeilen. Der Unterbau steht -- die
   Wechselkurse kommen mit demselben Aufruf, der die Tagesveraenderung holt.
5. **`SuccessExitStatus=SIGTERM` einspielen.** Der Unterschied ist eine Zeile
   plus Kommentar in `backup-lokal`, `backup-stick` und `backup-auslagern`,
   Timer unveraendert. Braucht `sudo`; der Versuch wurde heute vom
   Klassifizierer abgelehnt. Dazu ein Blick, ob die Sicherungs-Kachel im
   DMS-Plugin etwas davon mitbekommen muss (Einschaetzung: nein, die Zeile
   unterdrueckt nur die falsche "fehlgeschlagen"-Meldung).
6. **Der Hinweis zu `console.warn`** gehoert in die DOKUMENTATION; er steht
   bisher nur in einem Commit-Text.
7. **Die Fugenmessung fuer `ff2d7a0`** ist nie sauber nachgeholt worden. Der
   Versuch heute Vormittag lief unter anderen Bedingungen (Mempool 84.969,
   Rasterweite 7 px statt 17) und ist deshalb nicht mit der von gestern
   vergleichbar. Im Explorer waere sie auf Kommando herstellbar.
8. **Der Explorer-Zoom.** Die Maschinerie steht im Feed (`root.zoomed`), in
   `BlockTiles` nicht. Zurueckgestellt bis nach 0.2.3, weil er genau die
   Raster- und Fugenrechnung anfasst, die diese Woche mehrfach falsch war.
9. **Der Markt-Reiter fehlt auf Android** -- rund 800 Zeilen Python nach QML.
   **Wichtig:** die Freigabetexte nennen ihn prominent. Auf einer
   Android-Downloadseite waere das ein Versprechen, das das Paket nicht
   haelt.
10. **Auf dem Handy liegt eine mit dem Debug-Schluessel signierte 0.2.3.**
    Der Schluessel, mit dem die vorige Fassung signiert war, existiert nicht
    mehr (Fingerabdruck `f055bed9...`, weder der echte `b3cc8379...` noch
    `~/.android/debug.keystore`). Ein Wechsel heisst deshalb immer
    deinstallieren.
11. **Ein Proton-Lauf mit dem Signaturschluessel** steht noch aus.
12. **Die `.idsig`-Dateien und die alten Fassungen** raus aus
    `auslieferung/`, sobald 0.2.3 wirklich ausgeliefert ist. Nicht vorher.
13. **`tools/bauplan-pruefen.py`** meldet jetzt richtig rot (Pin auf 0.2.2,
    Baum auf 0.2.3). Das ist kein offener Punkt, sondern die Erinnerung, dass
    der Pin zum Auslieferungsdurchgang gehoert.
14. **Doku-Seite unter orangedeck.dev/doku/**, die elf uebrigen Sprachen der
    Website, der Spendenkanal, `og:image`, die Design-Leinwand, F-Droid,
    Laufzeit `org.kde.Platform` 6.11, eine Sicherheitsadresse -- unveraendert
    offen vom 07.09.

### Nachtrag: die Verbindung zum Handy

Das Kabel hat heute wieder mehrfach ausgesetzt, und die Ursachen waren
verschieden: einmal hatte sich der Stecker geloest (das Geraet war gar nicht
am Bus), mehrfach war USB-Debugging am Telefon abgeschaltet (das Geraet stand
als `04e8:6860` am Bus, `adb` sah es nicht), und einmal lag die
Benachrichtigungsleiste heruntergezogen ueber dem Bild, ohne dass sie sich
von hier schliessen liess. **`adb_allowed_connection_time` steht schon auf
0**, das ist es also nicht. `svc power stayon usb` hat geholfen, aber nicht
durchgehend.

Wer morgen dort weitermacht: `lsusb | grep 04e8` unterscheidet "Stecker lose"
von "Debugging aus" und spart das Raten.

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
| [08.09.2026](journal/2026-09-08.md) | Das Geraet fand dreizehn Befunde. Der Miner laeuft ohne Daemon, und `v0.2.2` zeigt auf einen Stand ohne jede Korrektur. |
| [07.09.2026](journal/2026-09-07.md) | Die Sicherung traegt, der Signaturschluessel existiert. Offen blieb nur der Push. |
| [06.09.2026](journal/2026-09-06.md) | orangedeck.dev ist live und zeigt den Mempool wirklich live; der Flathub-Antrag ging raus und war in einer Minute zu. |
| [05.09.2026](journal/2026-09-05.md) | Eigene Identitaet: eigene Domain, eigenes Zeichen, eine Kennung fuer alle Systeme. Die Auslieferung geradegezogen. |
| [04.09.2026](journal/2026-09-04.md) | Zum ersten Mal auf einem Rechner gelaufen, der nichts von diesem Projekt weiss. Die Pruef-VM entsteht. |
| [03.09.2026](journal/2026-09-03.md) | Das Projekt heisst OrangeDeck und ist oeffentlich. 394 Vorkommen umbenannt, zwei neue Ansichten. |
| [02.09.2026](journal/2026-09-02.md) | Blockuhr, Widgets, Flatpak, Layer-Shell, Android-APK, dreizehn Sprachen, Goggles, watch-only. |
| [01.09.2026](journal/2026-09-01.md) | Die erste Uebergabe: was steht, was offen ist, wie man morgen anfaengt. |
| [31.08.2026](journal/2026-08-31.md) | Die aeltesten Notizen. Woher `mondrian.js` und `colors.js` kommen, und ob Bitfeed sich selbst betreiben laesst. |
