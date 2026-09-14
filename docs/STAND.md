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
## TAGESABSCHLUSS 14.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.9 ist veroeffentlicht**
(https://github.com/21Rebel/orangedeck/releases/tag/v0.2.9, "Latest"), mit
Windows-ZIP, signiertem APK und Flatpak, getestet auf Windows, Galaxy und
jetzt auch Linux in zwei VMs. Tag `v0.2.9` auf `1147e7a`. Die
DMS-Verknuepfungen fuer `DirectMarket.qml` sind verteilt, der Arbeitsbaum ist
sauber, alles gepusht.

### Was morgen als Erstes drankommt

Nichts Dringendes. Wenn das Galaxy steckt: **das Release-APK aufspielen.**
Auf dem Telefon liegt noch das Test-APK vom 13.09. (17:16, entspricht
`0017a80`); das Release-APK ist mit demselben Schluessel signiert und geht
darueber:

    adb install -r ~/.local/share/orangedeck/auslieferung/orangedeck-0.2.9-arm64-v8a.apk
    adb shell wm user-rotation free

Danach frei waehlbar aus der Liste unten. Kandidaten fuer 0.2.10 sind die
Feinheiten des Markts ohne Dienst (Punkt 3) und die Werkzeuge, die das
Zahnrad noch nicht kennen (Punkt 6).

### Was heute dazugekommen ist

7 Commits, dazu Tag und Release.

| Was | Commit | Anstoss |
|---|---|---|
| Metainfo: Datum auf den Tag der Auslieferung, Beschreibung auf den Markt ohne Dienst | `1147e7a` | Datum war vorlaeufig, Text vom 12.09. |
| Flatpak-Pin auf `1147e7a`, `bauplan-pruefen.py` wieder in Ordnung | `a5637b5` | Ablauf |
| Freigabevorlage: drei Pruefsummen, "Tested on" fuer Windows, Android, Linux | `c92ff4d` | Ablauf |
| Freigabetext ohne KI-typische Muster, saubere Interpunktion | `ba6d358` | Anwender |
| Pruef-VM: KRunner unter Fedora ueber alt-spc, Probezeile vor langen Zeilen | `95b4ad3` | Fedora-Lauf |
| Dashtab: Nachbearbeitungen aus `~/.config/orangedeck/dashtab-hooks.d` | `ff505c2` | andere Sitzung, auf Wunsch uebernommen |
| Tag `v0.2.9`, Release als Entwurf, nach OK veroeffentlicht | -- | Anwender |

**Die drei Dateien der Auslieferung** (SHA-256, auch im Release und in
`PRUEFSUMMEN.txt`):

    f4dc5d45e05bd51f71b839b11e26fcbc08ec86df4105541f22cb6f861b3e4f2d  orangedeck-0.2.9-windows-x86_64.zip
    bfd75987bf6be12465e75e5ee771eab4265f209842e11c0eed405fa180bd51ce  orangedeck-0.2.9-arm64-v8a.apk
    9e7a9fb7c3ad273790858b6b6cb515a335ab58a5d6af008ba0c43119569fde30  orangedeck-0.2.9.flatpak

**Gemessen heute:**

- **Linux, beide VMs, das Buendel aus dem Pin:** Ubuntu 24.04 GNOME und
  Fedora 44 KDE, jeweils frisch installiert: Feed, Uhr, Mining, Explorer und
  Markt mit Daten, keine Darstellungsfehler. **Nicht erreicht:** Zahnrad,
  Liquidationen, Heatmap -- dafuer gibt es keine Taste, und Klicks kommen in
  dieser VM nicht an.
- **APK:** Signatur v3, Zertifikat `B3:CC:83:79...92:E0` wie in der Vorlage,
  Fassung 0.2.9, TLS an Bord.
- **Windows-ZIP:** aus dem CI-Lauf `34852519395` auf `a5637b5`; 72 Dateien,
  90 949 044 Bytes, gleich dem Artefakt. Ein Ordner
  `orangedeck-0.2.9-windows-x86_64/` darin.
- **DMS nach dem Neubau:** `install-links.sh --check` "Alles verteilt.", DMS
  laeuft mit `dms-custom` (die Weiche ist nicht eingesprungen), Plugin und
  Daemon-Plugin geladen, im Journal keine Fehler. Die Oberflaeche selbst hat
  der Anwender noch nicht angesehen.

**Beim Anwender eingerichtet:** Auslieferungsordner aufgeraeumt -- die
Test-APKs vom 13.09. und die alte `PRUEFSUMMEN.txt` liegen in
`~/.local/share/orangedeck/auslieferung/geraetetest-0.2.9/`, verschoben,
nicht geloescht. Das Passwort des Signaturbehaelters hat der Anwender nach
dem Signieren geaendert; der Schluessel ist derselbe. Pruef-VM aus.

### Die Erkenntnis des Tages

**Die Pruefliste deckte nur ab, was am Vortag gemessen worden war.** Sie
nannte fuer 0.2.9 Windows und das Galaxy; Linux stand nirgends, weil es am
13.09. kein Thema war. Bei 0.2.8 liefen vor dem Tag zwei Linux-VMs. Der
Unterschied fiel erst beim Eintragen von "Tested on" auf, an einem leeren
Platzhalter -- vor dem Push des Tags, zum Glueck. Ein Tag ist seit 0.2.8 eine
Zusage; was vor ihm geprueft wird, gehoert in die Vorlage, nicht in die
Erinnerung an das letzte Mal.

Die zweite: **Texte veralten neben dem Code, und keiner merkt es.** Die
Metainfo beschrieb 0.2.9 noch mit "Markt ueber einen Dienst", einen Tag
nachdem der Markt ohne Dienst kam. Die Freigabevorlage war nachgezogen
worden, die Metainfo nicht -- sie waere so ins Flatpak gegangen.

Die dritte: **Der Freigabetext ist ein eigenes Stueck Arbeit.** Der Anwender
will ihn ohne KI-typische Muster: keine Gedankenstriche als Einschub, keine
Mittelpunkte und Pfeile, keine fett gesetzten Satzanfaenge, Umlaute im
deutschen Teil. Beim Umschreiben fiel dabei noch eine sachliche Ungenauigkeit
heraus (macOS beim Markt, ohne Download und ohne Test).

Dazu, alle gemessen:

- **Die CI laeuft nicht auf Tags**, nur auf `main`. Die Vorlage sprach vom
  "CI-Lauf des Tags" -- den gibt es nicht. Das Windows-ZIP kommt aus dem Lauf
  auf dem Pin-Commit, der sich vom Tag nur im Bauplan unterscheidet.
- **`zip` ist auf dieser Maschine nicht installiert.** Gepackt mit
  `python3 -m zipfile -c`; das legt Verzeichniseintraege mit an (89 Eintraege
  fuer 72 Dateien), deshalb Dateien und Bytes getrennt zaehlen.
- **flathub meldete im Ubuntu-Gast einmal "SSL connect error"**, eine Minute
  spaeter ging es. Die Installation ist seitdem in eine Schleife mit drei
  Versuchen gefasst.
- **KRunner unter Fedora 44 Live: alt-f2 oeffnet nichts, alt-spc sofort.** Die
  lange Befehlszeile ging deshalb als Suche an DuckDuckGo; im Gast ist nichts
  ausgefuehrt worden. Steht jetzt in `tools/pruefvm.sh gast`.
- **Im Explorer nimmt das Suchfeld die Ziffern** -- gewollt
  (`ExplorerView.qml`, `focusSearch`). Esc gibt den Fokus zurueck, danach
  wechseln die Ziffern wieder den Reiter.
- **`gh release create --draft`** zeigt eine URL mit `untagged-...`; das ist
  bei Entwuerfen so und wird beim Veroeffentlichen zur Tag-URL.
- **mempool.space** antwortet dieser Maschine wieder ueber IPv4.

### Und was ich selbst falsch gemacht habe

- **Wieder `ls` fuer einen Pfad in einer Variablen** -- bei diesem Anwender
  mit Symbolen davor. `apksigner` war damit "nicht gefunden", und weil die
  Ausgabe durch `grep` lief, stand zuerst gar nichts da. Am 13.09. schon
  notiert; `command ls`.
- **Die lange Zeile in den Fedora-Gast ohne Probe geschickt.** Gut zwei
  Minuten Tippen ins falsche Fenster, danach ein zweiter Anlauf, bei dem
  Alt+F2 ebenfalls nicht wirkte. Die Probezeile kam erst beim dritten Mal.
- **Die Linux-Laeufe standen nicht in meinem Plan vom Morgen.** Gefunden am
  leeren Platzhalter, nicht beim Planen.
- **Den ersten Release-Entwurf mit dem Text der Vorlage angelegt**, ohne ihn
  auf Stil zu lesen; der Anwender musste danach fragen.
- **Den veroeffentlichten Text mit `cmp` gegengeprueft**, das an dem
  Zeilenumbruch scheiterte, den `jq` anhaengt -- ein Befund, der keiner war.

### Was sonst noch offen ist

1. **Galaxy: Release-APK aufspielen** (siehe oben).
2. **Warum die App den Dienst im WLAN nicht erreicht.** Galaxy A55, Android 16,
   NordVPN aktiv (nimmt 192.168.0.0/16 aber aus). Betrifft nur die Wallet auf
   Telefon und Tablet; im Release als ungeprueft genannt.
3. **Markt ohne Dienst, Feinheiten:** `liqSince` ist fuer Bybit zu
   grosszuegig (Beginn des OKX-Rueckgriffs); die erste Antwort kommt ohne
   Long/Short; die Heatmap kommt gelegentlich mit `kein_oi`, wenn Binance
   Futures nicht rechtzeitig antwortet; Zoom mit zwei Fingern haelt den
   rechten Rand fest, nicht die Mitte zwischen den Fingern.
4. **Der Dienst koennte den OKX-Rueckgriff auch nutzen**, und
   `Market.kerzen()` darin wird nirgends aufgerufen.
5. **Unter Windows rund 600 MB Arbeitsspeicher im Markt** -- notiert, nicht
   mit dem Feed verglichen.
6. **Veraltet durch das Zahnrad:** `tools/ansichten.py` (Einstellungen ueber
   Ziffer 6) und `tools/ansichten-android.py` (sucht "Settings" in der
   Reiterzeile); in `docs/DOKUMENTATION.md` die Tabelle der Ansichten mit
   "5 | tab.settings" als Reiter. Heute dazu: **das Zahnrad ist ohne Maus
   nicht erreichbar**, in der Pruef-VM also gar nicht.
7. **Klicks in der Pruef-VM.** `mouse_move` bewegt dort nichts (sieben
   Versuche, siehe `tools/pruefvm.sh`); ungeprueft ist allein QMP
   `input-send-event`. In der Windows-VM gehen Klicks genau darueber (USB-Tablet,
   absolute Achsen). Mit `-qmp` in `pruefvm.sh starten` waeren Zahnrad,
   Liquidationen und Heatmap auch unter Linux pruefbar.
8. **qmllint in `MarketView.qml`: 55 Warnungen**, alle "Unqualified access".
   `pragma ComponentBehavior: Bound` wuerde sie loesen.
9. **Freigabevorlage fuer die naechste Nummer:** die Pruefliste um die
   Linux-VMs und die Metainfo ergaenzen, "CI-Lauf des Tags" durch "Lauf auf
   dem Pin-Commit" ersetzen, den Stil des Freigabetexts als Punkt aufnehmen.
10. **Idee, nur wenn es stoert:** in der Tastenhilfe "Esc verlaesst die Suche"
    fuer den Explorer. Waere eine Aenderung an `ui/`, also eine neue Nummer.
11. **Windows, ungeprueft:** ob die README-Startzeile in Win+R eingefuegt
    ebenfalls als ClickFix gilt; Skalierung ueber 100 %; SmartScreen beim
    Entpacken aus dem Netz. **macOS** ungeprueft, kein Geraet.
12. Vom 12.09. unveraendert: `bitfeed` ansehen (kitty, Hintergrund, CPU), dann
    Stufe 3 und 4; die Ansichten rollen nicht mit der Tastatur; technische
    Fehlermeldungen aus dem Datenweg; der DMS-Anteil ist deutsch; Android 11 im
    Emulator; Aufraeumen von `~/.cache/orangedeck-fp` (rund 2 GB), alten
    Fassungen im Auslieferungsordner und jetzt auch `geraetetest-0.2.9/`.

### Fuer den naechsten Lauf

    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    tools/apk.sh [<tag|commit>]  ->  bash ~/Schreibtisch/orangedeck/tools/apk-signieren.sh <v>  (Anwender)
    SIGNER=$(command ls -d ~/Android/sdk/build-tools/*/apksigner | sort -V | tail -1)
    python3 tools/bauplan-pruefen.py
    gh run list --limit 5    (CI nur auf main, nicht auf Tags)
    gh run download <lauf> -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-<v>
    ZIP ohne zip:  python3 -m zipfile -c <ziel>.zip <ordner>
    tools/pruefvm.sh bauen | starten | anhalten | gast
      Fedora:  setsid env ORANGEDECK_VM_ISO=$HOME/VMs/fedora-kde-44.iso tools/pruefvm.sh starten
      KRunner mit alt-spc, vor langen Zeilen  echo FOKUS-OK  und ein Bild
    gh release create v<v> --draft --verify-tag --title "OrangeDeck <v>" --notes-file <text> <dateien>
    gh release edit v<v> --notes-file <text> --draft=false --latest
    virsh -c qemu:///system setmem win11 4G --config      (und setmaxmem; danach 10240000)
    im Windows-Gast nur Skripte starten, keine Schalter in Win+R (ClickFix)
    Pruefstand ohne Fenster:
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
          /usr/lib/qt6/bin/qml <datei>.qml      (grabToImage, 384 Punkte = Galaxy)
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    tools/install-links.sh --check
    tools/install-links.sh && python3 -B daemon/orangedeck-dashtab && systemctl --user restart dms

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
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
