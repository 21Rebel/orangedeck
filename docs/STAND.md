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
> **17.09.2026, aus der Desktop-Optik-Sitzung:** zwei Fehler am Desktop-Widget
> behoben (linke Taste zog das Fenster statt zu klicken; Tooltip blieb stehen),
> Tooltip abgedunkelt, Hintergrund und Blur der beiden Widgets aus. Ursache und
> alle Pfade stehen in `docs/UEBERGABE-2026-09-17-desktop-optik.md`. Die
> Aenderung an `ui/qml/FeedPanel.qml` ist uncommittet.

## TAGESABSCHLUSS 16.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.10 ist veroeffentlicht** ("Latest", Tag `v0.2.10` auf `e4e74ef`), und
auf `main` liegen **acht Aenderungen fuer 0.2.11**, noch ohne Nummer: die
Fassung in CMakeLists/Manifest ist weiter 0.2.10. Am Galaxy laeuft ein
Test-APK mit dem Nachholen der Widgets (Stand `fe60fd0`); ueber Nacht zeigt
sich, ob die Widgets nach dem Doze von selbst wieder Daten haben. Alles
gepusht, Arbeitsbaum sauber, der Dienst laeuft lokal, DMS mit `roll.js`
neu gestartet, keine VM an.

### Was morgen als Erstes drankommt

1. **Widgets am Galaxy ansehen, bevor die App geoeffnet wird.**
   - **Mit Daten**: bestanden. Weiter mit Punkt 2.
   - **"gerade nicht erreichbar"**: Galaxy anstecken, App **nicht** oeffnen,
     dann `adb logcat -d -v time | grep -E ' (I|W)/OrangeDeck'` -- Grund und
     ob Nachholversuche liefen. Laeuft der Puffer ueber, beim naechsten Mal
     mitschneiden.
2. **0.2.11 vorbereiten**, nach der Pruefliste oben in
   `packaging/github/RELEASE-TEXT.md`: Nummer an drei Stellen (CMakeLists,
   Manifest 14 / 0.2.11, Metainfo), Freigabetext, Pin, APK aus dem Pin,
   Galaxy, Windows-VM, beide Linux-VMs. **Die acht Aenderungen** seit
   `v0.2.10`:
   - Liquidationen bei "all" zeigen die laufende Woche (`116b2ce`, Dienst+App)
   - Leertext: OKX liefert einen Tag rueckwirkend (`3f4035e`)
   - Explorer, RBF-Spalten in jeder Sprache (`83171b1`)
   - Widgets holen nach einem Fehlschlag nach, sobald Netz da ist (`fe60fd0`)
   - Tastenhilfe "Esc Suche verlassen" (`4814067`)
   - Rollen mit der Tastatur (`cae3c06`, neue Datei `roll.js`)
   - OKX bis 24 h nachholen (`c40896a`, Dienst+App)
   - "zugehoert seit" rueckt beim Kuerzen mit (`c40896a`, Dienst+App)
3. **Vor dem Test mempool.space pruefen** (`curl -4`/`-6`): heute wieder
   IPv4-gesperrt. Ist die Sperre weg, laesst sich Windows mit Daten pruefen.

### Was heute dazugekommen ist

22 Commits (14 Code/Werkzeug, 8 Stand), Tag `v0.2.10`, Release.

| Was | Commit | Anstoss |
|---|---|---|
| Nummer 0.2.10; Metainfo und Freigabetext nennen den Wegfall der Wallet | `7d30b40` | Tagesabschluss 15.09. |
| Bauplan auf 0.2.10, dann auf `e4e74ef` | `65f858e`, `ab7c079` | Ablauf |
| Hinweis zur Dienstadresse: nicht mehr "Tablet und Telefon", 13 Sprachen | `e4e74ef` | Ubuntu-VM, vor dem Signieren |
| Freigabetext: Pruefsummen, Windows, Linux, Galaxy | `47e47b0`, `41711f0` | Ablauf |
| Tag `v0.2.10`, Entwurf; veroeffentlicht vom Anwender | -- | Anwender |
| Liquidationen bei "all": die laufende Woche fehlte | `116b2ce` | Galaxy, 13y leer |
| Leere Liquidationsansicht: OKX liefert einen Tag rueckwirkend | `3f4035e` | Galaxy |
| Explorer, RBF: "vorher"/"neu" in jeder Sprache | `83171b1` | beide Linux-VMs |
| Pruef-VM: KRunner unter Fedora ging nicht, Startmenue | `c8771d4` | Fedora-Lauf |
| Widgets: nach einem Fehlschlag nachholen, Grund ins Protokoll | `fe60fd0` | Galaxy, 08:53 |
| Tastenhilfe im Explorer: "Esc Suche verlassen" | `4814067` | Liste |
| Rollen mit der Tastatur: Bild auf/ab, Pos1, Ende | `cae3c06` | Liste, 12.09. |
| OKX bis 24 h nachholen; "seit" rueckt beim Kuerzen mit | `c40896a` | Liste; /market |
| Test-APKs 0.2.9 und 0.2.10 geloescht (869 MB) | `f812762` | Anwender |

**Die drei Dateien von 0.2.10** (SHA-256, im Release, von GitHub nach dem
Hochladen bestaetigt, in `PRUEFSUMMEN.txt`):

    9c446d2b396cea1730b89f1dc4195c2a577c85609b4033a24edf5eeb0eafb04f  orangedeck-0.2.10-windows-x86_64.zip
    14e7b7014c84a3138102486781a87eac995d7a9574b5611ad862de676428d25c  orangedeck-0.2.10-arm64-v8a.apk
    50d0ab4b459459951b9c1178cc9a3a27b3b712d915250d9bbb4e58c2bcea2737  orangedeck-0.2.10.flatpak

**Gemessen heute:**

- **Windows 11, VM, ZIP aus `65f858e`**: Registry wie nach 0.2.9
  (`dataSource=daemon`, `daemonHost`, `walletEnabled=true`) -- kein
  Wallet-Reiter, keine Datenquelle, Markt direkt mit Daten; `,` und Esc;
  Widget bleibt bei Win+D; Q schliesst Widget und Fenster; keine neue
  Defender-Erkennung, kein Absturz. Feed, Uhr, Mining ohne Daten (IPv4).
- **Ubuntu 24.04 und Fedora 44, Buendel aus `e4e74ef`**: alle Reiter, `,`,
  berichtigter Hinweistext, Markt ueber den Dienst mit Daten; Datenquelle
  und Wallet-Reiter unter Linux da. Feed, Uhr, Mining leer (IPv4).
- **Galaxy, Release-APK 0.2.10**: keine Wallet, keine Dienst-Einstellungen,
  Zurueck schliesst sie, Feed und Markt mit Daten, Long/Short von allen
  drei Boersen, Widgets nach dem Anstossen mit Daten, kein ANR.
- **Galaxy, Test-APK `...-geraetetest-liq`** (aus `d362ada`): 13y mit
  Summen (Longs 24,9 M $, Shorts 7,3 M $) statt leer; RBF-Tafel "vorher"/"neu".
- **Galaxy, Test-APK `...-geraetetest-nachholen`** (Stand `fe60fd0`):
  Bildschirm aus am Strom -- alle zehn Widgets kamen durch. Mit
  `deviceidle force-idle`: alle zehn `UnknownHostException` (Miner
  Zeitueberschreitung), zehn Jobs; nach `unforce` alle zehn sofort, 20
  Zeichnungen, keine Warnung, kein Job wartend; um 12:56 alle zehn auf dem
  Bildschirm mit Daten.
- **Xvfb, Desktop-App** (eigener `XDG_CONFIG_HOME`, ueber den Dienst):
  Taste 4 zeigt "Esc Suche verlassen"/"Esc Leave search", Esc und 1 zurueck
  zur vollen Hilfe; Mining Ende/Pos1, Explorer Ende/Bild auf; RBF englisch
  "old"/"new".
- **OKX per REST**: genau 24 h, danach leere Seiten -- 20 Seiten, 1874
  Marken, 9,7 s. In der Datei des Dienstes alle 24 Stunden mit OKX-Marken.
- **Dienst**: `/market?range=all` Marken vorher bis 15.09., nachher bis
  16.09.; `liqSince` vorher 04.09., nachher 14.09. 13:56 (48,0 h).

**Beim Anwender eingerichtet und zurueckgenommen:** `win11` 4 GB und zurueck
auf 10240000 KiB, aus; Registry dort absichtlich wie nach 0.2.9. Pruef-VM
aus. Galaxy: Drehung frei, Akku-Simulation und Doze zurueckgesetzt, Test-APK
`nachholen` installiert. Auslieferungsordner: nur 0.2.9 und 0.2.10 plus
`geraetetest-0.2.11/` (zwei signierte Test-APKs, umbenannt).
`PRUEFSUMMEN.txt` bereinigt. Neue Erinnerung: neue QML-Datei zuerst verlinken.

### Die Erkenntnisse des Tages

**Ein Text, der eine Faehigkeit beschreibt, faellt mit ihr nicht von selbst
weg.** Die Wallet war unter Android und Windows seit gestern entfernt; der
Hinweis bei der Dienstadresse versprach sie weiter "Tablet und Telefon".
Gefunden in der VM, eine halbe Stunde vor dem Signieren. Beim Entfernen
einer Faehigkeit ihre Namen in `strings.js` suchen.

**Ein stummer `catch` macht einen Fehler unerforschbar.** Die Widgets
scheiterten morgens, und niemand konnte sagen warum -- der Grund ging
verloren, den logcat hatte ich selbst geleert. Mit einer Zeile Protokoll und
`deviceidle force-idle` war die Ursache in zwei Minuten da: im Doze gibt es
fuer den Prozess kein Netz. Nachgestellt ist besser als abgewartet.

**Eine Grenze, die "ein Tag" annimmt, passt nur zu Kerzen bis zu einem
Tag.** Wortgleich in Dienst und App seit dem 13.09.; aufgefallen erst beim
Zeitraum, den am Telefon wirklich jemand eingestellt hatte.

**Vor "mehr Seiten" messen, wie weit die Quelle reicht.** OKX liefert 24
Stunden, nicht mehr. Die richtige Grenze ist die leere Seite, keine Zahl.

**Die laufende Shell ist ein Nutzer des Repos.** DMS laedt geaenderte
Dateien sofort; ein Import auf eine noch nicht verlinkte Datei legte die
Uhr-Ansicht elf Minuten lahm. Neue Datei: erst `install-links.sh`, dann
Imports.

**"Springt von selbst zurueck" war eine Einstellung.** Am Galaxy wechselte
die Ansicht alle 30 s -- der Reiterwechsel des Anwenders, dieselbe PID.
Zehn Bilder im Abstand von 10 s klaerten es.

Dazu, alle gemessen:

- **mempool.space sperrt die IPv4-Adresse wieder** (IPv4 `000`, IPv6 200).
  Der QEMU-Gast erreicht es ueber IPv6 (`wget -6`), die App darin nimmt
  IPv4; die Windows-VM hat nur IPv4.
- **Veroeffentlichen** (`gh release edit --draft=false`) lehnt die
  Rechtepruefung von Claude Code ab; Tag pushen und Entwurf anlegen gehen.
- **`od-start.cmd` und ein zweiter Start**: gleiche Logdatei, die exe
  startet nie, ohne Meldung. `OD_LOG` (in `build/`, nicht im Repo).
- **SetForegroundWindow stellt ein minimiertes Fenster nicht wieder her**;
  Alt+Tab schon.
- **Windows-VM**: `virsh send-key` mit deutscher Belegung, Klicks ueber
  `virsh qemu-monitor-command` mit `input-send-event`.
- **Galaxy**: zehn OrangeDeck-Widgets auf drei Startseiten; ohne Doze und
  am Strom kommen alle beim ersten Mal durch; `am broadcast` weiter
  verweigert, Anstossen per Neuinstallation.
- **Galaxy-Taps**: Koordinaten aus einem nebeneinandergelegten Bild erst
  zurueckrechnen -- ein Tipp landete im Suchfeld des Explorers.
- **Fedora-Live**: KRunner startete gar nicht ("startup job failed");
  Startmenue und bis zu einer Minute Geduld.

### Und was ich selbst falsch gemacht habe

- **Den logcat um 09:54 geleert**, bevor ich wusste, dass ich den Morgen
  noch brauche.
- **`roll.js` importiert, bevor sie verlinkt war** -- DMS elf Minuten mit
  kaputter Uhr-Ansicht.
- **Das Widget unter Windows fehlte, und ich habe erst in der App gesucht**
  statt im eigenen Testskript.
- **Q an ein minimiertes Fenster geschickt** und kurz fuer einen Befund
  gehalten.
- **Eine Befehlszeile in `$V` abgelegt**; die Shell teilt sie nicht,
  sechs Tasten gingen ins Leere.
- **In Fedora "konsole" getippt, ohne vorher ein Bild zu holen.**
- **Am Galaxy eine Koordinate falsch umgerechnet** (1756 statt 676) und das
  Suchfeld getroffen; nichts eingegeben, wieder geschlossen.
- **`--lang` fuer die Desktop-App geraten**; die Sprache kommt aus `LANG`.
- **"ok" als Freigabe genommen und veroeffentlichen wollen** -- die
  Rechtepruefung stoppte es; der Anwender hat es dann selbst getan.

### Was sonst noch offen ist

1. **Widgets ueber Nacht** und **0.2.11**: siehe oben.
2. **Leertext der Liquidationen** nirgends gesehen, nur im Paket
   nachgewiesen -- braucht ein Fenster ohne Marken.
3. **Windows mit Daten** (Feed, Uhr, Mining), sobald die IPv4-Sperre faellt.
4. **Rollen in den Einstellungen** nicht nachgewiesen (Seite passte ins
   Fenster); am Galaxy ist Rollen ohnehin Finger.
5. **Waehrung um 12:55** (15.09.) stiess die Widgets nicht an. Nicht
   geklaert.
6. **`tools/ansichten-android.py`** mit KEYCODE_COMMA am Galaxy.
7. **Windows ungeprueft:** 600 MB im Markt, README-Startzeile in Win+R,
   Skalierung ueber 100 %, SmartScreen. **macOS** ungeprueft.
8. **`bitfeed`** ansehen (kitty, Hintergrund, CPU), dann Stufe 3 und 4.
9. **Technische Fehlermeldungen** aus dem Datenweg; **DMS-Anteil** nur
   deutsch; **Android 11** im Emulator.
10. **Idee fuer spaeter**: Wallet direkt auf dem Telefon.

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
    Doze nachstellen:  adb shell dumpsys battery unplug; adb shell dumpsys deviceidle force-idle
      zurueck:         adb shell dumpsys deviceidle unforce; adb shell dumpsys battery reset
    Widget-Protokoll:  adb logcat -d -v time | grep -E ' (I|W)/OrangeDeck'
    adb logcat -d -v time | grep -E "AppWidgetManager\(|bg anr|freezing"
    Kommt von der App etwas an:  /health -> hits, zweimal im Abstand von 10 s
    Galaxy-Shell: nc und toybox, kein curl; Zeitstempel roh ausgeben
    python3 tools/bauplan-pruefen.py
    Windows-VM tippen:  virsh send-key win11 --holdtime 60 <KEY_...>   (deutsche Belegung)
    Windows-VM klicken: virsh qemu-monitor-command win11 '{"execute":"input-send-event",...}'  (0..32767)
    Fedora-Konsole: Startmenue vm.klick(35, 768), 'konsole', ret, bis zu 1 min warten
    gh run list --limit 5    (CI nur auf main, nicht auf Tags)
    gh run download <lauf> -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-<v>
    ZIP ohne zip:  python3 -m zipfile -c <ziel>.zip <ordner>
    tools/pruefvm.sh bauen | starten | anhalten | gast
      Fedora:  setsid env ORANGEDECK_VM_ISO=$HOME/VMs/fedora-kde-44.iso tools/pruefvm.sh starten
      KRunner mit alt-spc, vor langen Zeilen  echo FOKUS-OK  und ein Bild
      Klicks:  python3 -c 'import sys; sys.path.insert(0,"tools"); import vm; vm.klick(x, y)'
    gh release create v<v> --draft --verify-tag --title "OrangeDeck <v>" --notes-file <text> <dateien>
    gh release edit v<v> --draft=false --latest   (nur der Anwender: Rechtepruefung)
    virsh -c qemu:///system setmem win11 4G --config      (und setmaxmem; danach 10240000)
    im Windows-Gast nur Skripte starten, keine Schalter in Win+R (ClickFix)
    Pruefstand ohne Fenster:
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
          /usr/lib/qt6/bin/qml <datei>.qml      (grabToImage, 384 Punkte = Galaxy)
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    laeuft ein Prozess:  ps -C <name>   (nicht pgrep -f)
    tools/install-links.sh --check        (neue Datei unter ui/qml: ZUERST verlinken)
    Xvfb-Probe:  xvfb-run -a --server-args='-screen 0 1000x600x24' env -u WAYLAND_DISPLAY \
                 XDG_CONFIG_HOME=<kratz> LANG=en_US.UTF-8 QT_QPA_PLATFORM=xcb ./build/orangedeck-app
                 dazu tools/xtest.py: fenster_suchen, groesse, klick, taste("End")
    tools/install-links.sh && python3 -B daemon/orangedeck-dashtab && systemctl --user restart dms

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
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
