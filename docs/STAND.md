# Stand und offene Punkte — 31.08.2026, 18:15
# Ergaenzt 01.09.2026: Punkte 4 und 5 sind entschieden, siehe `ZIELBILD.md`

Aufbau, Formeln und Stolperfallen stehen in `DOKUMENTATION.md`. Hier nur, wo wir
stehengeblieben sind.

## Offene Punkte, in der Reihenfolge, in der sie anzugehen sind

### 1. Rueckschritt: die Transaktionen fallen nicht mehr sichtbar herunter

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

**Wo nachsehen:**
- `FeedCanvas.qml`, Timer mit `interval: 200` -> setzt `poolDirty` zurueck und
  ruft `poolCanvas.requestPaint()`
- `poolCanvas.onPaint`: der fruehe Ausstieg (`if (!root.layout || !root.poolTx)
  return;`) und die Zeile `e.pending = false;`
- Gegenprobe: einen Zaehler in `onPaint` hochzaehlen und mitloggen

**Wie es hereinkam:** durch das Zusammenspiel zweier Aenderungen von heute --
die Umstellung von "ueber alle Kacheln laufen" auf "nur ueber `flying` laufen"
(Rechenlast 16 % -> 10 %) und die Korrektur gegen das Wegblinken gelandeter
Kacheln ("bleib in `flying`, bis die Halde gezeichnet ist").

### 2. Karomuster kommt auch von nicht-quadratischen Kacheln

Beobachtung vom 31.08.: die ungleichen Luecken sind zwar behoben (Kanten werden
gerundet, siehe Stolperfalle 16), aber es bleibt ein Muster, weil manche Kacheln
nicht quadratisch gezeichnet werden. Naechster Schritt: in `blockRect` pruefen,
ob `w` und `h` auseinanderlaufen -- bei gerundeten Kanten kann ein Quadrat als
Rechteck von z. B. 3x4 herauskommen. Ueberlegen, ob man auf die kleinere Kante
quadriert oder das Raster ganzzahlig macht.

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
und Upstream ist seit Juni 2024 still -- man pflegt ihn also selbst. Neue
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
vollstaendige Projekt (MIT, 121 Sterne, letzter Push Juni 2024, nicht
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
