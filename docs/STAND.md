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
## TAGESABSCHLUSS 15.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**Alles fuer 0.2.10 liegt auf `main`, aber es ist nichts getaggt**: Zahnrad
per Taste, vier Feinheiten im Markt ohne Dienst, Widgets ohne leere Kacheln,
und unter Android und Windows **keine Wallet und kein Dienst-Weg mehr**. Am
Galaxy laeuft das Test-APK aus dem Stand `2c0cc24`; `1e0720f` (nur DMS) und
`b812c4e` sind danach dazugekommen. Gepusht bis `b812c4e`, Arbeitsbaum
sauber, der Dienst lauscht wieder nur lokal.

### Was morgen als Erstes drankommt

Die Entscheidung ueber 0.2.10. Wenn ja, die Pruefliste in
`packaging/github/RELEASE-TEXT.md`, und dabei zuerst:

1. **Freigabetext und Metainfo**: sie muessen sagen, dass Wallet und "Dienst
   auf einem anderen Geraet" unter Android und Windows wegfallen. 0.2.9 hat
   beides dort als Neuerung angekuendigt.
2. **Windows-VM**: der Wegfall ist dort ungeprueft, auch ein frueher
   gespeichertes "Eigener Dienst".
3. **Linux in beiden Pruef-VMs**, jetzt mit Klicks (`vm.klick`).
4. **APK aus dem Pin-Commit**, Geraetelauf am Galaxy mit `b812c4e`
   (MarketView mit `Bound`).

### Was heute dazugekommen ist

11 Commits, alle gepusht.

| Was | Commit | Anstoss |
|---|---|---|
| Freigabevorlage: eine Pruefliste fuer jede Nummer | `aac3424` | Erkenntnis vom 14.09. |
| Zahnrad auf der Tastatur: `,` oeffnet, Esc schliesst | `8241f4a` | Pruef-VM |
| Markt ohne Dienst: Long/Short sofort, Bybit mit eigenem "seit", Heatmap faengt Ausfaelle ab, Kneifen um die Fingermitte | `4bdaa94` | Liste, Punkt 3 |
| Dienst: OKX-Liquidationen nachholen, Sekundenring entfernt | `7b3d2d4` | Liste, Punkt 4 |
| Pruef-VM: Klicks ueber QMP | `972d6f7` | Liste, Punkt 7 |
| Widgets: sofort zeichnen, ein Budget fuer alle Abrufe | `6924dd7` | leere Widgets am Galaxy |
| Widgets: vor dem Freigeben zeichnen | `b63bdc4` | "..." blieb stehen |
| Dienst auf einem anderen Geraet: Adresse wurde verworfen | `fa6322c` | Liste, Punkt 2 |
| Wallet und Dienst-Weg nur noch unter Linux | `2c0cc24` | Anwender |
| Desktop-Widget: Umschaltungen wurden verworfen | `1e0720f` | andere Sitzung, gegengelesen |
| OKX-Nachholen mit 30 Seiten, MarketView mit `Bound` | `b812c4e` | Liste, Punkte 5 und 8 |

**Gemessen heute:**

- **Galaxy, Test-APK**: Markt vom Anwender angesehen ("schaut soweit gut
  aus"), Widgets ohne ANR (acht in 1,6 s ohne VPN, mit VPN je rund 1 s),
  Waehrung auf EUR stoesst alle zehn an, Wallet-Reiter und
  Dienst-Einstellungen fehlen.
- **Xvfb**: `,` oeffnet die Einstellungen, zweimal `,` oder `,` und Esc
  fuehren zurueck (Texterkennung).
- **Pruefstand ohne Fenster**: Long/Short nach 1,9 s mit der ersten Boerse,
  Bybit-`since` fest, Heatmap 1977 Zellen; `MarketView` mit `Bound` in 900 und
  384 Punkten ohne Laufzeitmeldung.
- **Pruef-VM**: `vm.klick(618, 336)` traf "Deutsch" im Ubuntu-Dialog.
- **Dienst**: OKX nachgeholt, 3000 Marken in 26 s bis 16,6 h zurueck; laeuft
  damit.

**Beim Anwender eingerichtet und wieder zurueckgenommen:** der Dienst war fuer
den Test ins WLAN geoeffnet (Drop-in `lan.conf`, ufw nur fuer 192.168.100.6)
und ist wieder zu -- Drop-in weg, Regel geloescht, lauscht auf `127.0.0.1`.
Die BIP84-Test-zpub stand kurz im Dienst und ist entfernt. **Geloescht nach
Freigabe:** `~/.cache/orangedeck-fp` (1,7 GB) und die Fassungen 0.2.0 bis 0.2.8
im Auslieferungsordner (34 Dateien, 918 MB). Test-APKs dieses Tages liegen in
`~/.local/share/orangedeck/auslieferung/geraetetest-0.2.10/`, umbenannt je
Runde; das Release-APK von 0.2.9 blieb unberuehrt.

### Die Erkenntnis des Tages

**Ein Zaehler beantwortet "kommt ueberhaupt etwas an" in einer Minute.** Der
Befund vom 13.09., "die Shell erreicht den Dienst, die App nie", wurde als
Netzfrage abgelegt und stand so im Release. Heute zeigte `hits` in `/health`:
von der App kam keine einzige Anfrage. Die Ursache war eine fehlende Zeile in
`setOpt` -- die eingetragene Adresse fiel stillschweigend weg, auf jedem
Geraet. Kein VPN, keine Firewall.

Die zweite: **Leere Kacheln und leere Ansichten waren zweimal das Netz, einmal
die App.** mempool.space antwortete dem NordVPN-Ausgang des Galaxy nicht
(github ueber dasselbe VPN schon, der Rechner ueber ProtonVPN auch). Die
Widgets machten daraus aber einen Prozess, den Android nach elf Sekunden
beendete, ohne je zu zeichnen -- das war die App. Erst beides getrennt
betrachtet ergab ein richtiges Bild.

Die dritte: **Nach `goAsync().finish()` friert Android den Prozess ein.** Ein
Faden, der danach noch zeichnen soll, zeichnet nie. Gezeichnet wird vor dem
Freigeben, oder gar nicht.

Dazu, alle gemessen:

- `am broadcast` mit APPWIDGET_UPDATE verweigert Android der Shell
  (`SecurityException`). Verlaesslicher Anstoss aller Widgets: dasselbe APK
  neu installieren, **waehrend der Startbildschirm vorn ist** -- aus den
  Einstellungen heraus kam keine Runde.
- Die OKX-Seiten laufen sauber rueckwaerts, die Dichte schwankt aber stark:
  bei einer Kaskade decken 100 Marken nur Minuten.
- `echo | nc -w 8` misst nicht den Verbindungsaufbau, sondern wartet, bis der
  Server schliesst. Fuer Zeiten eine HTTP-Anfrage mit erster Antwortzeile.
- `date +%s%N` rechnet in der Shell des Galaxy ueber -- rohe Zeitstempel
  ausgeben, auf dem Rechner rechnen.
- Die Shell des Galaxy hat `nc` und `toybox`, kein `curl`, kein `wget`.
- `pgrep -f muster` findet die eigene Befehlszeile (wieder, wie am 05.09.);
  `ps -C name` statt dessen.
- Das Galaxy verlor die USB-Verbindung heute dreimal.

### Und was ich selbst falsch gemacht habe

- **"Der Rechner ohne VPN" behauptet**, ohne nachzusehen -- er laeuft ueber
  ProtonVPN. Der Anwender hat es korrigiert; `ip route get <ziel>` zuerst.
- **Die Wallet-Abfragen dem Telefon zugeschrieben**, obwohl der Reiter dort
  noch aus war. Die Zaehler stammten von den lokalen Abnehmern.
- **Die erste Widget-Fassung liess den Abruf nach dem Freigeben weiterlaufen**
  -- genau der Fall, in dem Android einfriert. Erst am Geraet gesehen.
- **Zweimal eine untaugliche Zeitmessung am Telefon** (Ueberlauf, `nc`
  wartet auf das Schliessen), bevor die Zahlen stimmten.
- **`pgrep -f flatpak-builder`** meldete einen laufenden Bau, der keiner war;
  der Cache blieb dadurch einen Schritt lang liegen.
- **Ein `ls` auf Sockel, die QEMU noch nicht angelegt hatte**, brach den
  ersten VM-Start im Hintergrund ab.
- **"seit 0.2.10" in einen Kommentar geschrieben**, fuer eine Nummer, die es
  nicht gibt. Vor dem Commit berichtigt.

### Was sonst noch offen ist

1. **0.2.10**: siehe oben. Offen darin auch, ob der Freigabetext eine Wallet
   direkt auf dem Telefon (Ableitung in der App) als Weg zurueck nennt.
2. **Widgets bei haengendem Abruf**: "offline" statt "..." ist am Geraet nicht
   gesehen -- mempool.space antwortete seit dem Umbau immer.
3. **`tools/ansichten-android.py`** mit dem Weg ueber KEYCODE_COMMA am Galaxy
   laufen lassen (vom Anwender auf spaeter gelegt).
4. **Waehrung um 12:55**: stiess die Widgets nicht an, um 13:58 schon. Nicht
   geklaert.
5. **OKX-Nachholen**: auch 30 Seiten sind an unruhigen Tagen die Grenze, nicht
   der Tag.
6. **Test-APKs** in `geraetetest-0.2.10/` (vier Runden) und
   `geraetetest-0.2.9/` (542 MB, vom Anwender behalten) vor der Auslieferung
   wegraeumen, samt ihren Zeilen in `PRUEFSUMMEN.txt`.
7. **Unter Windows rund 600 MB Arbeitsspeicher im Markt** -- notiert, nicht
   verglichen.
8. **Idee, behalten**: in der Tastenhilfe "Esc verlaesst die Suche" fuer den
   Explorer (neuer Text in 13 Sprachen).
9. **Windows, ungeprueft:** ob die README-Startzeile in Win+R als ClickFix
   gilt; Skalierung ueber 100 %; SmartScreen beim Entpacken aus dem Netz.
   **macOS** ungeprueft, kein Geraet.
10. Vom 12.09. unveraendert: `bitfeed` ansehen (kitty, Hintergrund, CPU), dann
    Stufe 3 und 4; die Ansichten rollen nicht mit der Tastatur; technische
    Fehlermeldungen aus dem Datenweg; der DMS-Anteil ist deutsch; Android 11 im
    Emulator.
11. **Idee fuer spaeter**: Wallet direkt auf dem Telefon, die xpub bleibt dort
    -- falls sie jemand vermisst.

### Fuer den naechsten Lauf

    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    ip route get <ziel>                       (welcher Weg, welches VPN)
    tools/apk.sh [<tag|commit>]  ->  bash ~/Schreibtisch/orangedeck/tools/apk-signieren.sh <v>  (Anwender)
    Test-APKs neben dem Release:
      env ORANGEDECK_APK_DIR=$HOME/.local/share/orangedeck/auslieferung/geraetetest-<v> tools/apk.sh
      env ORANGEDECK_APK_DIR=... bash ~/Schreibtisch/orangedeck/tools/apk-signieren.sh <fassung>
      vor jeder Runde das signierte umbenennen: ...-geraetetest-<name>.apk
    SIGNER=$(command ls -d ~/Android/sdk/build-tools/*/apksigner | sort -V | tail -1)
    Widgets anstossen: dasselbe APK neu installieren, Startbildschirm vorn
    adb logcat -d -v time | grep -E "AppWidgetManager\(|bg anr|freezing"
    Kommt von der App etwas an:  /health -> hits, zweimal im Abstand von 10 s
    Galaxy-Shell: nc und toybox, kein curl; Zeitstempel roh ausgeben
    python3 tools/bauplan-pruefen.py
    gh run list --limit 5    (CI nur auf main, nicht auf Tags)
    gh run download <lauf> -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-<v>
    ZIP ohne zip:  python3 -m zipfile -c <ziel>.zip <ordner>
    tools/pruefvm.sh bauen | starten | anhalten | gast
      Fedora:  setsid env ORANGEDECK_VM_ISO=$HOME/VMs/fedora-kde-44.iso tools/pruefvm.sh starten
      KRunner mit alt-spc, vor langen Zeilen  echo FOKUS-OK  und ein Bild
      Klicks:  python3 -c 'import sys; sys.path.insert(0,"tools"); import vm; vm.klick(x, y)'
    gh release create v<v> --draft --verify-tag --title "OrangeDeck <v>" --notes-file <text> <dateien>
    gh release edit v<v> --notes-file <text> --draft=false --latest
    virsh -c qemu:///system setmem win11 4G --config      (und setmaxmem; danach 10240000)
    im Windows-Gast nur Skripte starten, keine Schalter in Win+R (ClickFix)
    Pruefstand ohne Fenster:
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
          /usr/lib/qt6/bin/qml <datei>.qml      (grabToImage, 384 Punkte = Galaxy)
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    laeuft ein Prozess:  ps -C <name>   (nicht pgrep -f)
    tools/install-links.sh --check
    tools/install-links.sh && python3 -B daemon/orangedeck-dashtab && systemctl --user restart dms

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
| [14.09.2026](journal/2026-09-14.md) | 0.2.9 veroeffentlicht, Linux in zwei VMs nachgeholt, Freigabetext ohne KI-typische Muster, Dashtab-Nachbearbeitungen uebernommen. |
| [13.09.2026](journal/2026-09-13.md) | 0.2.9 fertig getestet, der Markt ohne Dienst in der App, am Telefon bedienbar; Defender hielt die Testfernbedienung fuer ClickFix. |
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
