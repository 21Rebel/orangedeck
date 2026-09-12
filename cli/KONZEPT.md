# OrangeDeck im Terminal -- Konzept

> Stand 12.09.2026. Noch kein Code. Entworfen aus dem Quelltext von Dienst und
> App (Routen, `DirectFeed.qml`, `mondrian.js`, `colors.js`), die
> Entscheidungen darunter hat der Anwender getroffen.

**Wunsch des Anwenders:** "mehr oder weniger die gleichen Funktionen wie in der
App, nur komplett ohne Wallet, aber komplett ueber das Terminal -- mit Befehlen
wie bitfeed, blockheight die Daten direkt abrufen, bzw. das Terminal-Fenster
mit den herunterfallenden Transaktionen ausstatten". Linux-Ricing-Stil. Nicht
Teil des App-Pakets.

## Entschieden

| Frage | Entscheidung |
|---|---|
| Aufruf | **Kurzbefehle ohne Praefix** (`bitfeed`, `mempool`, `miner` ...) |
| Sprache der Ausgabe | nach `LANG`: Deutsch, sonst Englisch |
| `bitfeed` ohne Dienst | **erlaubt**: eigener WebSocket zu mempool.space, mit den Grenzen unten |
| Terminal des Anwenders | kitty (0.48.2) unter niri |
| Wallet | bleibt draussen |

## Befehle

Ein Programm (`cli/orangedeck-cli`), das am Aufrufnamen erkennt, was gemeint
ist (`argv[0]`, busybox-Stil). Die Kurzbefehle sind Verknuepfungen darauf.

| Befehl | zeigt | Quelle |
|---|---|---|
| `bitfeed` | die fallenden Transaktionen, Vollbild; `--bg` als Hintergrund | Dienst `/state?since`, `/block` -- sonst WebSocket |
| `mempool` | Anzahl, Groesse, vB/s, geplante Bloecke | `/state` -- sonst REST |
| `blockheight` | Hoehe, Alter, Pool des letzten Blocks | `/state` `tip` |
| `fees` | schnell bis minimal, farbig nach Gebuehrenklasse | `/state` `fees` |
| `price` | Kurs, `--history 7d` mit Verlauf | `/state` `price`, `/prices` |
| `hashrate` | aktueller Wert, `--span 1y` mit Verlauf | `/state`, `/network` |
| `difficulty` | Fortschritt, erwartete Aenderung | `/state` `difficulty` |
| `halving` | Hoehe, restliche Bloecke, ungefaehre Tage | aus `tip.height`, wie `ClockView.qml` |
| `nextblock` | die geplanten Bloecke | `/state` `projected` |
| `blockinfo` | ein Block, `--tiles` als Kachelbild | `/lookup/blockheight`, `/lookup/blockinfo`, `/lookup/blocktiles` |
| `tx` | eine Transaktion | `/lookup/tx`, `/lookup/txstatus` |
| `miner` | der eigene Bitaxe (AxeOS, cgminer) | `/state` `miners` -- sonst AxeOS direkt |
| `market` | Kerzen, `--tape` als Band | nur Dienst (`/market`) |
| `btcfetch` | Uebersicht im fastfetch-Stil | `/state` |

Fuer alle: `--json`, `--raw`, `--watch[=SEK]`, `--source auto|daemon|direct`,
`--cur`, `--color auto|always|never` (keine Farbe ohne Terminal oder bei
`NO_COLOR`). Mit `--watch` schreibt ein Befehl eine Zeile je Aenderung --
damit laesst er sich dauerhaft in waybar oder polybar haengen, ohne jede
Sekunde neu zu starten.

**Namen, die ausscheiden -- auf dem Rechner des Anwenders nachgesehen:**
`block` ist ein eingebauter fish-Befehl und gewaenne immer. `next`, `fetch`,
`height`, `network` waren frei, sind aber so allgemein, dass andere Pakete sie
mitbringen; daher `nextblock`, `btcfetch`, `blockheight`.

**Einrichtung:** `orangedeck-cli install-aliases [--prefix ~/.local/bin]` legt
die Verknuepfungen an, **prueft jeden Namen vorher** (Programm im `PATH`,
fish-Funktion oder -Builtin) und ueberspringt belegte mit Warnung, statt zu
ueberschreiben. Ein Paket (AUR) legt die Kurzbefehle nicht nach `/usr/bin`.

## Datenquelle

    auto (Vorgabe)
      /health am Dienst, Frist 300 ms
        ├─ keine Antwort ───────────────► direkt zu mempool.space
        └─ antwortet
             ├─ Zustand frisch ─────────► Dienst
             └─ Dienst selbst offline ──► Fehler zeigen, NICHT direkt fragen
                                          (hinter derselben Adresse waere
                                           der Direktbezug ebenso gesperrt)

**Rueckhalt nach der IPv4-Sperre vom 11./12.09.2026** -- Pflicht, nicht Kuer:

- Zwischenspeicher unter `$XDG_CACHE_HOME/orangedeck-cli/`: Hoehe und Gebuehren
  30 s, Mempool 15 s, Schwierigkeit und Hashrate 300 s, Kursverlauf 1 h,
  bestaetigte Bloecke und Transaktionen unbegrenzt. Mit Dateisperre, damit drei
  Leistenmodule gleichzeitig nur eine Anfrage ausloesen.
- Untergrenzen fuer `--watch`: 1 s ueber den Dienst, 30 s direkt, 300 s fuer
  Schwierigkeit und Hashrate -- still angehoben, mit Hinweis.
- Bei 429, Zeitueberschreitung oder abgebrochenem TLS: Pause mit wachsender
  Wartezeit bis 15 min, **als Datei festgehalten**, damit auch neue Aufrufe
  warten.
- `bitfeed` direkt: ein WebSocket mit `blocks`, `stats`, `mempool-blocks`
  (rund 4 kB/s), **nie** `track-mempool` (250 kB/s). Faellt die Verbindung,
  dieselbe wachsende Pause.
- Eigene mempool-Instanz ueber `host`/`scheme` in `sources.json`, wie beim
  Dienst.

## `bitfeed` -- die fallenden Transaktionen

Uebernommen aus der App, nicht neu erfunden: Kachelgroesse
`ceil(log10(sat)) - 5` (1..5), Packung und Foerderband aus `mondrian.js`,
Farben aus der HCL-Formel in `colors.js` (Alter, Gebuehr, Art), Schwerkraft
`g = Hoehe * 1,1`, Pakete ueber 0,85 s verteilt, Warteschlange hoechstens 240,
Blockfund als Weiss mit Uebergang zu Orange.

**Zeichnen in Halbbloecken** (`▀` `▄`): jede Zeichenzelle traegt zwei nahezu
quadratische Pixel. Leere Pixel bleiben im Standardhintergrund -- ein
transparentes Terminal bleibt transparent. Truecolor, sonst 256 oder 16
Farben. Alternativer Bildschirm, Cursor aus, nur geaenderte Zellen schreiben,
Bildrate begrenzen; Groessenaenderung packt die Halde neu, statt sie zu
verlieren. Tasten wie in der App: `q`, `c`, `s`, `i`, `b`.

**In kitty -- beides am 12.09.2026 nur im Hilfetext nachgesehen, nicht
ausprobiert:**

- `kitten panel --edge=background` macht ein kitty-Fenster zum
  Desktop-Hintergrund. `bitfeed --bg` darin waere der Mempool als lebendes
  Hintergrundbild unter niri.
- kittys Grafikprotokoll (`kitten icat` ist vorhanden): dort liessen sich die
  Kacheln als echte Pixel zeichnen. Die Halbbloecke bleiben der Rueckfall fuer
  jedes andere Terminal.

## Technik

**Python, nur Standardbibliothek, eine Datei** -- wie der Dienst. Gruende:
Statusleisten laufen ueber `--watch` dauerhaft, die Startzeit faellt dort weg;
Farben, Gebuehrenklassen und Packung gibt es sonst in einer dritten Sprache.

**Das Dienst-Skript wird nicht importiert** (Seiteneffekte beim Laden, rund
160 ms Start). Die rund 150 Zeilen, die beide brauchen (`FEE_BUCKETS`,
Kachelgroesse, Transaktionsart, WebSocket-Client), werden uebernommen und von
einem Pruefskript gleich gehalten.

Faellt `bitfeed` bei der Messung ueber 10 % eines Kerns, wandert nur der
Zeichner in eine kompilierte Sprache; die Befehle bleiben.

## Stufen

| Stufe | Inhalt | grob |
|---|---|---|
| 1 | Geruest, Quellenwahl, Zwischenspeicher mit Pausen, Farberkennung, `--json/--raw/--watch`; `blockheight`, `fees`, `mempool`, `price`, `difficulty`, `hashrate`, `halving`, `nextblock`, `btcfetch`; `install-aliases` mit Namenspruefung | 3-4 Tage |
| 2 | `bitfeed`: WebSocket, Packung, Halbblock-Zeichner, Farben, Foerderband, Blockfund, `--bg`, CPU-Messung | 4-6 Tage |
| 3 | `blockinfo`/`tx` mit Kachelbild, volle Blockfund-Animation, kitty-Grafikprotokoll | 3-4 Tage |
| 4 | `market`, `miner`, Shell-Vervollstaendigung (fish zuerst), AUR-Paket | 3-5 Tage |

## Stand

**Stufe 1 steht (12.09.2026)**: `cli/orangedeck-cli` mit `blockheight`,
`fees`, `mempool`, `price`, `difficulty`, `hashrate`, `halving`, `nextblock`,
`btcfetch` und `install-aliases`/`remove-aliases`. Gemessen, nicht angenommen:

- alle neun gegen den laufenden Dienst, deutsch und englisch, mit `--raw` und
  `--json`;
- **die Farben gleich denen der App** -- die zehn Gebuehrenklassen und Orange
  aus Python gegen `colors.js` unter node gehalten, Ton fuer Ton;
- `install-aliases` in einem Testordner: legt an, erkennt die eigenen
  Verknuepfungen wieder, laesst eine fremde Datei gleichen Namens stehen,
  meldet `block` als `fish: builtin`; `remove-aliases` nimmt nur die eigenen;
- der Direktbezug mit eigenem Zwischenspeicher; die Untergrenze fuer `--watch`
  ("5 s ... es werden 30 s"); ein fehlender Dienst mit klarer Meldung.

**Ein Unterschied zwischen den Quellen, und er liegt bei mempool.space:**
ueber den Dienst kommen die Gebuehren aus dem WebSocket mit Nachkommastellen
(1,51 / 0,94), direkt aus `/v1/fees/recommended` gerundet (2 / 1).

Die CI uebersetzt Dienst und Terminal-Werkzeug und haelt `FEE_BUCKETS` an
allen drei Stellen gegeneinander.

## Offen

- `kitten panel --edge=background` unter niri einmal wirklich starten -- das
  legt etwas auf den Desktop des Anwenders, also nur mit seinem OK.
- Ob `bitfeed` im kitty-Grafikprotokoll fluessig genug zeichnet.
- Die Kurzbefehle wirklich in `~/.local/bin` anlegen -- bisher nur im
  Testordner, das richtige Verzeichnis gehoert dem Anwender.
