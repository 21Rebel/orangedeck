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
## TAGESABSCHLUSS 13.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.9 ist fertig getestet und wartet nur noch auf die Auslieferung.** Der
Markt laeuft seit heute **ohne Dienst** direkt in der Anwendung
(`DirectMarket.qml`), am Galaxy und unter Windows angesehen; am Telefon ist
er bedienbar geworden (Zahnrad statt Reiter, Kurzknoepfe, zwei Finger,
fluessiges Ziehen, Kerzen bleiben Kerzen). Alle Commits gepusht, letzter
`4cae9c3`.

### Was morgen als Erstes drankommt

**1. Auslieferung 0.2.9.** Vorlage `packaging/github/RELEASE-TEXT.md`, ihre
Pruefliste oben ist bis auf Punkt 3 und 4 abgehakt. Ablauf wie bei 0.2.8:

1. Im Auslieferungsordner (`~/.local/share/orangedeck/auslieferung/`) die
   Test-APKs von heute wegraeumen: `...-geraetetest-dienst.apk` und
   `...-geraetetest-markt1..7.apk`, dazu `orangedeck-0.2.9-arm64-v8a.apk`
   (signiertes Test-APK, 17:16), die `.idsig` und die Test-Zeilen in
   `PRUEFSUMMEN.txt`. Sonst verweigert `apk-signieren.sh` mit "Liegt bereits".
2. Tag `v0.2.9` auf den getesteten Stand, Flatpak-Pin nachziehen (der
   Flatpak-Job der CI ist bis dahin rot -- richtig so).
3. `tools/apk.sh v0.2.9`, signieren durch den Anwender, `tools/pruefvm.sh
   bauen`, Windows-ZIP aus dem CI-Lauf des Tags als
   `orangedeck-0.2.9-windows-x86_64.zip`.
4. Drei Pruefsummen und "Tested on" eintragen, Release als Entwurf,
   **veroeffentlichen nur mit ausdruecklichem OK**.

Getestet ist `053f502`; `4cae9c3` aendert nur Texte. Aendert sich an `app/`
oder `ui/` noch etwas, gelten die Messungen nicht mehr fuer den Tag.

**2. Die DMS-Verknuepfungen fuer `DirectMarket.qml`.** `tools/install-links.sh
--check` meldet die neue Datei in vier Shell-Ordnern als fehlend. Beheben mit
`tools/install-links.sh && python3 daemon/orangedeck-dashtab`, danach
`systemctl --user restart dms`. **Nicht heute gemacht**, weil an
`daemon/orangedeck-dashtab` eine andere Sitzung arbeitet (siehe unten).

### Was heute dazugekommen ist

7 Commits.

| Was | Commit | Anstoss |
|---|---|---|
| Dashboard-Tab nach dem Update auf DMS 1.6.1: eigene Kopie der Oberflaeche, Weiche im Drop-in | `69e3ac9` | DMS startete nach dem Update nicht mehr |
| Windows: Direktbezug mit Daten und Q (Hauptfenster, Widget) gemessen, Defender/ClickFix-Befund | `2fc25bd` | Plan von gestern |
| Der Markt ohne Dienst (`DirectMarket.qml`), Umbrueche am Telefon | `c509924` | Galaxy erreichte den Dienst im WLAN nicht; Anwender: "bauen wir das in der App" |
| Zahnrad statt Reiter, Kurzknoepfe, zwei Finger, feste Skala, Vorrat | `b2e415b` | Geraetelauf |
| Knopfhoehe, neues Zahnrad, eigener Zeitraum ohne Ueberlappung, Kerzenbuendelung | `0017a80` | Geraetelauf |
| Freigabevorlage: Galaxy nachgetragen | `053f502` | |
| Windows auf `053f502` nachgemessen, mit Markt | `4cae9c3` | Anwender |

**Neu im Projekt:** `ui/qml/DirectMarket.qml` (dritter Loader in `FeedState`,
Antworten Feld fuer Feld wie `/market`, `/market/overview`,
`/market/heatmap`); `FeedTabs.settingsTab`/`tabsRechts`; `views.reiter()` mit
viertem Parameter; `DropDown.anzeige`; in `MarketView` `kurzwahl`,
`EigenFeld`, `PinchHandler`, `sichtInfo`/`gebuendelt`/`buendeln`. In
`docs/DOKUMENTATION.md` die Kapitel "Nachgemessen am 13.09.2026: Direktbezug
und Q" und "Der Markt ohne Dienst (13.09.2026)".

**Beim Anwender eingerichtet:** Galaxy mit 0.2.9 (Stand von 17:16, entspricht
`0017a80`), Drehung freigegeben. Windows-VM wieder auf 10240000 KiB und aus.
Der Dienst lauscht wieder nur lokal, die `ufw`-Regel fuer das Telefon ist
geloescht (vom Anwender).

### Die Erkenntnis des Tages

**Ein Weg, der auf dem Papier geht, geht am Geraet noch lange nicht.** Der
Dienst im WLAN war offen, die Firewall frei, und die Shell des Telefons bekam
`/market` mit HTTP 200 -- die App nicht. Die Zaehler in `/health` belegten:
kein einziger `/market`-Aufruf von ihr. Ausgeschlossen wurden Firewall,
Klartext-HTTP, Androids Sperre des lokalen Netzes und ein VPN mit Sperre; die
Ursache ist offen. Statt weiterzusuchen hat der Anwender entschieden, den
Markt in die App zu holen -- und das war der bessere Weg, weil er unterwegs
genauso geht.

Die zweite: **Das Pruefwerkzeug kann den Befund erzeugen.** Defender beendete
unter Windows einen Prozess lautlos als `Behavior:Win32/SuspClickFix.F`,
ausgeloest von der Testfernbedienung, die eine lange Befehlszeile in Win+R
tippt -- genau das Muster der Masche. Am Vortag traf es viermal `curl.exe`,
unbemerkt. Es sah aus wie ein Absturz.

Die dritte: **Bilder aus dem Pruefstand finden, was Lesen nicht findet.**
`grabToImage` ohne Fenster in 384 Punkten Breite hat heute die abgeschnittenen
Legenden, den Ruecksprung aus dem Markt beim Start und die mitrutschende Skala
gezeigt, bevor jemand signieren musste. Zweimal hat es aber auch getaeuscht:
ein gesetzter Versatz zeichnet ohne Groessenaenderung nicht neu, und ein Fall
"mit Wallet" pruefte nichts, weil es die Wallet im Direktbezug nicht gibt.

Dazu, alle gemessen:

- **OKX liefert Liquidationen rueckwirkend**, per REST
  (`/api/v5/public/liquidation-orders`, `after` zum Blaettern): 402 Eintraege
  ueber rund 23 Stunden. Der Dienst haelt das seit dem 04.09. fuer unmoeglich.
  Binance `allForceOrders` gibt 404. Pythons `urllib` bekommt beim Blaettern
  403, `curl` und Qt nicht.
- **Die Heatmap braucht nichts Gesammeltes** -- Kerzen und
  `openInterestHist` (30 Tage) kommen beide per REST.
- **`ufw` protokolliert nur BLOCK.** Ein leeres Kernel-Protokoll beweist
  nicht, dass nichts ankam.
- **`qml` schreibt nichts nach stderr**, wenn stderr kein Terminal ist -- die
  Meldungen gehen ins Journal. `QT_FORCE_STDERR_LOGGING=1`.
- **PIN-Eingabe per `virsh send-key`** braucht `--holdtime` und Abstand
  zwischen den Tasten, sonst gehen Ziffern verloren. Klicks gehen ueber das
  USB-Tablet der VM (QMP `input-send-event`, absolute Achsen).
- **qmlcachegen uebersetzt Namen weg.** Lokale Variablen und selbst Eigenschaften
  wie `tabFont` stehen nicht als Text im APK; ob eine Aenderung drin ist, zeigen
  die Zeitstempel (QML-Datei, `.rcc/qmlcache/*.cpp`, APK).
- **Die Rechtepruefung von Claude Code** laesst es nicht zu, den Dienst ins WLAN
  zu oeffnen; das fuehrt der Anwender aus.

### Und was ich selbst falsch gemacht habe

- **`canMarket` an `Loader.Ready` gehaengt** -- warf bei jedem Start die
  gemerkte Ansicht Markt auf den Feed. Im Pruefstand gefunden.
- **Den Vorrat eingebaut, ohne die Folge fuer das Raster zu bedenken** --
  dadurch wechselte das Bild beim Verschieben zwischen Kerzen und Kurve. Am
  Galaxy gefunden, nicht vorher.
- **Im ersten Entwurf der Buendelung eine Bindungsschleife** ueber `padR`,
  vor dem Bauen entfernt.
- **"Kein einziges Paket vom Telefon" behauptet**, obwohl `ufw` erlaubte
  Pakete nicht protokolliert; zurueckgenommen. Danach NordVPN und `IIF_MATCH`
  als Hauptverdacht formuliert und wieder verworfen.
- **Messbefehle, die selbst falsch waren:** `set -- $r` in zsh, `ls` (bei
  diesem Anwender mit Symbolen) fuer einen Pfad, `strings` ohne `-el`, ein
  Pruefbild ohne Neuzeichnen. Jedes Mal zuerst ein falscher Befund.
- **Der erste Widget-Test am Abend startete das Widget gar nicht** (das
  Hauptfenster hielt den Fokus); die Zaehlung hatte trotzdem eine Zahl.
- **Neun Signierrunden fuer den Anwender.** Mehrere Aenderungen haetten sich
  in weniger Runden buendeln lassen.
- **Die Drehung am Telefon erst beim Abschluss freigegeben**, nicht nach dem
  ersten Test.

### Was sonst noch offen ist

1. **0.2.9 ausliefern** (siehe oben) und die DMS-Verknuepfungen.
2. **Warum die App den Dienst im WLAN nicht erreicht.** Galaxy A55, Android 16,
   NordVPN aktiv (nimmt 192.168.0.0/16 aber aus). Betrifft nur noch die Wallet
   auf Telefon und Tablet; im Freigabetext als ungeprueft genannt.
3. **`daemon/orangedeck-dashtab` ist geaendert und nicht committet** --
   Nachbearbeitungen aus `~/.config/orangedeck/dashtab-hooks.d` (dort
   `dms-leiste-patch`). Stammt aus einer anderen Sitzung des Anwenders; nicht
   angefasst.
4. **Markt ohne Dienst, Feinheiten:** `liqSince` ist fuer Bybit zu
   grosszuegig (Beginn des OKX-Rueckgriffs); die erste Antwort kommt ohne
   Long/Short; die Heatmap kommt gelegentlich mit `kein_oi`, wenn Binance
   Futures nicht rechtzeitig antwortet; Zoom mit zwei Fingern haelt den
   rechten Rand fest, nicht die Mitte zwischen den Fingern.
5. **Der Dienst koennte den OKX-Rueckgriff auch nutzen**, und
   `Market.kerzen()` darin wird nirgends aufgerufen.
6. **Unter Windows rund 600 MB Arbeitsspeicher im Markt** -- notiert, nicht
   mit dem Feed verglichen.
7. **qmllint in `MarketView.qml`: 55 Warnungen**, alle "Unqualified access"
   (Repeater-Delegates, `EigenFeld`). `pragma ComponentBehavior: Bound` wuerde
   sie loesen.
8. **Veraltet durch das Zahnrad:** `tools/ansichten.py` (Einstellungen ueber
   Ziffer 6) und `tools/ansichten-android.py` (sucht "Settings" in der
   Reiterzeile); in `docs/DOKUMENTATION.md` die Tabelle der Ansichten mit
   "5 | tab.settings" als Reiter.
9. **Windows, ungeprueft:** ob die README-Startzeile in Win+R eingefuegt
   ebenfalls als ClickFix gilt; Skalierung ueber 100 %; SmartScreen beim
   Entpacken aus dem Netz. **macOS** ungeprueft, kein Geraet.
10. Vom 12.09. unveraendert: `bitfeed` ansehen (kitty, Hintergrund, CPU), dann
    Stufe 3 und 4; die Ansichten rollen nicht mit der Tastatur; technische
    Fehlermeldungen aus dem Datenweg; der DMS-Anteil ist deutsch; Android 11 im
    Emulator; Aufraeumen von `~/.cache/orangedeck-fp` (rund 2 GB) und alten
    Fassungen im Auslieferungsordner.

### Fuer den naechsten Lauf

    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    tools/apk.sh [<tag>]  ->  bash tools/apk-signieren.sh 0.2.9  ->  adb install -r ...
    virsh -c qemu:///system setmem win11 4G --config      (und setmaxmem; danach 10240000)
    gh run download <lauf> -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-test
    im Gast nur Skripte starten: build/od-vorbereiten.cmd, od-markt.cmd, od-widget.cmd,
      od-prozess.cmd, od-defender.cmd -- keine Schalter in Win+R (ClickFix)
    Pruefstand ohne Fenster:
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
          /usr/lib/qt6/bin/qml <datei>.qml      (grabToImage, 384 Punkte = Galaxy)
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    tools/install-links.sh --check

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
| [12.09.2026](journal/2026-09-12.md) | Das erste Release 0.2.8, Windows startet zum ersten Mal, Markt und Wallet ueber einen Dienst im Netz, `bitfeed` als Entwurf. |
| [11.09.2026](journal/2026-09-11.md) | Derselbe Satz Ansichten auf jedem System: vier Befunde, die Nummer wanderte auf 0.2.8, und mempool.space drosselte diese Maschine. |
| [10.09.2026](journal/2026-09-10.md) | Dreimal getaggt, und jedes Mal kam am Telefon noch etwas. Widgets, Vollbild, Sprache des Systems. |
| [09.09.2026](journal/2026-09-09.md) | Acht Widgets, und eine Verwechslung, die Stunden gekostet hat: gezaehlt am Block statt an der Halde. |
| [08.09.2026](journal/2026-09-08.md) | Das Geraet fand dreizehn Befunde. Der Miner laeuft ohne Daemon, und `v0.2.2` zeigt auf einen Stand ohne jede Korrektur. |
| [07.09.2026](journal/2026-09-07.md) | Die Sicherung traegt, der Signaturschluessel existiert. Offen blieb nur der Push. |
| [06.09.2026](journal/2026-09-06.md) | orangedeck.dev ist live und zeigt den Mempool wirklich live; der Flathub-Antrag ging raus und war in einer Minute zu. |
| [05.09.2026](journal/2026-09-05.md) | Eigene Identitaet: eigene Domain, eigenes Zeichen, eine Kennung fuer alle Systeme. Die Auslieferung geradegezogen. |
| [04.09.2026](journal/2026-09-04.md) | Zum ersten Mal auf einem Rechner gelaufen, der nichts von diesem Projekt weiss. Die Pruef-VM entsteht. |
| [03.09.2026](journal/2026-09-03.md) | Das Projekt heisst OrangeDeck und ist oeffentlich. 394 Vorkommen umbenannt, zwei neue Ansichten. |
| [02.09.2026](journal/2026-09-02.md) | Blockuhr, Widgets, Flatpak, Layer-Shell, Android-APK, dreizehn Sprachen, Goggles, watch-only. |
| [01.09.2026](journal/2026-09-01.md) | Die erste Uebergabe: was steht, was offen ist, wie man morgen anfaengt. |
| [31.08.2026](journal/2026-08-31.md) | Die aeltesten Notizen. Woher `mondrian.js` und `colors.js` kommen, und ob Bitfeed sich selbst betreiben laesst. |
