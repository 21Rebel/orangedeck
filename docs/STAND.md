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
## TAGESABSCHLUSS 16.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.10 ist veroeffentlicht**
(https://github.com/21Rebel/orangedeck/releases/tag/v0.2.10, "Latest"), Tag
`v0.2.10` auf `e4e74ef`, drei Dateien gegen die Pruefsummen gehalten, "Tested
on" mit Windows, Galaxy und beiden Linux-VMs. Das Veroeffentlichen hat die
Rechtepruefung von Claude Code abgelehnt ("Create Public Surface"); der
Anwender hat es selbst getan. Danach drei Berichtigungen fuer 0.2.11 auf
`main`. Alles gepusht, Arbeitsbaum sauber.

### Was morgen als Erstes drankommt

Nichts Dringendes. Wenn das Galaxy steckt:

1. **Leertext der Liquidationen am Geraet**: nur im APK nachgewiesen (Text
   im Paket), nicht gesehen -- dafuer braucht es ein Fenster ohne Marken.

### Was heute dazugekommen ist

10 Commits, dazu Tag und Release-Entwurf.

| Was | Commit | Anstoss |
|---|---|---|
| Nummer 0.2.10, Metainfo und Freigabetext nennen den Wegfall der Wallet | `7d30b40` | Tagesabschluss 15.09. |
| Bauplan auf 0.2.10 | `65f858e` | Ablauf |
| Hinweis zur Dienstadresse: nicht mehr "Tablet und Telefon", 13 Sprachen | `e4e74ef` | Ubuntu-VM, vor dem Signieren |
| Bauplan auf `e4e74ef` | `ab7c079` | Ablauf |
| Freigabetext: Pruefsummen, Windows, Linux, Galaxy | `47e47b0`, `41711f0` | Ablauf |
| Liquidationen bei "all": die laufende Woche fehlte (Dienst und App) | `116b2ce` | Galaxy, 13y leer |
| Leere Liquidationsansicht: OKX liefert einen Tag rueckwirkend | `3f4035e` | Galaxy |
| Explorer, RBF: "vorher"/"neu" in jeder Sprache | `83171b1` | beide Linux-VMs |
| Pruef-VM: KRunner unter Fedora ging nicht, Startmenue | `c8771d4` | Fedora-Lauf |
| Tag `v0.2.10`, Release als Entwurf, vom Anwender veroeffentlicht | -- | Anwender |

**Die drei Dateien der Auslieferung** (SHA-256, auch im Release, von GitHub
nach dem Hochladen bestaetigt, und in `PRUEFSUMMEN.txt`):

    9c446d2b396cea1730b89f1dc4195c2a577c85609b4033a24edf5eeb0eafb04f  orangedeck-0.2.10-windows-x86_64.zip
    14e7b7014c84a3138102486781a87eac995d7a9574b5611ad862de676428d25c  orangedeck-0.2.10-arm64-v8a.apk
    50d0ab4b459459951b9c1178cc9a3a27b3b712d915250d9bbb4e58c2bcea2737  orangedeck-0.2.10.flatpak

**Gemessen heute:**

- **Windows 11, VM, ZIP aus `65f858e`** (Stand `7d30b40`; `e4e74ef` aendert
  nur einen Text, den Windows ausblendet): Registry wie nach 0.2.9
  (`dataSource=daemon`, `daemonHost`, `walletEnabled=true`) -- kein
  Wallet-Reiter, keine Datenquelle, Markt direkt mit Daten; `,` und Esc;
  Widget bleibt bei Win+D; Q schliesst Widget und Fenster; keine neue
  Defender-Erkennung, kein Absturz im Protokoll.
- **Ubuntu 24.04 und Fedora 44, Buendel aus `e4e74ef`**: Pruefsummen,
  Installation, alle Reiter, `,`, der berichtigte Hinweistext, Markt ueber
  den Dienst mit Daten. Unter Linux Datenquelle und Wallet-Reiter vorhanden.
- **Galaxy, Release-APK ueber adb**: keine Wallet, keine
  Dienst-Einstellungen, Zurueck schliesst sie, Feed und Markt mit Daten,
  Long/Short von allen drei Boersen, Bybit mit eigenem "seit". Widgets nach
  der Installation bei gesperrtem Telefon "gerade nicht erreichbar", nach
  dem Anstossen alle mit Daten, kein ANR -- damit ist "offline statt ..."
  gesehen. Zwei Finger nicht geprueft (adb kann das nicht).
- **Dienst, `/market?range=all`**: vorher Marken bis 15.09., nachher bis
  16.09. 09:04.

**Beim Anwender eingerichtet und zurueckgenommen:** `win11` auf 4 GB und
wieder auf 10240000 KiB, aus. Pruef-VM aus. Drehung am Galaxy freigegeben.
In der Windows-VM steht noch die Registry wie nach 0.2.9 (`daemon`,
`192.168.100.7`, Wallet an) -- absichtlich, schadet unter 0.2.10 nicht.
`PRUEFSUMMEN.txt`: die Zeile des verworfenen ersten 0.2.10-Baus entfernt,
ZIP und Flatpak ergaenzt.

### Die Erkenntnis des Tages

**Ein Text, der eine Faehigkeit beschreibt, faellt mit ihr nicht von selbst
weg.** Die Wallet unter Android und Windows war seit gestern entfernt, der
Hinweis bei der Dienstadresse versprach sie unter Linux weiter "Tablet und
Telefon". Gefunden in der VM, als niemand danach suchte, eine halbe Stunde
bevor das APK signiert wurde. Beim Entfernen einer Faehigkeit gehoert eine
Suche nach ihren Namen in `strings.js` dazu.

Die zweite: **"Springt von selbst zurueck" war eine Einstellung.** Am Galaxy
wechselte die Ansicht alle 30 s -- der Reiterwechsel des Anwenders, kein
Absturz (dieselbe PID). Zehn Bilder im Abstand von 10 s haben das in 90 s
geklaert.

Die dritte: **Eine Grenze, die "ein Tag" annimmt, passt nur zu Kerzen bis
zu einem Tag.** Der Fehler stand wortgleich in Dienst und App, seit dem
13.09., und fiel erst beim Zeitraum auf, den am Telefon jemand wirklich
eingestellt hatte.

Dazu, alle gemessen:

- **mempool.space sperrt die IPv4-Adresse wieder** (IPv4 `000`, IPv6 200).
  Der QEMU-Gast erreicht mempool.space ueber IPv6 (`wget -6` 200), die App
  darin nimmt aber IPv4; die Windows-VM hat nur IPv4.
- **`od-start.cmd` und ein zweiter Start**: die Umleitung in dieselbe
  Logdatei scheitert, solange das Fenster sie offen haelt, und die exe
  startet nie, ohne Meldung. `OD_LOG` waehlt jetzt die Datei (in `build/`,
  nicht im Repo).
- **SetForegroundWindow holt ein minimiertes Fenster nicht zurueck**; Q ging
  ins Leere. Alt+Tab stellt es wieder her.
- **Die libvirt-VM tippt ueber `virsh send-key` mit deutscher Belegung**
  (z/y getauscht, `:` = Shift+Punkt, `\` = AltGr+sz); Helfer im Kratzbereich,
  nicht im Repo. Klicks ueber `virsh qemu-monitor-command` mit
  `input-send-event`.
- **Der Galaxy-Startbildschirm** hat zehn OrangeDeck-Widgets auf drei Seiten.

### Und was ich selbst falsch gemacht habe

- **Das Widget unter Windows fehlte, und ich habe erst nach der App
  gesucht**, bevor ich das eigene Testskript verdaechtigt habe.
- **Q an ein minimiertes Fenster geschickt** und kurz fuer einen Befund
  gehalten.
- **Einen Befehl mit `$V` als Variable** an die zsh-artige Shell gegeben;
  sie teilt nicht in Woerter, sechs Tasten gingen ins Leere.
- **In Fedora "konsole" getippt, ohne vorher ein Bild zu holen**; es landete
  im Willkommensfenster.
- **"ok" des Anwenders als Freigabe genommen und veroeffentlichen wollen** --
  die Rechtepruefung hat es gestoppt. Die Frage war gestellt, die Antwort
  kam; der Weg ueber den Anwender ist trotzdem der richtige.

### Was sonst noch offen ist

1. ~~0.2.10 veroeffentlichen~~: am 16.09. um 10:55 vom Anwender.
2. ~~Test-APKs~~: `geraetetest-0.2.9/` (542 MB) und `geraetetest-0.2.10/`
   (327 MB) am 16.09. auf Wort des Anwenders geloescht. Im
   Auslieferungsordner liegen nur noch 0.2.9 und 0.2.10.
3. **Windows mit Daten** (Feed, Uhr, Mining), sobald die IPv4-Sperre faellt.
4. ~~Widgets blieben "gerade nicht erreichbar"~~: **Ursache gemessen, am
   Nachmittag behoben** (`fe60fd0`). Im Doze sperrt Android dem Prozess das
   Netz (`UnknownHostException` fuer mempool.space, beim Miner eine
   Zeitueberschreitung), und nach einem Fehlschlag gab es keinen Versuch bis
   zum naechsten Takt. Jetzt je Widget-Art ein Job mit Netz-Bedingung.
   Nachgestellt am Galaxy mit `force-idle`: zehn Fehlschlaege, zehn Jobs;
   nach `unforce` liefen alle zehn sofort, 20 Zeichnungen, keine Warnung,
   kein Job mehr wartend. Ohne Doze (nur Bildschirm aus, am Strom) kam alles
   beim ersten Mal durch. Um 12:56 alle zehn Widgets auf drei Seiten mit
   Daten gesehen (Blockhoehe 967.305). Offen nur der Fall ueber Nacht ohne
   Zwang: morgen frueh ansehen, bevor 0.2.11 eine Nummer bekommt.
5. **Waehrung um 12:55** (15.09.) stiess die Widgets nicht an. Nicht
   geklaert.
6. **OKX-Nachholen**: 30 Seiten reichen an unruhigen Tagen nicht.
7. **Am Galaxy gesehen (16.09., 11:30, Test-APK aus `d362ada`,
   `geraetetest-0.2.11/...-geraetetest-liq.apk`)**: Liquidationen bei 13y
   mit Summen (Longs 24,9 M $, Shorts 7,3 M $) und Balken statt leer; RBF-
   Tafel mit "vorher"/"neu" aus dem neuen Schluessel. Englisch nicht
   gesehen, Leertext nicht gesehen.
8. **`tools/ansichten-android.py`** mit KEYCODE_COMMA am Galaxy.
9. **Windows ungeprueft:** 600 MB im Markt, README-Startzeile in Win+R,
   Skalierung ueber 100 %, SmartScreen. **macOS** ungeprueft.
10. **Idee:** in der Tastenhilfe "Esc verlaesst die Suche" (13 Sprachen).
11. Vom 12.09. unveraendert: `bitfeed` ansehen, dann Stufe 3 und 4; Ansichten
    rollen nicht mit der Tastatur; technische Fehlermeldungen aus dem
    Datenweg; DMS-Anteil deutsch; Android 11 im Emulator.
12. **Idee fuer spaeter**: Wallet direkt auf dem Telefon.

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
