# Stand und offene Punkte

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
  (`app/`, CMake, app_id `dev.21rebel.btcfeed-app`).

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

1. **Lebendige Darstellung des geplanten Blocks auf der Startseite.**
   Die Datenseite steht bereits: der Daemon fuehrt den Block ueber
   `track-mempool-block` laufend mit (Aenderungen kosten 7,8 kB/s) und meldet
   sich 20 Sekunden nach der letzten Abfrage von selbst ab
   (`PROJECTED_LINGER`). Die Kachelgrafik gibt es. Offen ist nur die Ansicht,
   die sich mit dem Zulauf veraendert.
2. **Mempool-Goggles** -- dieselben Kacheln nach Transaktionsart einfaerben.
   `ui/qml/txtype.js` ist fertig und an echten Daten geprueft.
3. **Flatpak.** `flatpak` ist da, **`flatpak-builder` fehlt** und muesste
   installiert werden.
4. **Layer-Shell** (`layer-shell-qt`, in den Paketquellen, nicht installiert)
   fuer ein eigenes Desktop-Widget und eine eigene Leiste auf Wayland.
5. **Android-APK.** SDK und NDK fehlen; der frickeligste Teil.
   **>>> Vor diesem Schritt dem Nutzer Bescheid geben <<<** -- er haengt dann
   sein Handy an den Rechner (abgesprochen am 01.09.2026).
6. **WatchView** (xpub, watch-only). Der letzte grosse Brocken. Grundsatz steht
   in `ZIELBILD.md`: Adressen **lokal** ableiten, den xpub nie verschicken.
7. **Blockhistorie** mit Transaktionsliste zum Durchblaettern.

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
