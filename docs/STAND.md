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
## TAGESABSCHLUSS 17.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.11 ist fertig gebaut und signiert, aber nicht getaggt.** Die Nummer
steht an allen drei Stellen, zwoelf Aenderungen seit `v0.2.10`, der Pin zeigt
auf `d630c38`, die CI ist auf allen vier Jobs gruen. Das signierte APK liegt
in der Auslieferung, Windows ist geprueft und **zum ersten Mal seit Tagen mit
Daten**. Offen sind die beiden Linux-VMs, eine Nachschau am Galaxy und der
Text mit den Pruefsummen. Alles gepusht, Arbeitsbaum sauber, keine VM an,
der Dienst laeuft lokal -- noch mit dem Code von heute frueh.

### Was morgen als Erstes drankommt

1. **Galaxy**: das signierte APK (`7156ac36`) installieren und **direkt nach
   dem Start** in den Explorer, ganz nach unten: "Zuletzt im Mempool
   gesehen" muss zwoelf **verschiedene** Zeilen zeigen. Das ist die zweite
   Probe auf `d630c38`; unter Windows ist sie schon bestanden. Danach
   `adb shell wm user-rotation free`. Vorsicht: `tabRotate` ist am Telefon
   an, die Ansicht wandert alle 30 s weiter.
2. **Beide Linux-VMs** mit `build/flatpak-0.2.11/orangedeck.flatpak` (aus
   dem Lauf auf dem Pin-Commit): Ubuntu GNOME und Fedora KDE, frisch
   installiert, alle Reiter, Einstellungen ueber `,`.
3. **Punkt 8 der Pruefliste**: drei Pruefsummen und "Tested on" in
   `packaging/github/RELEASE-TEXT.md` (dort stehen PLATZHALTER), Stilpruefung
   wiederholen, `PRUEFSUMMEN.txt` und `geraetetest-0.2.11/` aufraeumen.
4. **Tag `v0.2.11` auf `d630c38`**, Release als Entwurf mit den drei Dateien.
   **Veroeffentlichen nur der Anwender.**
5. **Den Dienst neu starten** -- er laeuft noch ohne die Dubletten-Korrektur.
   Das setzt "zugehoert seit" fuer OKX und Bybit zurueck, darum nicht
   mittendrin.

### Was heute dazugekommen ist

Neun Commits, davon sechs am Code und an der Auslieferung.

| Was | Commit | Anstoss |
|---|---|---|
| Tooltip der Halde auf dem dunklen Untergrund der uebrigen Angaben | `11b6836` | Desktop-Optik-Sitzung |
| Schalter "Kaestchen hinter der Schrift" auf der DMS-Plugin-Seite | `20c995b` | lag seit gestern im Baum |
| Uebergabe der Desktop-Optik-Sitzung abgelegt | `573d380` | andere Sitzung |
| Nummer 0.2.11: CMakeLists, Manifest 14, Metainfo, Freigabetext | `76b8525` | Ablauf |
| STAND: Widgets haben die Nacht bestanden | `0d995ff` | Anwender |
| Bauplan auf `0d995ff` | `e786fa8` | CI rot |
| Dieselbe Transaktion nicht zweimal in "Zuletzt im Mempool gesehen" | `d630c38` | Geraetelauf |
| Bauplan auf `d630c38` | `1a2ed0c` | Ablauf |
| Werkzeug: `tools/win-tippen.py` | -- | heute dreimal gebraucht |

**Die Dateien von 0.2.11** (noch nicht veroeffentlicht):

    7156ac36fb4a2e406bb09cca7107f7be7e6937b4efb6cb52fc1fc590008b0496  orangedeck-0.2.11-arm64-v8a.apk (signiert)
    dc91255fdddb9deecd860e2641b554c34407aa8909d201aa4101e07145beaa00  orangedeck-0.2.11-arm64-v8a-unsigniert.apk
    Windows-ZIP und Flatpak liegen in build/zip-0.2.11/ und build/flatpak-0.2.11/,
    beide aus dem CI-Lauf 35278774885 auf dem Pin-Commit.

**Gemessen heute:**

- **Galaxy ueber Nacht, ohne dass die App geoeffnet wurde**: die Widgets
  hatten am Morgen saubere Daten. Damit traegt das Nachholen nach dem Doze
  (`fe60fd0`) ueber eine ganze Nacht. Im Protokoll steht derselbe Ablauf noch
  einmal ungestellt: um 16:21 fuenf Fehlschlaege mit
  `UnknownHostException`, jeder mit "Versuch 1 in 1 min", um 16:26 fuer alle
  zehn "Widget nachholen".
- **Galaxy, Release-APK 0.2.11 (erste Runde)**: Liquidationen bei `13y` und
  `Alles` mit Summen (Longs 2,9 M $, Shorts 4,6 M $, Balken bei 77.361 mit
  7,5 M), Long/Short von allen drei Boersen. Bei `1 Stunde` **der Leertext**,
  zum ersten Mal auf einem Bildschirm: "Noch keine Liquidationen in diesem
  Zeitraum. Sie kommen live dazu; rueckwirkend reicht nur OKX rund einen Tag
  zurueck." "Zugehoert seit 16.09. 16:43 (OKX), 17.09. 16:36 (Bybit)" --
  getrennt und ehrlich. Explorer mit der RBF-Tafel "vorher"/"neu".
- **Windows 11, VM, ZIP aus dem Pin-Lauf**: `curl` im Gast bekam
  `mempool 200` ueber IPv4, und danach **alle Ansichten mit Daten** -- Feed
  (Block 967.473, "vor 0 s"), Uhr (Moscow Time 1.312 sat, 956 EH/s), Mining
  (Kurve ueber ein Jahr), Explorer, Markt (Heatmap, 132 Trades). Registry
  noch so, wie 0.2.10 sie hinterlassen hat (`dataSource=direct`,
  `walletEnabled=false`). `,` oeffnet die Einstellungen, kein Wallet-Reiter,
  keine Datenquelle. Esc gibt das Suchfeld frei, Ende springt ans Seitenende.
  Widget bleibt bei Win+D stehen und zeigt Daten, Q schliesst Fenster und
  Widget. **Keine neue Defender-Erkennung**, die juengste ist vom 13.09.
- **Die Dubletten-Korrektur im echten Bau**: unter Windows direkt nach einem
  Neustart sechs verschiedene Zeilen, spaeter zwoelf verschiedene. Dazu
  dieselbe Probe auf beiden Seiten im Quelltext (dreimal derselbe Satz, dann
  zwei alte und ein neuer): vorher `a,b,c,a,b,c,a,b,d`, jetzt `a,b,c,d`,
  Nummern lueckenlos, Eintraege ohne TxID erhalten.
- **Der Untergrund hinter dem Tooltip kostet Rechenzeit**: am Pruefstand
  (Xvfb ohne GPU, 20 s Zeiger ueber der Halde, je zwei Laeufe) 478/489 %
  vorher gegen 581/602 % nachher, also rund ein Fuenftel mehr. Er haengt am
  Zeiger, und `FrostedPanel` zieht bei jeder Lageaenderung sofort einen neuen
  Ausschnitt, waehrend die vier anderen Felder stillstehen.
- **mempool.space antwortet wieder ueber IPv4** (200, Hoehe 967.462 am
  Nachmittag) -- die Sperre von gestern ist weg, auch aus dem QEMU-Gast.

**Beim Anwender eingerichtet und zurueckgenommen:** `win11` auf 4 GB und
zurueck auf 10240000 KiB, VM aus. Am Galaxy liegt 0.2.11 (erste Runde)
installiert; das signierte APK der zweiten Runde ist noch nicht drauf. Das
erste signierte APK liegt als `...-geraetetest-erste-runde.apk` in
`geraetetest-0.2.11/`, damit es nicht mit dem Release durcheinanderkommt.

### Die Erkenntnisse des Tages

**Ein Test, der nur nach der Korrektur gruen ist, beweist nichts.** Die Probe
zu den Dubletten lief erst gegen den reparierten Stand -- sauber. Erst der
zweite Lauf, gegen einen Arbeitsbaum auf dem Stand davor, hat gezeigt, dass
sie den Fehler ueberhaupt sieht: `a,b,c,a,b,c,a,b,d`. Seitdem gehoert der
Lauf gegen das Alte zur Probe dazu.

**Dieselbe Luecke lag an zwei Stellen.** `DirectFeed.qml` und `daemon/
orangedeck` bereiten denselben Zustand auf, absichtlich deckungsgleich. Der
Fund kam vom Telefon, die staerkere Ursache lag im Dienst: `poll_rest` holt
`/mempool/recent` bei **jedem** Durchlauf. Wer eine Aufbereitung zweimal hat,
repariert sie zweimal.

**Ein Klick ohne Mausbewegung ist kein Fokuswechsel.** Q schloss das
Windows-Widget nicht, und es sah nach einem Befund aus. Mit drei Zeigerpunkten
vor dem Klick ging es sofort. Dasselbe Muster wie am 16.09. mit dem
minimierten Fenster: erst der Zustand, dann die Taste.

**Der Fokus im Suchfeld schluckt die Tastenbefehle.** "Ende" tat unter Windows
nichts, weil der Explorer den Cursor im Suchfeld hat. Genau dafuer gibt es
seit gestern die Zeile "Esc Suche verlassen" -- sie hat sich heute selbst
bewiesen, an mir.

**"Springt von selbst zurueck" war `tabRotate`.** Am Galaxy wanderte die
Ansicht heute alle 30 s weiter, Explorer, Markt, Feed, ohne jede Eingabe. Der
Eintrag von gestern ("der Reiterwechsel des Anwenders") war falsch; es ist
eine Einstellung, und sie ist an diesem Telefon an.

**Die rote CI war die Wache, nicht der Fehler.** `bauplan-pruefen.py` hat den
Lauf angehalten, weil der Pin noch auf dem Stand von 0.2.10 zeigte -- ein Bau
daraus haette die Nummer 0.2.11 getragen und den Inhalt von 0.2.10. Windows,
Linux und macOS waren im selben Lauf gruen; nur das Flatpak faellt ueber die
Pruefung, und genau dafuer steht sie da.

**Ein Fund im Geraetelauf kostet eine Runde.** Das APK war gebaut und
signiert, bevor der Lauf durch war. Der Fund danach hiess: neu bauen, Pin ein
zweites Mal nachziehen, noch einmal signieren. Das Paket gehoert ans Ende der
Pruefliste, nicht in ihre Mitte.

### Und was ich selbst falsch gemacht habe

- **Das APK vor dem Geraetelauf gebaut** und den Anwender dadurch zweimal
  signieren lassen.
- **Bei der PIN zu schnell getippt**: 0,4 s Abstand, eine Ziffer ging
  verloren, ohne Meldung. Steht jetzt als 0,45 s in `tools/win-tippen.py`.
- **Q an ein Widget geschickt, das keinen Fokus hatte**, und es kurz fuer
  einen Befund gehalten.
- **Den Reiterwechsel am Galaxy erst fuer einen Fehler gehalten**, statt
  zuerst in den Einstellungen nachzusehen.
- **"0.2.10" pauschal durch "0.2.11" ersetzt** -- das traf auch die
  Ueberschrift "What's new since" und zwei Stellen im Kommentar, die von der
  Geschichte erzaehlen. Gefunden beim Gegenlesen, aber eine Ersetzung ueber
  eine ganze Datei liest keinen Sinn mit.

### Was sonst noch offen ist

1. **0.2.11 zu Ende bringen**: siehe oben, Punkte 1 bis 5.
2. **Der Tooltip-Untergrund** kostet rund ein Fuenftel mehr CPU, solange der
   Zeiger ueber der Halde wandert. Ein Riegel waere eine Zeile: das sofortige
   Nachziehen bei Lageaenderung abschaltbar machen und den Tooltip beim
   200-ms-Takt lassen. Nicht gemacht, das Aussehen ist abgenommen.
3. **Rollen in den Einstellungen** nicht nachgewiesen (Seite passte ins
   Fenster); am Galaxy ist Rollen ohnehin Finger.
4. **Waehrung um 12:55** (15.09.) stiess die Widgets nicht an. Nicht geklaert.
5. **`tools/ansichten-android.py`** mit KEYCODE_COMMA am Galaxy.
6. **Windows ungeprueft:** 600 MB im Markt, README-Startzeile in Win+R,
   Skalierung ueber 100 %, SmartScreen. **macOS** ungeprueft.
7. **`bitfeed`** ansehen (kitty, Hintergrund, CPU), dann Stufe 3 und 4.
8. **Technische Fehlermeldungen** aus dem Datenweg; **DMS-Anteil** nur
   deutsch; **Android 11** im Emulator.
9. **Idee fuer spaeter**: Wallet direkt auf dem Telefon.

### Fuer den naechsten Lauf

    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    ip route get <ziel>                       (welcher Weg, welches VPN)
    tools/apk.sh [<tag|commit>]  ->  bash ~/Schreibtisch/orangedeck/tools/apk-signieren.sh <v>  (Anwender)
    Test-APKs neben dem Release:
      env ORANGEDECK_APK_DIR=$HOME/.local/share/orangedeck/auslieferung/geraetetest-<v> tools/apk.sh
      vor jeder Runde das signierte umbenennen: ...-geraetetest-<name>.apk
    SIGNER=$(command ls -d ~/Android/sdk/build-tools/*/apksigner | sort -V | tail -1)
    Widgets anstossen: dasselbe APK neu installieren, Startbildschirm vorn
    Doze nachstellen:  adb shell dumpsys battery unplug; adb shell dumpsys deviceidle force-idle
      zurueck:         adb shell dumpsys deviceidle unforce; adb shell dumpsys battery reset
    Widget-Protokoll:  adb logcat -d -v time | grep -E ' (I|W)/OrangeDeck'
    Galaxy: tabRotate ist an, die Ansicht wandert alle 30 s -- zuegig schauen
    Bildschirm des Telefons: adb exec-out screencap -p > bild.png (1080x2340)
    python3 tools/bauplan-pruefen.py        (der Pin ist Punkt 5, vor dem Tag)
    gh run list --limit 5    (CI nur auf main, nicht auf Tags)
    gh run download <lauf> -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-<v>
    gh run download <lauf> -n orangedeck-flatpak -D build/flatpak-<v>
    ZIP ohne zip:  python3 -m zipfile -c <ziel>.zip <ordner>   (Ordner im ZIP wie der Name)
    Windows-VM:
      virsh -c qemu:///system setmaxmem win11 4G --config   (und setmem; danach 10240000)
      virsh -c qemu:///system start win11 ; Anmeldung: PIN vom Anwender
      python3 tools/win-tippen.py 'Z:\orangedeck\build\od-start.cmd'   (deutsche Belegung)
      dann KEY_ENTER; in Win+R nur Pfade, keine Schalter (ClickFix)
      Paket nach Z:\orangedeck\build\win-test, dann od-vorbereiten.cmd
      od-start.cmd | od-widget.cmd | od-defender.cmd | od-fokus.cmd, Ausgaben nach Z:
      Klick: erst drei Zeigerpunkte, dann die Taste -- sonst kein Fokuswechsel
      Bild: virsh -c qemu:///system screenshot win11 <datei>.ppm   (2560x1440)
    tools/pruefvm.sh bauen | starten | anhalten | gast
      Fedora:  setsid env ORANGEDECK_VM_ISO=$HOME/VMs/fedora-kde-44.iso tools/pruefvm.sh starten
      KRunner mit alt-spc, vor langen Zeilen  echo FOKUS-OK  und ein Bild
      Klicks:  python3 -c 'import sys; sys.path.insert(0,"tools"); import vm; vm.klick(x, y)'
    gh release create v<v> --draft --verify-tag --title "OrangeDeck <v>" --notes-file <text> <dateien>
    gh release edit v<v> --draft=false --latest   (nur der Anwender: Rechtepruefung)
    Pruefstand ohne Fenster:
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
          /usr/lib/qt6/bin/qml <datei>.qml      (Import als file:/... , kein absoluter Pfad)
      eine Aufbereitung allein pruefen: DirectFeed { active: false } und die Funktion rufen
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    Dienst im Test laden:  SourceFileLoader("od", "daemon/orangedeck") -- die
      __main__-Wache haelt ihn an, Feed() laesst sich einzeln pruefen
    laeuft ein Prozess:  ps -C <name>   (nicht pgrep -f)
    tools/install-links.sh --check        (neue Datei unter ui/qml: ZUERST verlinken)
    tools/install-links.sh && python3 -B daemon/orangedeck-dashtab && systemctl --user restart dms

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
| [16.09.2026](journal/2026-09-16.md) | 0.2.10 veroeffentlicht, acht Aenderungen fuer 0.2.11 auf main, Widgets im Doze nachgestellt, OKX reicht nur 24 Stunden zurueck. |
| [15.09.2026](journal/2026-09-15.md) | Alles fuer 0.2.10 auf main: Widgets ohne leere Kacheln, der Dienst-Weg repariert und unter Android und Windows entfernt, Zahnrad per Taste. |
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
