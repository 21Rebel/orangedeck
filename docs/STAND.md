# Stand und offene Punkte

## Stand 02.09.2026, spaeter Abend -- Direktbezug, und was er kostet

**Die Oberflaeche kann jetzt selbst mit mempool.space reden.** Der Anlass:
ein Widget, das nur laeuft, solange der Heimrechner an ist, ist keines --
und auf einem Handy gibt es den Dienst ohnehin nicht.

Neu ist `ui/qml/DirectFeed.qml`: derselbe WebSocket, den auch der Dienst
benutzt, dazu die REST-Abfragen fuer Kacheldaten und langsame Kennzahlen.
Herausgekommen ist ein Zustand mit **genau demselben Aufbau** wie `/state`
und `/block` -- `FeedState` schiebt beide Quellen durch dieselbe Auswertung
(`__apply`), und keine einzige Ansicht merkt, woher die Zahlen kommen.
Umgestellt wird in den Einstellungen unter "Allgemein" oder mit
`btcfeed-app --source direct`.

Weniger Arbeit als befuerchtet, aus zwei Gruenden: die Kachelpackung lief
**schon immer** in QML (`mondrian.js`), der Dienst liefert nur rohe Listen --
und die Schnittstelle zwischen beiden ist schmal, drei Abfragen.

**Zwei Reiter fallen im Direktbezug weg**, und das ist keine Bequemlichkeit:
der Miner steht im Heimnetz, und die Wallet-Ableitung ist Punktarithmetik auf
secp256k1 -- die gehoert nicht in QML nachgebaut. `FeedState` sagt das ueber
`canMiner` und `canWallet`, alle drei Hosts blenden die Reiter danach aus.
Ein Reiter, hinter dem nichts sein kann, ist schlimmer als keiner.

`import QtWebSockets` steht bewusst in einer **eigenen** Datei: das Paket
(`qt6-websockets`) ist nicht ueberall installiert, und stuende die Zeile in
`FeedState.qml`, fiele damit die ganze Anwendung aus statt nur einer
Betriebsart. Geladen wird sie ueber einen `Loader`. Die KDE-Flatpak-Laufzeit
bringt das Modul mit -- das Flatpak laeuft damit ganz ohne Dienst.

### Dabei eine teure Gewohnheit gefunden

Beim Nachmessen fiel auf, dass die Anwendung **im Dienstbetrieb** deutlich
mehr Rechenzeit brauchte als im Direktbezug. Nachgesehen, warum:

    /state                     32 kB, alle 400 ms geholt = 80 kB/s JSON
      davon recent             16 kB, wovon die Ansicht alles bis `seq` wegwirft
      davon stats +
            minerHistory       14 kB, die sich hoechstens im Minutentakt aendern

Der Dienst nimmt jetzt zwei freiwillige Parameter: `?since=<seq>` schickt nur
die neuen Transaktionen, `?slow=<rev>` laesst die langsamen Felder weg,
solange sie sich nicht geaendert haben. Was fehlt, behaelt die Oberflaeche vom
vorigen Stand. **Aus 32 kB werden rund 2 kB.** Ohne Parameter kommt die
Vollform wie eh und je -- `curl` und aeltere Fassungen merken nichts davon.

**Und eine Lehre ueber das Messen selbst.** Nacheinander gemessen kamen
19,97 % gegen 5,82 % heraus, kurz darauf 7,20 % gegen 13,48 % -- die Zahlen
haengen am Mempool-Verkehr, nicht an der Betriebsart. Erst **gleichzeitig**
gemessen, im selben Zeitfenster, sind sie vergleichbar:

    Dienst (gekuerzt)   11,1 % CPU
    Direktbezug         14,7 % CPU

Der Dienst bleibt also die guenstigere Quelle -- er nimmt der Oberflaeche den
WebSocket und das Zusammenbauen ab. Auf dem Handy zaehlt das nicht, dort gibt
es keine Wahl.

## Dazu am 02.09.2026: der Fluss einer Transaktion

Drei Punkte aus dem Durchgang, alle am Vorbild (mempool.space) geprueft:

- **Anschlussstuecke an beiden Enden.** Vor dem Eingang und hinter dem
  Ausgang steht jetzt ein kurzer Balken, der nach aussen in nichts uebergeht.
  Er sagt: davor haengt eine andere Transaktion, danach geht es weiter.
- **Die Stufe an der Naht ist weg.** Ursache war nicht die Lage, sondern die
  Dicke: gezeichnet wird ein Band ueberall mit **einer** Staerke, und das
  erste und letzte Band steht oben und unten um die Haelfte dessen ueber, was
  ihm die Mindestdicke ueber sein Gewicht hinaus gibt. Dieser Ueberstand ist
  auf beiden Seiten verschieden gross -- links ein dicker Eingang, rechts die
  winzige Gebuehr. Jetzt wird der Platz fuer die Gewichte um beide
  Ueberstaende gekuerzt; dann misst der gezeichnete Strang auf beiden Seiten
  genau `trunkH`. Ein erster Versuch, der nur `hMid` staucht, blieb wirkungslos:
  gezeichnet wird mit `hEdge`.
- **Die Angaben stehen am Zeiger**, nicht mehr am Fussrand: welcher Ein- oder
  Ausgang, der Betrag, die Adresse -- und im Strang darueber die Transaktion,
  weil dort beide Seiten zu ihr gehoeren.

Nebenbei ein echter Fehler, den erst der Pruefstand zeigte: steht die eine
Seite schon und die andere noch nicht -- die Eigenschaften kommen nacheinander
an --, lief der Aufbau in `out[0]` einer leeren Liste.

**Der Pruefstand ist die Lehre daraus.** Eine einzelne QML-Datei, die nur
`TxFlow` mit einer echten Transaktion zeichnet und den Zeiger von aussen
setzt (`scratchpad/flowtest.qml`, mit `qml6` gestartet). Das Diagramm im
ganzen Programm zu erreichen kostet Klicks, die sich kopflos nicht
nachstellen lassen -- ein Zeigerwerkzeug gibt es hier nicht, und die Ziffern
einer TxID schalten beim Tippen die Ansicht um, weil das Suchfeld beim
Oeffnen keinen Eingabefokus hat.

## Stand 02.09.2026, Abend -- Flatpak, Layer-Shell, Android-APK

Drei der offenen Punkte auf einmal. Vorher wurde installiert, was fehlte:
`flatpak-builder`, `layer-shell-qt` (Qt6), `wlr-randr`, `jdk17-openjdk`,
`android-udev` aus den Paketquellen; die KDE-Laufzeit `org.kde.Platform//6.9`
und `org.kde.Sdk//6.9` als **Benutzer**-Installation; Android-Kommandozeile,
Plattform 36, Build-Tools 36.0.0 und NDK 27.2.12479018 nach `~/Android/sdk`;
Qt 6.11.2 fuer `android_arm64_v8a` mit `aqtinstall` nach `~/Qt`.

### Flatpak -- laeuft

`packaging/flatpak/store._21rebel.btcfeed.yml`. Gebaut und geprueft: das
Paket startet im kopflosen Compositor, zeigt Live-Daten und traegt sein
eigenes Symbol.

**Die Kennung musste sich aendern.** `dev.21rebel.btcfeed` weist Flatpak ab:
*"Name segment can't start with 2"*. Ein Segment einer solchen Kennung darf
nicht mit einer Ziffer beginnen; die vorgesehene Schreibweise setzt einen
Unterstrich davor. Neu ist deshalb **`store._21rebel.btcfeed`** -- und das
passt zugleich zu einer Domain, die es wirklich gibt (21rebel.store).
Umbenannt wurden die `.desktop`-Datei und das Symbol; in `main.cpp` steht die
Kennung jetzt ausdruecklich (`setDesktopFileName`), sonst leitet Qt die
Wayland-app_id aus der umgedrehten Domain ab und der Fensterverwalter findet
das Symbol nicht.

Dazu neu: `app/icons/store._21rebel.btcfeed.svg` (eigene Zeichnung -- Kacheln
wie im Feed, **nichts** von Bitfeed uebernommen), eine AppStream-Beschreibung
und `packaging/flatpak/btcfeed-launch`. Der Starter prueft erst, ob auf
`127.0.0.1:21021` schon ein Daemon antwortet: im Flatpak ist das dank
`--share=network` dieselbe Schnittstelle wie draussen, ein laufender
Benutzerdienst wird also mitbenutzt und nur sonst einer im Sandkasten
gestartet. Python bringt die Laufzeit mit (3.12), der Daemon kommt mit der
Standardbibliothek aus.

`layer-shell-qt` fehlt in der KDE-Laufzeit und wird als eigenes Modul
mitgebaut -- **nicht** in der Fassung des Systems: 6.7.4 verlangt Qt 6.10 und
ECM 6.26, die Laufzeit 6.9 hat Qt 6.9.3 und ECM 6.22. 6.5.5 ist die letzte,
die dazu passt.

**Und trotzdem gibt es im Flatpak keine Widgets** -- aus einem Grund, der
richtig ist: der Compositor blendet privilegierte Protokolle vor
Sandkastenprogrammen aus. Nachgewiesen: derselbe Aufruf legt als gewoehnlich
gebaute Anwendung drei Layer-Flaechen an, aus dem Flatpak scheitert er mit
"Failed to initialize layer-shell integration", obwohl die Bibliothek
geladen ist -- und labwc schreibt genau bei diesen beiden Laeufen (und nur
bei ihnen) "Blocking ... protocol" ins Protokoll. Flatpak meldet den
Sandkasten ueber `wp_security_context_v1` an, und wer sich so anmeldet,
bekommt `zwlr_layer_shell_v1` nicht mehr zu sehen. Ein Programm im Sandkasten
soll sich eben nicht ueber den ganzen Bildschirm legen koennen.

Die Anwendung faellt sauber zurueck: `--layer` warnt und zeigt ein
gewoehnliches Fenster. Ein Zwischenschritt hatte das kaputtgemacht --
`QT_WAYLAND_SHELL_INTEGRATION=layer-shell` von Hand gesetzt, weil
`Shell::useLayerShell()` in 6.5 noch nicht als ueberfluessig gilt. Das ist
aber ein **globaler** Schalter: schlaegt die Anbindung fehl, startet Qt
ueberhaupt nicht mehr ("no Qt platform plugin could be initialized"). Seit
Qt 6.5 haengt LayerShellQt die Anbindung ohnehin an das **einzelne Fenster**
(`waylandWindow->setShellIntegration`), auch in 6.5.5 -- die Zeile war
unnoetig und ist wieder heraus.

**Fuer Widgets also: aus den Paketquellen bauen, nicht das Flatpak.** Das
Flatpak bleibt das gewoehnliche Fenster.

### Layer-Shell -- Widgets ohne DMS

`btcfeed-app` kennt jetzt Schalter (Anleitung in
`packaging/widgets/README.md` samt Startzeilen fuer niri, Hyprland, sway und
labwc):

    --layer <background|bottom|top|overlay>   --anchor top,left,...
    --width --height --margin --exclusive
    --view <0-5>   --bare   --id <name>

Nachgewiesen im Bild: drei Flaechen gleichzeitig auf einem Compositor --
Miner links oben, Blockclock rechts oben, Feed als Leiste unten, jede mit
eigener Ansicht.

Drei Dinge, die dabei zu lernen waren:

- **Das Fenster muss unsichtbar entstehen.** `Window { visible: true }` haengt
  die Wayland-Flaeche sofort ein; danach ist `LayerShellQt::Window::get()`
  wirkungslos und `--layer` bliebe stumm. Jetzt setzt `main.cpp` beim Laden
  `visible: false` und zeigt das Fenster erst, nachdem die Layer-Flaeche
  eingerichtet ist.
- **`-v` war schon vergeben.** `--version` belegt es; `QCommandLineParser`
  lehnt daraufhin die **ganze** Option ab, und `--view` war stillschweigend
  unbekannt ("Unknown option 'view'"). Kein Kuerzel mehr.
- **`--id` ist der Punkt, an dem mehrere Widgets nebeneinander gehen.** Ohne
  eigenen Einstellungsspeicher schreiben sie sich gegenseitig um. Mit
  `--id uhr` liegt er in `~/.config/btcfeed/btcfeed-uhr.conf`.

Nebenbei: ein unsichtbares Element behaelt seine Hoehe -- die nackten Widgets
hatten oben einen leeren Streifen in Reiterhoehe (`win.tabSpace`).

### Android -- das APK steht, das Handy fehlt noch

`cmake --build build-android --target apk` liefert 45 MB, arm64-v8a,
unsigniert. Die Werkzeugkette traegt also.

**Zwei Stolpersteine.** `install(TARGETS)` bricht unter Android ab
("no LIBRARY DESTINATION"): dort ist das Programm eine Bibliothek, die die
Java-Huelle laedt. Installiert wird unter Android ohnehin nichts, also ist die
Regel jetzt in `if(NOT ANDROID)` gefasst. Und Plattform 35 reicht nicht:
`androidx.core:core:1.17.0` verlangt **compileSdk 36**.

**Offen und wichtig:** auf dem Handy gibt es keinen Daemon. Die Anwendung
fragt `127.0.0.1:21021` -- dort antwortet auf einem Telefon niemand. Zwei
Wege stehen zur Wahl, und das ist genau die Frage "wie soll die mobile
Fassung aussehen":

1. Die Anwendung redet auf dem Handy **selbst** mit mempool.space.
   Kein Daemon, aber die Aufbereitung (Kachelpackung, Aenderungsbuch) muesste
   in QML nachgebaut werden.
2. Das Handy fragt den Daemon **auf dem Rechner** im Heimnetz. Wenig Arbeit --
   aber der Daemon lauscht bewusst nur auf `127.0.0.1`. Das aufzumachen ist
   eine Entscheidung, die dem Nutzer gehoert, nicht der Anwendung.

## Stand 02.09.2026, spaeter Abend -- Widgets und grosse Werte

**Jeder Tab laesst sich einzeln auf den Desktop legen.** Das DMS-Widget
(`shell/dms/BitcoinFeedDesktop.qml`) kennt jetzt eine Einstellung
`widgetView` -- Feed, Blockclock, Miner oder Explorer. DMS gibt jeder
Instanz eines Desktop-Widgets einen **eigenen** Einstellungsspeicher
(`instanceId` + instanzgebundener `pluginService`), also kann man vier
Widgets nebeneinander legen, jedes mit einer anderen Ansicht.

**Blockclock: welcher Wert gross steht, ist waehlbar** -- Blockhoehe, Kurs,
Moscow Time, Gebuehr, Hashrate, Mempool oder Uhrzeit, mehrere zugleich. Sind
mehrere gewaehlt, wechselt die Anzeige reihum; das Intervall steht in den
Einstellungen (aus / 5 / 10 / 30 / 60 s). Der gerade grosse Wert faellt aus
der kleinen Kennzahlenzeile heraus, damit er nicht doppelt dasteht.
Nachgesehen im Bild: vier Aufnahmen im Abstand von fuenf Sekunden zeigen
Kurs -> Moscow Time -> Blockhoehe -> Kurs.

**`startView` kennt jetzt "zuletzt benutzte" (-1)** und ist damit
voreingestellt -- vorher ueberschrieb die Starteinstellung immer die zuletzt
gewaehlte Ansicht.

**Die zweite QSettings-Falle** (die erste war die leere Liste): eine
INI-Zeichenkette mit Komma wird beim Lesen als **Liste** zurueckgegeben.
`bigFieldsRaw=height,price,moscow` kam als `"height"` wieder an, stillschweigend
und ohne Meldung -- die Rotation stand deshalb still. Alle Listen werden
jetzt mit `|` zusammengesetzt (`Main.qml`, `btcfeed-dashtab`,
`BitcoinFeedDesktop.qml`).

**Beim Pruefen im kopflosen Compositor:** `labwc` uebernimmt `WAYLAND_DISPLAY`
nicht als eigenen Sockelnamen, es sucht sich `wayland-N` selbst. Wer die
Anwendung von aussen startet, trifft den falschen Compositor. Richtig ist
`labwc -S <skript>` -- das Skript laeuft als Kind und erbt den richtigen
Namen. Die Meldung "Failed to bind socket @/tmp/.X11-unix/X0" ist dabei
harmlos, `labwc` laeuft trotzdem weiter.

## Stand 02.09.2026 -- der geplante Block lebt

Punkt 1 der Liste ist erledigt. Auf der Startseite des Explorers steht der
naechste Block als Kachelgrafik und veraendert sich mit dem Zulauf: neue
Transaktionen blitzen weiss auf, verdraengte verschwinden, darueber steht
"+178 hinzugekommen · -199 verdraengt". Dieselbe Darstellung traegt auch die
Ansicht eines einzelnen geplanten Blocks (Klick auf eine gruene Kachel), dort
ohne eigene Ueberschrift.

Neu: `ui/qml/ProjectedBlock.qml`. Geaendert: `BlockTiles.qml` (lebendiger
Betrieb), `daemon/btcfeed` (Aenderungsbuch, geplante Bloecke im Zustand),
`BlockChain.qml`, `ExplorerHome.qml`, `ExplorerView.qml`, `FeedState.qml`,
`colors.js`.

**Drei Messungen haben die Bauform bestimmt** -- ausfuehrlich in
`DOKUMENTATION.md`, Abschnitt "Der geplante Block, lebendig":

    neu packen statt nachfuehren       99,7 % der Kacheln springen
    Vollform statt Aenderungen         634 kB je 2 s, 6 % CPU allein fuers Zerlegen
    ein pulsierender Punkt             5 % CPU

    Grundlast der Seite                5,0 %
    erster Entwurf                    16,0 %
    jetzt                              5,6 %

Gegenproben, die gelaufen sind: keine QML-Meldung in der eigenstaendigen
Anwendung und in DMS, `dms ipc call dash toggle bitcoin` meldet
`DASH_TOGGLE_SUCCESS`, und 18 Sekunden nach dem Beenden der Anwendung meldet
sich der Daemon beim Server wieder ab (`tracking: null`).

## Stand 02.09.2026, Abend -- dreizehn Sprachen

Die Oberflaeche spricht Deutsch, Englisch, Spanisch, Franzoesisch,
Italienisch, Niederlaendisch, Polnisch, Portugiesisch (Portugal und Brasilien
getrennt), Tschechisch, Russisch, Japanisch und Chinesisch. Umgeschaltet wird in den Einstellungen unter "Allgemein", die
Umstellung greift sofort und ohne Neustart.

`ui/qml/strings.js`: rund 300 Schluessel, je Schluessel eine Zeile mit einem
Eintrag pro Sprache. `t(key, lang)` ist eine reine Funktion -- gibt man `lang`
mit, haengt die Bindung daran. Ein Singleton ginge nicht, weil dieselben
Dateien in drei Wirten laufen und ein `qmldir` nur im CMake-Modul entsteht.

**Zahlen gehoeren zur Sprache.** "1.234" heisst je nach Sprache
tausendzweihundert oder eins Komma zwei. `Tr.group` und `Tr.fixed` setzen die
Trennzeichen jetzt nach Sprache; vorher stand `.replace(".", ",")` an vierzig
Stellen.

**Zwei Fallen dabei:**
1. **Ein `.import` in einer `.pragma library` traegt nicht** -- das Laden
   scheitert stumm zur Laufzeit ("Script … unavailable"). `money.js` kennt
   deshalb nur noch Kurs und Zeichen, geschrieben wird in `strings.js`.
2. **Regulaere Ausdruecke taugen nicht zum Umbauen von Quelltext.** Der
   Versuch, `x.toFixed(2).replace(".", ",")` maschinell zu ersetzen, hat in
   acht Dateien Ausdruecke zerrissen. Fundstellen auflisten und einzeln
   ersetzen.

## Stand 02.09.2026, spaeter Nachmittag -- Einstellungen ausgebaut

Jeder Reiter hat jetzt seine eigenen Einstellungen, dazu "Allgemein" fuer alles
Uebergreifende. **Waehrung: sieben statt zwei** -- der WebSocket liefert USD,
EUR, GBP, CAD, CHF, AUD und JPY in derselben Nachricht mit, der Daemon warf
fuenf davon weg. Umgerechnet wird jetzt an einer Stelle (`money.js`).

Ein- und ausblendbar ist praktisch alles: im Feed Kopf-, Fusszeile,
Blockangaben, Kachelgrafik, Legende, Trennlinie und Weichzeichnung; in der
BlockClock fuenf Kennzahlen einzeln plus Balken, Kurve und **Uhrzeit**; beim
Miner sechs Kennzahlen plus Kurve, Rechenwerke und Bestenliste; im Explorer
fuenf Abschnitte der Startseite und die vier Tafeln einzeln.

**Falle, die dabei aufgeflogen ist: QSettings kann keine leere Liste.** Sie
wird als `@Invalid()` geschrieben und als ungueltiger Wert zurueckgelesen --
die Ansicht bekam etwas, das weder `length` noch `indexOf` hat. Die Anwendung
legt Listen jetzt als Zeichenkette ab (das Quickshell-Fenster braucht das
nicht, JSON kann leere Listen), und jeder Filter prueft zusaetzlich, ob
ueberhaupt eine Liste vorliegt.

**Sprache ist bewusst nicht eingebaut.** Die Zeile steht in den Einstellungen,
hat aber nur einen Eintrag. Eine Umschaltung muesste rund 300 Textstellen in
fuenfzehn Dateien erfassen -- ein eigener Arbeitsgang, und halb uebersetzt
waere schlechter als gar nicht. Der Weg stuende fest: `strings.js` mit
`t(key, lang)` und ein `lang` an jeder Ansicht, so wie schon `textColor`
durchgereicht wird. **Das ist die naechste Entscheidung des Nutzers.**

## Stand 02.09.2026, nachmittags -- Durchgang nach dem Ansehen

Nach einem Durchgang durch alle Reiter, Punkt fuer Punkt:

**Das Fenster aus `btcfeed-window` war die alte Fassung** -- nur der Feed,
keine Reiter. `shell.qml` hat jetzt dieselben Ansichten wie die eigenstaendige
Anwendung; zwei Fenster mit verschiedenem Inhalt waren nur verwirrend.

**Feed:** Abstaende im Zoom (gelandete Kacheln lagen auf gebrochenen
Koordinaten), die gestrichelte Linie doppelt und mitvergroessert, drei Lesarten
statt zwei (Alter/Gebuehr/Art), Weichzeichnung mit Maske in der Form des
Feldes, und die grosse Zahl im Blockfeld heisst jetzt "Bewegter Wert".

**Explorer:** Blockkacheln quadratisch und ohne den dunklen Schlagschatten,
Gebuehrenstufen mittig im Kaestchen, Pfeile im Flussdiagramm mit einem Winkel
und als Kerbe im Band statt als angesetztes Dreieck.

**Miner:** Kennzahlen verteilen sich ab sechs Stueck auf Zeilen zu je drei.

**Einstellungen:** neuer Reiter, gegliedert wie die Ansichten. Die
Wallet-Ansicht ist **zugesperrt** und erscheint erst nach einer Warnung, die
gelesen und bestaetigt werden muss.

**BlockClock:** Kennzahlen einzeln waehlbar, Waehrung Euro oder Dollar, und
**Moscow Time** ist dazugekommen.

### Was aus diesem Durchgang offen geblieben ist

1. **Kursverlauf mit Schieber** (Boersen-Optik). Braucht eine Datenreihe, die
   der Daemon nicht holt -- `/api/v1/historical-price` waere die Quelle.
2. **Freie Waehrungswahl.** Geliefert werden zurzeit nur Euro und Dollar.
3. **Wahl der Datenquelle je Ansicht.** Umgestellt wird bis auf Weiteres ueber
   `host` in `sources.json`, was den ganzen Feed umzieht.
4. Die **Halde** kann die Transaktionsart nicht zeigen -- der WebSocket
   liefert kein `flags`. Waere nur mit eigenem Node zu haben.

### Und ein Fehler, den ich selbst gebaut habe

Nach zwei neuen geteilten QML-Dateien lief `tools/install-links.sh`, aber
**nicht** `python3 daemon/btcfeed-dashtab` -- das Dashboard ging dadurch nicht
mehr auf. Dieselbe Falle wie schon dokumentiert. Beide Schritte gehoeren immer
zusammen.

Ausserdem: **`pkill -f "qs -p"` trifft auch DMS.** Beim Pruefen des
Quickshell-Fensters hat das die Leiste des Nutzers abgeschossen (systemd hat
sie sofort neu gestartet). Fuer Testfenster die PID merken und gezielt
beenden.

## Dazu am 02.09.2026: Blockhistorie und Transaktionsliste

"Alle Blöcke durchblättern" auf der Explorer-Startseite fuehrt in die
Blockhistorie: fuenfzehn Bloecke je Seite, rueckwaerts durch die Kette. In der
Blockansicht steht unter der Kachelgrafik dieselbe Liste der Reihe nach,
25 Transaktionen je Seite. Nachgeladen wird nichts -- die Zeilen stecken schon
in den Kacheldaten.

**Dabei einen aelteren Fehler gefunden und behoben:** ein abgeschalteter
`Loader` behaelt die Hoehe seines letzten Inhalts. Nach einer Blockansicht
stand deshalb ein 2571 Pixel hohes Nichts vor der naechsten Seite -- eine
`Column` laesst nur unsichtbare Kinder aus, keine leeren. `visible: active` an
allen vier Loadern. **Merksatz: `active` steuert den Inhalt, `visible` die
Flaeche.**

**Und eine Falle, die schon in der Dokumentation stand und trotzdem zugeschlagen
hat:** nach zwei neuen geteilten QML-Dateien lief `tools/install-links.sh`,
aber **nicht** `python3 daemon/btcfeed-dashtab` -- damit fehlten sie in der
DMS-Ueberlagerung, `ExplorerView` liess sich dort nicht mehr laden und **das
ganze Dashboard ging nicht mehr auf**. Beide Schritte gehoeren zusammen, jedes
Mal:

    tools/install-links.sh
    python3 daemon/btcfeed-dashtab
    systemctl --user restart dms
    dms ipc call dash toggle bitcoin      # muss DASH_TOGGLE_SUCCESS melden

## Dazu am 02.09.2026: beobachtete Wallets (watch-only)

Fuenfter Reiter "Wallet", im eigenen Fenster wie im Dashboard-Tab. Zeigt Saldo,
Verlauf, benutzte Adressen und die naechste unbenutzte Empfangsadresse.

**Der Sicherheitsgrundsatz hat den Bau bestimmt, nicht umgekehrt:**

- Im Daemon steht nur Punktarithmetik auf secp256k1 -- kein privater
  Schluessel, keine Signatur, nichts, was eine erzeugen koennte. Gehaertete
  Ableitung ist gar nicht moeglich.
- Der xpub verlaesst das Geraet nie; Adressen werden lokal abgeleitet und
  einzeln abgefragt.
- Eingetragen wird ueber die **Kommandozeile** (`btcfeed --watch-add`), nicht
  ueber die Oberflaeche: der Dienst nimmt weiterhin nichts entgegen.
- Ein privater Schluessel wird vor jeder anderen Pruefung abgewiesen, mit einer
  Meldung, die sagt warum.

**Zwei unabhaengige Gegenproben der Ableitung, beide bestanden:** die
Testvektoren aus SLIP-0132 und BIP-0084 (sechs von sechs) und **101 echte
Ausgaenge aus der Kette** in fuenf Skriptformen gegen `scriptpubkey_address`
von mempool.space, ohne Abweichung.

Nebenher entstanden: eigene Transaktionen bekommen in der Halde einen hellen
Rahmen (`m` an der Kachel, `FeedCanvas` zeichnet ihn) und einen Hinweis im
Tooltip.

Was fehlt: **Taproot (BIP86)** -- fuer P2TR gibt es kein eigenes Praefix, das
braeuchte eine ausdrueckliche Angabe der Adressform. Testnetz ebenfalls nicht.
Die Transaktionsliste ist ein Ausschnitt (hoechstens 15 abgefragte Adressen,
30 juengste Vorgaenge), kein Kontoauszug.

## Dazu am 02.09.2026: die Mempool-Goggles

Ueber jeder Kachelgrafik im Explorer steht jetzt "Farbe: Gebuehr | Art". In der
Betriebsart *Art* faerben sich die Kacheln nach dem, was die Transaktion tut,
mit Legende und Anteilen darunter.

Die Deutung kommt aus dem Bitfeld `flags`, das mempool.space in beiden Quellen
mitliefert. Die Bitlage ist aus dem Quelltext von mempool.space geholt und an
echten Daten gegengeprueft, nicht geraten. Neu: `ui/qml/TileGoggles.qml`,
`types` in den Kacheldaten, `fromFlags()` in `txtype.js`.

**Falle, die dabei fast zugeschlagen haette:** `>>` rechnet in JavaScript mit
32 Bit, die Flags reichen bis 2^44.

**Nebenbei einen echten Fehler gefunden und behoben:** die Suche nach einer
**Blockhoehe** war unbrauchbar ("Antwort nicht lesbar"). `/api/block-height/<n>`
antwortet mit dem blanken Hash, der Daemon reichte ihn als
`application/json` durch, und `JSON.parse` scheiterte.

**Zum Messen gelernt:** `top`-Momentaufnahmen taugen zum Vergleichen zweier
Bauformen, nicht als absolute Zahl. Ueber 60 Sekunden aus `/proc/<pid>/stat`
gemessen kostet die Startseite 6,3 % ohne und 6,9 bis 7,6 % mit laufendem
Mitverfolgen; die Goggles selbst kosten nichts Messbares.

**Werkzeug, das dabei entstanden ist und sich wieder lohnt:** die Anwendung
laesst sich in einem **unsichtbaren Compositor** pruefen, ohne den Bildschirm
zu uebernehmen --

    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 labwc &
    WAYLAND_DISPLAY=wayland-0 ./build/btcfeed-app &
    WAYLAND_DISPLAY=wayland-0 grim bild.png

Der Schirm ist 1280x720 gross und laesst sich ohne `wlr-randr` nicht
vergroessern -- alles darunter ist abgeschnitten. Das hat hier zweimal einen
Fehlalarm ausgeloest ("das Aufblitzen kommt nicht an"), bevor klar war, dass es
schlicht unterhalb der Fensterkante lag. Fuer die Registry-Screenshots
(Veroeffentlichung) ist derselbe Weg brauchbar.

---

## Stand 01.09.2026, Abend — Uebergabe

58 Commits an diesem Tag. Arbeitsbaum sauber, `btcfeed.service` laeuft ohne
Neustarts, DMS laeuft, die eigenstaendige App ist beendet.

Aus einem DMS-Plugin ist eine portable Anwendung mit vier Ansichten geworden.
Mechanik und Stolperfallen stehen in `DOKUMENTATION.md`, das Zielbild in
`ZIELBILD.md`.

## Was steht

**Grundlage**
- Repo `~/Schreibtisch/btcfeed` ist die Quelle der Wahrheit;
  `tools/install-links.sh` verteilt alles. **bitfeed als `git subtree`** unter
  `upstream/bitfeed/`, Historie erhalten.
- **`btcfeed` laeuft als abgesicherter Benutzerdienst** und bietet seine Daten
  unter `http://127.0.0.1:21021` an -- nur lesend, nur GET, gebunden auf
  Loopback. Abfragen: `/state`, `/block`, `/health`, `/lookup/<art>/<wert>`.
- **Die Grafik haengt an nichts ausser Qt Quick.** Dieselben QML-Dateien
  bedienen DMS-Plugin, Dashboard-Tab und die eigenstaendige Anwendung
  (`app/`, CMake, app_id `store._21rebel.btcfeed`).

**Vier Ansichten** (Tabs oder Tasten 1-4)
- **Feed** -- Halde und Block wie bitfeed, mit Zoom (Rad, Zusammenziehen,
  Ziehen), Tooltip, Klick auf eine Kachel fuehrt in den Explorer.
- **BlockClock** -- Blockhoehe gross, Gebuehr, Kurs, Mempool, Hashrate,
  Schwierigkeit mit Countdown, Halving.
- **Miner** -- AxeOS und cgminer, mehrere Geraete, Verlaufskurve, Bestenliste,
  Rechenwerke; Suche im eigenen Netz per `btcfeed --discover-miners`.
- **Explorer** -- Startseite mit Blockkette (geplant und bestaetigt in einer
  Leiste), vier Tafeln, letzte Transaktionen; Suche; Transaktions-, Block- und
  Adressansicht; Flussdiagramm; Kachelgrafik fuer bestaetigte **und** geplante
  Bloecke.

**Leisten** -- `btcfeed --waybar`, `--polybar`, `--genmon`, Vorlagen in
`packaging/bars/`.

## Offene Punkte, in der Reihenfolge, in der sie anzugehen sind

1. ~~Lebendige Darstellung des geplanten Blocks auf der Startseite.~~
   **Erledigt am 02.09.2026**, siehe unten.
2. ~~Mempool-Goggles.~~ **Erledigt am 02.09.2026**, siehe unten.
   Offen geblieben: die **Halde** im Feed kann nicht mit -- die
   `transactions`-Nachrichten des WebSocket fuehren kein `flags` mit
   (nachgesehen). Fuer den Block im Feed waere es moeglich, aber zwei
   Farblogiken in einem Bild waeren irrefuehrend.
3. ~~**Flatpak.**~~ **Erledigt am 02.09.2026**, siehe oben.
4. ~~**Layer-Shell**~~ **Erledigt am 02.09.2026**, siehe oben.
5. **Android-APK.** Werkzeugkette steht, das APK baut (02.09.2026). Offen:
   auf das Handy spielen -- **dafuer haengt der Nutzer sein Telefon an** --
   und vorher entscheiden, woher die Daten auf dem Handy kommen sollen
   (siehe oben, zwei Wege).
6. ~~WatchView (xpub, watch-only).~~ **Erledigt am 02.09.2026**, siehe unten.
7. ~~Blockhistorie mit Transaktionsliste zum Durchblaettern.~~
   **Erledigt am 02.09.2026**, siehe unten.

## Kleinigkeiten, notiert

- Der WebSocket liefert `rbfSummary`, `da` und `conversions` mit -- die holen
  wir teils per REST. Liesse sich zusammenlegen und spart Abfragen.
- Der Bitaxe war nur einmal erreichbar; die **cgminer-Familie** ist bis heute
  nur gegen nachgestellte Antworten geprueft.
- Dashboard-Tab: echte Einzelquadrate im Block braeuchten `implicitHeight` von
  410 auf rund 545.
- `FrostedPanel`: an den abgerundeten Ecken erscheint weichgezeichneter Inhalt
  ohne Einfaerbung (QML beschneidet nur rechteckig). Sauber ueber `maskEnabled`.
- Eine neue geteilte QML-Datei braucht den Eintrag in `app/CMakeLists.txt`
  **von Hand**; `install-links.sh` und `btcfeed-dashtab` lesen das Verzeichnis.
- "Angepasste vsize" und "Transaktion in Hex" fehlen in der Detailtafel.

## Die Erkenntnisse, die Zeit gekostet haben

Ausfuehrlich in `DOKUMENTATION.md`. Die wichtigsten in einem Satz:

- **`Item.visible` sagt nichts darueber, ob jemand hinsieht.** Schliesst das
  Fenster, bleibt es wahr. Kostete 7,4 % CPU im Leerlauf.
- **Lage und Strichstaerke sind zwei verschiedene Dinge.** Im Flussdiagramm
  bestimmt das Gewicht die Lage, die Dicke das Zeichnen -- werden sie
  gleichgesetzt, wird der Strang bei vielen Faeden achtmal zu dick.
- **Baender als Strich zeichnen, nicht als gefuellte Flaeche.** Zwischen zwei
  Kurven mit gleichem *senkrechtem* Abstand wird das Band in steilen
  Abschnitten duenner -- bei 60 Grad um die Haelfte.
- **Nicht im RGB-Raum mischen.** Blau und Orange liegen 177 Grad auseinander;
  ihre Mitte faellt auf 28 % Saettigung und wirkt grau.
- **Ein 4-px-Raster vertraegt nur ganzzahlige Rasterweiten und Massstaebe.**
  Alles andere erzeugt ungleiche Kacheln -- ausser unterhalb von zwei
  Bildpunkten je Zelle, dort ist gebrochen mit Kantenglaettung richtig.
- **`transform` skaliert Breite und Hoehe, nicht `x`/`y`.** Deshalb liegt die
  Zoom-Transformation auf Behaeltern bei (0,0).
- **`data` ist in QML belegt**, und `parent.parent.parent.x` in
  Repeater-Delegaten ist bruechig.
- **Qt schickt seine Meldungen ans Journal, nicht auf stderr.** QML-Fehler
  werden erst mit `QT_FORCE_STDERR_LOGGING=1` sichtbar.
- **`QT_RESOURCE_ALIAS` wirkt nur vor `qt_add_qml_module`.**
- **Offene Verbindungen taugen nicht als Aktivitaetsmass** -- Keep-Alive haelt
  sie, auch wenn niemand fragt. Deshalb zaehlt der Daemon jetzt seine Abfragen
  (`/health`, Feld `hits`).
- **Beim Messen die PID frisch holen.** Nach `systemctl restart` zeigt eine
  gemerkte PID ins Leere und liefert stillschweigend Unsinn.
- **`systemctl show -p MainPID` liefert waehrend eines Neustarts `0`** --
  `kill -9 0` trifft dann die ganze Prozessgruppe.

## Wie man morgen anfaengt

    cd ~/Schreibtisch/btcfeed
    git log --oneline -10
    systemctl --user status btcfeed
    curl -s http://127.0.0.1:21021/health

Aendert man etwas an den geteilten QML-Dateien:

    tools/install-links.sh          # verteilt alles
    python3 daemon/btcfeed-dashtab  # baut die DMS-Ueberlagerung neu
    systemctl --user restart dms

Die eigenstaendige Anwendung:

    cmake -S app -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build
    QT_FORCE_STDERR_LOGGING=1 ./build/btcfeed-app

**Nicht vergessen: die App nach dem Pruefen wieder beenden.** Sie kostet rund
7 % CPU, und genau das ist am 01.09. abends als hochdrehender Luefter
aufgefallen.

---

# Aeltere Notizen (31.08.2026, 18:15)


Aufbau, Formeln und Stolperfallen stehen in `DOKUMENTATION.md`. Hier nur, wo wir
stehengeblieben sind.

## Offene Punkte, in der Reihenfolge, in der sie anzugehen sind

### 1. Rueckschritt: die Transaktionen fallen nicht mehr sichtbar herunter — BEHOBEN 01.09.2026

**Nachgemessen, Ursache eingekreist.** Ein Zaehler ueber zwoelf Sekunden:

    flying 31  poolTx 31
    flying 36  poolTx 36
    flying 48  poolTx 48
    flying 59  poolTx 59

`flying` (die Liste der noch fallenden Kacheln) ist **immer genauso gross wie
die ganze Halde**. Keine Kachel verlaesst sie je. Eine Kachel fliegt aus
`flying` heraus, wenn `fly >= 1 && !pending` gilt; `pending` wird in
`poolCanvas.onPaint` zurueckgesetzt. Das passiert offenbar nicht -- entweder
zeichnet `poolCanvas` gar nicht, oder der Zweig wird nicht erreicht.

**Warum das die Fallanimation kaputtmacht:** Solange niemand `flying` leert,
zeichnet die Rechteck-Ebene (`flyLayer`) die **komplette** Halde statt nur der
fallenden. Sie hat aber `capacity: 320`. Sobald mehr als 320 Transaktionen in
der Halde liegen, bekommen die neu hereinfallenden **kein Rechteck mehr** und
sind waehrend des Fallens unsichtbar. Das passt genau zur Beobachtung: anfangs
fiel es, spaeter nicht mehr.

**Ursache und Behebung (01.09.2026).** In `step()` stand:

    if (e.fly >= 1) { e.pending = true; settled = true; }

Das setzt `pending` bei jedem Bild neu, solange die Kachel gelandet ist — also
dauerhaft. `step()` laeuft 30-mal pro Sekunde, `poolCanvas.onPaint` hoechstens
5-mal. Jedes `e.pending = false` aus dem Anstrich wurde im naechsten Bild sofort
ueberschrieben. Die Kachel verliess `flying` nie.

`poolCanvas` war unschuldig — es zeichnete die ganze Zeit korrekt.

Richtig ist der **Uebergang** statt des Zustands:

    var wasFlying = e.fly < 1;
    e.fly = span > 0 ? Math.min(1, e.fly + (e.vy * dt) / span) : 1;
    if (e.fly >= 1 && wasFlying) { e.pending = true; settled = true; }

Gefahrlos, weil Kacheln nur mit `fly < 1` in `flying` aufgenommen werden
(`addTx`), und ausreichend, weil `poolDirty` ein Riegel ist, der bis zum
Anstrich haelt.

**Nachgestellt und gegengeprueft** (Schleife mit 30 Bildern/s und
200-ms-Anstrich, Zulauf 5/s):

    nach  12 s   ALT: flying   60 / pool   60      NEU: flying 7 / pool   60
    nach  60 s   ALT: flying  300 / pool  300      NEU: flying 7 / pool  300
    nach 300 s   ALT: flying 1500 / pool 1500      NEU: flying 8 / pool 1500
                      davon 1180 nie gezeichnet         0 nie gezeichnet

Die alte Fassung trifft die am 31.08. gemessenen `flying 59 / poolTx 59` exakt.
Ab `capacity: 320` in `flyLayer` bekommen neue Kacheln kein Rechteck mehr —
daher "anfangs fiel es, spaeter nicht mehr".

### 2. Karomuster kommt auch von nicht-quadratischen Kacheln — BEHOBEN 01.09.2026

Am 01.09. unter dem neuen Zoom sofort sichtbar geworden. Es waren **drei**
verschiedene Ursachen, die alle gleich aussahen:

**(a) Der Block rechnete mit gebrochener Rasterweite.** `g = blockSide /
rowsUsed`, und `blockRect` rundet beide Kanten einzeln -- `x1 - x0` ergab also
je nach Nachkommastelle mal `floor(g*r)`, mal `ceil(g*r)`. Eine `r=1`-Kachel kam
als **3x3, 3x4, 4x3 oder 4x4** heraus. Behoben durch `blockUnit(rows)`:
`floor(blockSide / rows)`, also **ganzzahlig**. Der Block wird dadurch bis zu
`rowsUsed` Pixel kleiner als der Platz -- unsichtbar. Zusaetzlich sind `bx` und
`by` gerundet, sonst landen die Kanten trotz ganzem `g` auf halben Pixeln.

**(b) In der Halde steckt das animierte `scrollPx` in `targetY`.** Die
Unterkante schnappte dadurch anders als die Oberkante, die Kachel wurde ein
Pixel hoeher oder niedriger als breit. Behoben durch Rundung beim Zeichnen.

**(c) Der Zoom selbst, neu hinzugekommen.** Ein gebrochener Massstab macht jede
Kante gebrochen. Ein 4-px-Raster laesst sich nicht ungleichmaessig skalieren,
ohne dass Kacheln ungleich werden. Deshalb ist der Massstab jetzt
**ganzzahlig** (1x bis 24x, ein Radschritt = eine Stufe) und die Verschiebung
liegt auf ganzen Bildpunkten.

**Nachgerechnet** (blockRect nachgebildet, alte gegen neue Rasterweite):

    Blockseite 560 px, 73 Zeilen   ALT: 4796/15554 nicht quadratisch (30,8 %)
                                   NEU:     0/15554                  (0,0 %)
    ueber Blockseite 300..900 und 20..90 Zeilen, 20,4 Mio. Kacheln:
                                   ALT: 33,2 %      NEU: 0,0 %

### 3. Eigener Node als Datenquelle

Bisher haengt alles an `mempool.space`. Mit einem eigenen Node waeren die beiden
verbleibenden Unterschiede zum Original weg: die Halde koennte den **echten
Mempool-Inhalt** zeigen statt nur den Zulauf (kein Fuellen ueber eine
Viertelstunde mehr), und es gaebe **Abgangsereignisse** (RBF, Verfall) fuer die
Fallanimation nach unten aus dem Bild.

Anschlusspunkt: `~/.local/bin/btcfeed` ist die einzige Stelle, die Daten holt.
Ein zweites Backend dort einzuhaengen ist ueberschaubar.

**Was der Node koennen muss** (aus `server/bitcoin.conf.example` von bitfeed):

    txindex=1            # unpruned, voller Transaktionsindex
    server=1
    zmqpubrawtx=tcp://127.0.0.1:29001
    zmqpubrawblock=tcp://127.0.0.1:29000
    zmqpubsequence=tcp://127.0.0.1:29002

Der entscheidende Kanal ist **`zmqpubsequence`**: der meldet Zu- *und* Abgaenge
im Mempool. Genau das fehlt uns fuer die Fallanimation nach unten.

**Das ist das eigentliche Tor fuer alles Weitere:** unpruned plus txindex sind
rund 700 GB plus Index und mehrere Tage Erstsynchronisation. Steht der Node
nicht, aendert auch ein Fork von bitfeed nichts an den Daten, die wir bekommen.

### 4. Funktionen lokal abbilden — geklaert am 01.09.2026

Gewuenscht sind **alle vier Gruppen, jede einzeln ueber die Einstellungen
abschaltbar**:

1. **Explorer** — Suche nach TXID/Adresse/Block, Transaktionsdetails,
   Blockhistorie, Hervorhebung nach Adresse.
2. **Desktop-Anbindung** — Benachrichtigung bei neuem Block, Gebühren-Kachel,
   Leistenanzeigen, Schwellwert-Alarm.
3. **Eigene Adressen / Wallet-Bezug** — Adressen oder xpub beobachten, eigene
   Transaktionen in der Halde hervorheben, Bestaetigungszaehler, Fiat-Kurs.
4. **Solo-Mining (Bitaxe)** — Hashrate, Best-Difficulty gegen die
   Netzschwierigkeit, Alarm beim Blockfund. Siehe [[bitaxe-gamma-601]].

Dazu neu und richtungsweisend: **Android-App, um ein beliebiges Tablet zur
BlockClock zu machen.** Das erzwingt eine Client-Server-Trennung — der Daemon
muss eine Netzwerkschnittstelle bekommen, das Tablet hat keinen lokalen.

Ebenfalls festgelegt: Zielplattform ist **jeder Linux-Desktop**, nicht nur
DMS/Quickshell. Und die Datenquelle soll **umschaltbar** sein, mempool.space
oder eigener Node.

Ausarbeitung in `ZIELBILD.md`.

### 5. Bitfeed forken statt selbst bauen? -- ENTSCHIEDEN am 01.09.2026

**Empfehlung: als Backend und Referenz ja, als unsere Desktop-Anwendung nein.**

Begruendung: Was hier gebaut ist, ist keine Bitfeed-Kopie, sondern eine
**Shell-Integration** -- Leistenpille, Control-Center-Kachel, Desktop-Widget,
Dashboard-Tab. Das muss QML in DMS sein; ein geforkter Svelte-Client kann keins
davon werden. Nur beim grossen eigenen Fenster ueberschneiden sich die beiden.

Was ein Fork kostet: ein Browser-Motor auf dem Desktop (Electron/Tauri,
150-300 MB statt ~10 % CPU nativ), dazu Elixir und Svelte als Werkzeugketten,
und Upstream ist seit Juni 2022 still -- man pflegt ihn also selbst. Neue
Funktionen entstuenden in Svelte statt QML, die DMS-Anbindung liefe daneben
weiter: zwei Codebasen, zwei Datenwege.

Was ein Fork wirklich brauechte man dafuer: Suche, Transaktionsdetails,
Blockhistorie, Hervorhebung nach Adresse, Uebersetzungen -- alles fertig
vorhanden und in QML viel Arbeit.

**Vorgeschlagener Weg, der beides holt:**
1. Upstream unveraendert per Docker gegen den eigenen Node laufen lassen -- das
   Original mit allen Funktionen, ohne Fork und ohne Pflegeaufwand.
2. Den eigenen Daemon an den Node haengen statt an mempool.space (Punkt 3 oben).
   Eine Datei, kein neuer Stack.
3. Die QML-Seite bleibt in der Shell.

Faellt danach auf, dass das grosse eigene Fenster ueberfluessig ist, weil fuer
die Vollbildansicht ohnehin das Original genommen wird -- dann raus damit und
die Shell-Integration behalten.

**Entschieden am 01.09.2026: kein Fork des Clients. Der Fork sitzt auf der
Serverseite.** Ausschlaggebend war eine Messung statt einer Abwaegung:
`FeedCanvas.qml` (997 Zeilen) und `FeedPanel.qml` (558) importieren **nur
`QtQuick`** — zusammen mit den beiden JS-Dateien sind **1.851 von 2.004 Zeilen
schon plattformunabhaengig** und laufen unter Qt for Android wie auf jedem
Linux-Desktop. Die gesamte Quickshell-Bindung steckt in `FeedState.qml` (153
Zeilen, drei Stellen: `Quickshell.env`, `FileView`, `Process`).

Ein Client-Fork wuerde also ausgerechnet den fertigen, entwanzten Teil wegwerfen
— gegen Svelte-Code, der die hier behobenen Fehler noch enthaelt — und von den
vier gewuenschten Funktionsgruppen nur eine mitbringen (Explorer).

Als Datenquelle dagegen: **eigene mempool.space-Instanz**, weil `btcfeed` deren
API bereits spricht und `HOST` schon eine Variable ist. Der Elixir-Server von
bitfeed nur dann, falls die Abgangsereignisse fehlen. Vollstaendig in
`ZIELBILD.md`.

### 6. Veroeffentlichung auf GitHub

Vorher zu klaeren:
- **Lizenz und Herkunft.** `mondrian.js` und `colors.js` sind Portierungen aus
  bitfeed (MIT, mononaut). Die MIT-Lizenz verlangt, den Urheberrechtsvermerk
  und den Lizenztext mitzuliefern. Also: `LICENSE` von bitfeed beilegen, im
  README klar sagen, was portiert und was eigen ist. Die Quellenangaben stehen
  bereits in den Dateikoepfen.
- Das Repo braucht: `btcfeed`, `btcfeed-window`, `btcfeed-dashtab`, die fuenf
  Dateien aus `~/.local/share/btcfeed/qml/`, das Plugin-Verzeichnis, die
  Quickshell-App und ein Installationsskript, das die Symlinks setzt.
- Fuer die DMS-Plugin-Registry gelten die Regeln aus [[dms-plugin-entwicklung]]
  (eigenes oeffentliches Repo, Screenshot ist Pflicht, `id` in camelCase).

## Bitfeed selbst: gibt es das auch zum Selbstbetreiben?

Ja. `github.com/bitfeed-project/bitfeed` ist nicht nur die Website, sondern das
vollstaendige Projekt (MIT, 121 Sterne, letzter Push Juni 2022, nicht
archiviert):

- **client/** -- die Oberflaeche (Svelte + WebGL), das ist die Seite
- **server/** -- ein **Elixir**-Dienst (`mix.exs`, Phoenix), der an einem
  eigenen `bitcoind` haengt; im Verzeichnis liegen `Dockerfile`,
  `bitcoin.conf.example` und eine fertige `bitfeed.service`
- Fertige Wege laut README: **Docker**, sowie Ein-Klick-Integrationen fuer
  **Umbrel** und **Citadel**

Wer also einen eigenen Node hat, kann das Original vollstaendig selbst
betreiben. Fuer Punkt 3 oben ist das die naheliegende Referenz -- der
Elixir-Server zeigt genau, welche Node-Ereignisse die Oberflaeche braucht.

## Was heute lief und stimmt

- Foerderband-Halde ohne Loecher (0,00 % ueber 40 000 Kacheln nachgemessen)
- Halde auf ein Viertel der Fensterhoehe gedeckelt, gestrichelte Linie auf ihrer
  Oberkante
- Kachelgroesse fest (4 px + 1 px), unabhaengig von der Fensterbreite
- Keine Platzhalter mehr -- jede Kachel ist eine echte Transaktion
- Blockanimation: weiss aufleuchten, aus dem Bild heraufziehen, in Weiss
  zusammensetzen, dann Uebergang nach Orange
- Tooltip in Halde **und** Block, mit blaugruener Hervorhebung der Kachel
- Dashboard-Tab mit Zahnrad und Fenster-Knopf, ueber eine Symlink-Ueberlagerung
  ohne Eingriff in `/usr/share`
- Fenster mit echter Transparenz und Blur
- Rechenlast ~10 % im Vollbild
