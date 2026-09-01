# Zielbild — portable Anwendung, 01.09.2026

Beantwortet die in `STAND.md` offen gelassenen Punkte 4 und 5 und beschreibt,
wohin das Projekt gehen soll. Aufbau und Stolperfallen des Bestehenden stehen in
`DOKUMENTATION.md`.

Vorgaben aus dem Gespraech vom 01.09.:
- Alle vier Funktionsgruppen: Explorer, Desktop-Anbindung, eigene Adressen,
  Solo-Mining (Bitaxe). **Jede einzeln ueber die Einstellungen abschaltbar.**
- Lauffaehig auf **beliebigem Linux-Desktop**, ohne DMS und ohne Quickshell.
- **Android-Tablet als BlockClock** angedacht.
- Datenquelle **umschaltbar**: mempool.space oder eigener Node.

## Die Messung, die die Fork-Frage entscheidet

Am 01.09. nachgemessen, welche Teile des Bestandes ueberhaupt an Quickshell
haengen:

| Datei | Zeilen | Importe |
|---|---|---|
| `FeedCanvas.qml` | 997 | nur `QtQuick` |
| `FeedPanel.qml` | 558 | nur `QtQuick` |
| `mondrian.js` + `colors.js` | 296 | reines JavaScript |
| `FeedState.qml` | 153 | `Quickshell`, `Quickshell.Io` |

**1.851 von 2.004 QML-Zeilen sind bereits plattformunabhaengig** und laufen
unveraendert unter Qt Quick — auf jedem Linux-Desktop und unter Qt for Android.
Die gesamte Quickshell-Bindung sitzt in `FeedState.qml` und besteht aus genau
drei Dingen: `Quickshell.env`, `FileView`, `Process`.

Das dreht die Fork-Frage um: der teure, muehsam entwanzte Teil ist schon
portabel. Ein Fork des bitfeed-Clients wuerde genau diesen Teil wegwerfen — und
zwar gegen Svelte-Code, der die hier bereits behobenen Fehler noch enthaelt (die
wachsenden Loecher beim Abraeumen, der Flaechenverlust der Slot-Liste, siehe
Stolperfalle 0 in `DOKUMENTATION.md`).

## Entscheidung: Punkt 5 aus STAND.md, endgueltig

**Der Fork sitzt auf der Serverseite, nicht im Client.**

Was ein Client-Fork von den fuenf gewuenschten Funktionen brachte:

| Funktion | bringt der Fork mit? |
|---|---|
| Explorer (Suche, Details, Historie) | **ja** — als einzige |
| Desktop-Anbindung (Leiste, Kacheln, Benachrichtigungen) | nein, geht nur in QML |
| Eigene Adressen / Wallet | nein, gibt es dort auch nicht |
| Bitaxe / Solo-Mining | nein, gibt es dort auch nicht |
| Android-BlockClock | teils — als Website ueber den Browser |

Eine von fuenf, und ausgerechnet die, die im Kern aus HTTP-Abfragen und
Listenansichten besteht statt aus Grafik. Dagegen stehen: ein Browser-Motor auf
dem Desktop, Elixir und Svelte als zusaetzliche Werkzeugketten, Upstream seit
Juni 2022 still, und dauerhaft zwei Codebasen mit zwei Datenwegen, weil die
Shell-Integration in jedem Fall QML bleiben muss.

**Stattdessen als Datenquelle geforkt bzw. betrieben:**

1. **Eigene mempool.space-Instanz** (`github.com/mempool/mempool`) als Backend B.
   Der entscheidende Vorteil: `btcfeed` spricht diese API bereits, und der Wirt
   ist schon eine Variable — `WS_URL = f"wss://{HOST}/api/v1/ws"`. Der Wechsel
   auf den eigenen Node ist damit eine Konfigurationszeile, kein neuer Stack.
2. **bitfeeds Elixir-Server**, unveraendert per Docker, nur falls sich zeigt,
   dass die mempool-Instanz die **Abgangsereignisse** (RBF, Verfall) nicht
   liefert. Der Kanal `zmqpubsequence` ist der einzige Grund, ihn ueberhaupt
   anzufassen. **Noch nicht geprueft** — das gehoert an einen Prototypen, nicht
   an eine Annahme.

## Aufbau: drei Schichten, drei Ziele aus einer Quelle

### Schicht 1 — `btcfeedd`, der Datendienst

Aus dem heutigen `~/.local/bin/btcfeed` (515 Zeilen) wird ein Dienst mit
austauschbaren Quellen. Alle Quellen sind einzeln abschaltbar.

    source_mempool   mempool.space ODER eigene Instanz — nur HOST unterscheidet sie
    source_bitfeed   optional, Elixir-Server, nur fuer Abgangsereignisse
    source_bitaxe    HTTP gegen den Bitaxe: Hashrate, Best-Difficulty
    source_watch     Adressen/xpub ueber electrs
    source_price     Kurs fuer Fiat-Umrechnung und BlockClock

Ausgabe auf **zwei Wegen**:
- `state.json` in `$XDG_RUNTIME_DIR/btcfeed/` — wie heute, lokal, tmpfs
- **WebSocket auf einem Port** — neu, und die Voraussetzung fuer Android:
  das Tablet hat keinen lokalen Daemon, es holt sich alles vom Rechner im Netz.
  Wahlweise verbindet es sich auch direkt gegen mempool.space.

Betrieb als systemd-User-Unit. (Nebenbefund vom 01.09.: der Daemon laeuft
derzeit als loser Prozess, `systemctl --user is-active btcfeed` meldet
`inactive` — beim Umbau gleich miterledigen.)

### Schicht 2 — `btcfeed-ui`, die Darstellung

Ein Satz QML-Dateien fuer alle drei Ziele.

Unveraendert uebernommen: `FeedCanvas.qml`, `FeedPanel.qml`, `mondrian.js`,
`colors.js`.

`FeedState.qml` wird ersetzt: die drei Quickshell-Stellen weichen einer
plattformneutralen Anbindung (`QtWebSockets` bzw. `XMLHttpRequest`, beides in
reinem QML verfuegbar). **Danach gibt es keine Quickshell-Bindung mehr.**

Neue Ansichten, jede ueber die Einstellungen abschaltbar:

    ExplorerView   Suche nach TXID/Adresse/Block, Detailtafel, Blockhistorie
    WatchView      beobachtete Adressen; eigene TX in der Halde hervorgehoben
                   -- die Hervorhebung ist ein zusaetzliches Feld an der Kachel,
                   keine neue Grafik, also billig
    MinerView      Bitaxe: Hashrate, Best-Difficulty gegen Netzschwierigkeit,
                   Alarm beim Blockfund
    ClockView      BlockClock: Hoehe, Gebuehren, Kurs, Halving-Countdown --
                   gross, ohne Bedienung

Eine Einstellungsdatei, die auf allen drei Zielen gilt.

### Schicht 3 — Verpackung

- **a) Eigenstaendige Qt-Anwendung.** Gepackt als Flatpak (Wayland und X11,
  jeder Desktop) und AppImage. Das ist die Desktop-Unabhaengigkeit.
- **b) DMS/Quickshell-Plugin.** Bleibt, wird aber duenn: Leistenpille,
  Control-Center-Kachel, Desktop-Widget, Dashboard-Tab laden dieselben
  Komponenten aus Schicht 2. Kein zweiter Datenweg mehr.
- **c) Android-APK.** Qt for Android; `ClockView` als Startansicht, Vollbild,
  Display-an. Qt 6.11.2 liegt hier bereits, SDK und NDK fehlen noch
  (installiert ist nur `android-tools`).

## Sicherheitsgrundsatz: betrachten, niemals verfuegen — festgelegt 01.09.2026

**Die Anwendung ist ein Betrachter. Sie bekommt nie etwas in die Hand, mit dem
sich Geld bewegen liesse.** Ausdrueckliche Vorgabe vom 01.09.2026, angesichts
der Luecken, die zuletzt in Bitcoin-Produkten aufgetaucht sind. Der Zweck ist
eine Angriffsflaeche von null: geht hier etwas kaputt, darf niemandes Guthaben
betroffen sein.

Daraus folgt, verbindlich fuer jede spaetere Funktion:

| erlaubt | ausgeschlossen |
|---|---|
| Eingabe eines **xpub** (auch ypub/zpub) | privater Schluessel, Seed, Mnemonic |
| Ableiten von Adressen, Salden, Verlauf | Signieren, PSBT, Senden |
| beliebige oeffentliche Kennzahlen lesen | Wallet-Anbindung jeder Art |
| lokale Anzeige und Alarme | Schluesselverwaltung, Hardware-Wallet |

**Nur lesende HTTP-Abfragen gegen oeffentliche Endpunkte. Keine Bibliothek, die
signieren kann.** Damit ist der schlimmste denkbare Fehlerfall eine falsche
Zahl auf dem Bildschirm.

### Der Preis ist Privatsphaere, nicht Sicherheit

Watch-only schuetzt die Guthaben vollstaendig. Was bleibt, ist ein
Verkettungsproblem, und das gehoert offen benannt:

1. **Den xpub selbst nie verschicken.** Wird er an einen Dienst uebergeben,
   kennt dieser Betreiber schlagartig die gesamte Wallet — jede vergangene und
   jede kuenftige Adresse. Richtig ist: **Adressen lokal ableiten** und einzeln
   ueber `/api/address/:addr` abfragen. Der xpub verlaesst das Geraet nie.
2. **Auch das verkettet noch.** Wer 100 Adressen nacheinander von derselben
   Adresse abfragt, zeigt dem Betreiber, dass sie zusammengehoeren. Vollstaendig
   loesen laesst sich das nur mit eigenem electrs. Zwischenschritte: Abfragen
   streuen, optional ueber einen Proxy.
3. **Der xpub liegt lokal** in der Konfiguration, Datei auf `0600`.

Technisch angenehm: die oeffentliche Ableitung (BIP32) braucht nur
Punktaddition auf secp256k1, keine Signaturmathematik — das sind rund 50 Zeilen
reines Python ohne fremde Abhaengigkeit. Es gibt damit im ganzen Programm
keinen Code, der ueberhaupt signieren koennte.

## Weitere Kennzahlen und Grafiken — 01.09.2026 geprueft

Alle Endpunkte am 01.09.2026 gegen die oeffentliche API abgefragt und
bestaetigt:

    /api/v1/mining/hashrate/3d          Zeitreihe + currentHashrate + currentDifficulty
    /api/v1/difficulty-adjustment       Fortschritt, Aenderung, Restbloecke, Retarget-Datum
    /api/v1/fees/recommended            steckt bereits in state.json

Gemessene Beispielwerte: Hashrate rund 919 EH/s; Schwierigkeitsanpassung bei
69 % Fortschritt, +1,40 %, 625 Bloecke bis Hoehe 965.664.

Damit sind Hashrate-Verlauf, Schwierigkeitsanpassung mit Countdown und
Gebuehrenverlauf ohne Node darstellbar. Sie speisen zugleich die BlockClock
und die MinerView (Best-Difficulty des Bitaxe gegen die Netzschwierigkeit).

## Andere Ebenen: Liquid, Lightning, Ark — 01.09.2026 geprueft

**Liquid: faellt praktisch von selbst an.** `liquid.network` fuehrt dieselbe
API-Form. Geprueft: `/api/blocks/tip/height` → 4.043.120 und
`/api/v1/fees/recommended` antworten wie erwartet. Weil `HOST` in `btcfeed`
bereits eine Variable ist, ist die Umschaltung auf Liquid **derselbe
Handgriff wie die Umschaltung auf einen eigenen Node** — eine
Konfigurationszeile, dieselbe Grafik. Das ist die billigste der drei Ebenen.

**Lightning: eigene Endpunkte, eigene Ansicht.** `/api/v1/lightning/
statistics/latest` geprueft, liefert Kanalzahl, Knotenzahl, Gesamtkapazitaet,
Tor- gegen Clearnet-Knoten (Stand der Abfrage: 32.674 Kanaele, 16.232 Knoten).
Aber: Lightning hat keinen Mempool und keine Bloecke. Die Halde-und-Block-
Darstellung passt hier nicht — das wird eine **eigene Ansicht** (Kapazitaet,
Knoten, Gebuehrenraten im Zeitverlauf), keine Umschaltung der bestehenden.

**Ark: vorerst zurueckgestellt.** Es gibt einen Explorer
(`arkexplorer.blockonomics.co`, Blockonomics), aber **keine oeffentliche API in
der Form, die hier angebunden werden koennte**. Ohne eigene Datenquelle geht
das nicht. Erneut ansehen, wenn sich das aendert.

### Was das fuer den Aufbau heisst

Zwei verschiedene Dinge, nicht eines:

- **Kettenumschaltung** (Bitcoin / Liquid / eigener Node): eine Einstellung im
  Daemon, `HOST`. Dieselbe Grafik, dieselben Ansichten.
- **Zusatzansichten** (Lightning, Hashrate, Schwierigkeit, Bitaxe, Wallet):
  eigene Quell-Adapter im Daemon und eigene Ansichten in `ui/qml`, jede ueber
  die Einstellungen abschaltbar — wie alles Uebrige.

## Reihenfolge

Die ersten sechs Schritte brauchen **keinen Bitcoin-Node**.

    0. STAND.md Punkt 1 beheben (der pending-Reset). Sonst portiert man den
       Fehler mit. Klein.
    1. FeedState.qml entkoppeln. DER Schluesselschritt -- danach ist die
       gesamte Grafik plattformunabhaengig.
    2. btcfeedd: WebSocket-Ausgabe, Quell-Adapter, systemd-Unit.
    3. Eigenstaendige Qt-App + Flatpak. Damit ist "beliebiger Linux-Desktop"
       erreicht.
    4. DMS-Plugin auf die geteilten Komponenten umstellen.
    5. MinerView (Bitaxe) und ClockView. Beide klein und ohne Node machbar --
       deshalb frueh, sie zahlen sofort ein.
    6. Android-APK: SDK/NDK einrichten, Qt-Android-Build. Der frickelige Teil.
    ---- ab hier ist der Node Voraussetzung ----
    7. Node + eigene mempool-Instanz + electrs.
    8. ExplorerView und WatchView (gehen auch ohne Node -- siehe unten).

Nachtrag 01.09.2026: Schritt 8 ist **nicht** vom Node abhaengig. Gegen die
oeffentliche API sind `/api/address/:addr` und `/api/address/:addr/txs`
verfuegbar (geprueft, volle Transaktionsobjekte). Der Node verbessert nur die
Privatsphaere, siehe Sicherheitsgrundsatz. Einen `/api/v1/search`-Endpunkt gibt
es nicht -- die Suche wird ueber die Eingabeform aufgeloest: 64 Hex =
TXID/Blockhash, Zahl = Hoehe, sonst Adresse.

## Zwei harte Randbedingungen

**Platte.** 639 GB frei auf `/dev/nvme0n1p2` (952 GB gesamt, 33 % belegt). Ein
unpruned Node mit `txindex=1` liegt bei rund 700 GB und waechst; dazu kommen der
electrs-Index und die MariaDB der mempool-Instanz. Realistisch ist 1 TB, mit
Reserve eher 2 TB — und auf einer **eigenen Platte**, nicht der Systemplatte.
Solange die nicht da ist, sind Schritt 7 und 8 blockiert.

**electrs ist Pflicht fuer die Adressbeobachtung.** Am 01.09. in der Doku von
`mempool/mempool` nachgelesen: die Instanz laeuft auch ohne Electrum-Server,
aber *"address lookups will be disabled"*. Unterstuetzt sind `romanz/electrs`,
`cculianu/Fulcrum` und `mempool/electrs`. Ohne diese Komponente gibt es kein
WatchView und keine Adresssuche im Explorer.

## Lizenz

`mondrian.js` und `colors.js` bleiben gekennzeichnete Portierungen aus bitfeed
(MIT, mononaut); `LICENSE` beilegen. Kommt die mempool-Instanz oder bitfeeds
Server dazu, aendert das nichts — beide sind ebenfalls quelloffen und mit dem
Vorhaben vertraeglich. Details in STAND.md Punkt 6.
