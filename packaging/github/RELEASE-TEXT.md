<!-- Der Text unten ist der Entwurf fuer 0.2.11 (17.09.2026). "Tested on" und
     die Pruefsummen sind Platzhalter, bis Punkt 2 bis 8 erledigt sind. Die
     Texte von 0.2.8 bis 0.2.10 stehen in der Geschichte dieser Datei.

     **Die Pruefliste gilt fuer jede Nummer, nicht nur fuer die, bei der sie
     entstand.** Am 14.09.2026 nannte sie fuer 0.2.9 nur Windows und das
     Galaxy, weil am Vortag nur dort gemessen worden war; Linux fiel erst an
     einem leeren Platzhalter auf. Deshalb steht hier alles, jedes Mal, und
     was nicht gemessen ist, wird nicht als getestet genannt.

     **Vor dem Tag:**

     1. Metainfo (`packaging/flatpak/*.metainfo.xml`): Fassung, Datum, und die
        Beschreibung gegen das, was die Nummer wirklich bringt. Am 14.09.2026
        beschrieb sie noch den Markt ueber einen Dienst, einen Tag nachdem er
        ohne Dienst kam. **Auch was wegfaellt**, gegen den Text der letzten
        Nummer gehalten: 0.2.9 kuendigte die Wallet unter Android und Windows
        an, 0.2.10 nimmt sie dort heraus.
     2. Geraetelauf am Galaxy mit dem gebauten APK, vom Anwender selbst
        durchgegangen. Danach `adb shell wm user-rotation free`.
     3. Windows-VM: Feed, Mining und Markt mit Daten, Zahnrad (auch `,`),
        Widgets mit Win+D, Q schliesst Fenster und Widget, keine neue
        Defender-Erkennung.
     4. Linux in **beiden** Pruef-VMs (Ubuntu GNOME, Fedora KDE), das Buendel
        aus dem Pin frisch installiert: alle Reiter, Einstellungen ueber `,`.
     5. `python3 tools/bauplan-pruefen.py`, Pin im Flatpak-Bauplan auf dem
        Commit, der getaggt wird.

     **Vor dem Veroeffentlichen:**

     6. Windows-ZIP aus dem **Lauf auf dem Pin-Commit** (die CI laeuft nur
        auf main, nicht auf Tags; der Pin-Commit unterscheidet sich vom Tag
        nur im Bauplan). Dateien und Bytes gegen das Artefakt halten.
     7. APK signiert der Anwender; Zertifikat gegen den Fingerabdruck unten.
        Test-APKs und ihre Zeilen in `PRUEFSUMMEN.txt` vorher wegraeumen.
     8. Drei Pruefsummen eintragen, "Tested on" nur mit dem, was in Punkt 2
        bis 4 wirklich gesehen wurde.
     9. **Stil des Textes**, maschinell pruefen: keine Gedankenstriche als
        Einschub, keine Mittelpunkte oder Pfeile, keine fett gesetzten
        Satzanfaenge, saubere Interpunktion, Umlaute im deutschen Teil.
     10. Release als Entwurf; veroeffentlicht wird nur mit ausdruecklichem OK
         des Anwenders. -->


A Bitcoin dashboard with the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, a block explorer and the BTC market. MIT licensed, no account needed.

This release fixes what the last one left behind. Widgets that came back empty after a night in standby, a liquidation view that stayed blank, and tables you could not scroll with the keyboard.

## What's new since 0.2.10

- Android widgets fetch what they missed as soon as the network is back. While a phone is dozing it has no connection, so the update failed and the widget waited for the next hour. Now the attempt is repeated the moment there is a network again, and the reason for a failure is written to the log.
- The liquidation view no longer stays blank. Over a long range it now includes the running week, and when the last hours are empty it says so instead of showing nothing. The service fills the view from the last 24 hours that OKX still serves, which is as far back as that exchange goes.
- The time in "listening since" now moves along when older entries drop out of the stored window, instead of claiming a longer history than the numbers cover.
- In the explorer, the two columns of a replaced transaction are translated in every language. They read "old" and "new" in English and the same in the other twelve.
- Tables can be read with the keyboard: page up and down, home and end. The key help says how to leave the search with Esc.
- The tooltip over the mempool mosaic sits on the same dark, blurred backing as the other readings, so it stays legible above bright tiles.

## Windows: `orangedeck-0.2.11-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.11-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.10.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.11-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux: `orangedeck-0.2.11.flatpak`

    flatpak install --user orangedeck-0.2.11.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other Linux computers on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- PLATZHALTER Galaxy (Punkt 2 der Pruefliste)
- PLATZHALTER Windows-VM (Punkt 3)
- PLATZHALTER Ubuntu und Fedora (Punkt 4)
- Not tested yet: macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    PLATZHALTER  orangedeck-0.2.11-windows-x86_64.zip
    PLATZHALTER  orangedeck-0.2.11-arm64-v8a.apk
    PLATZHALTER  orangedeck-0.2.11.flatpak

---

## Deutsch

0.2.11 bessert nach, was die letzte Nummer offen gelassen hat: Widgets, die nach einer Nacht im Standby leer zurückkamen, eine Liquidationsansicht, die nichts zeigte, und Tabellen, die sich mit der Tastatur nicht bewegen ließen.

Android-Widgets holen nach, sobald das Netz wieder da ist. Im Doze hat das Telefon keine Verbindung, der Versuch scheiterte, und das Widget wartete auf die nächste Stunde. Jetzt wird er wiederholt, sobald wieder ein Netz da ist.

Die Liquidationsansicht bleibt nicht mehr leer. Über einen langen Zeitraum zählt sie auch die laufende Woche mit, und sind die letzten Stunden leer, sagt sie das, statt nichts zu zeigen. Sie füllt sich aus den letzten 24 Stunden, weiter zurück gibt OKX nichts heraus. Die Angabe "zugehört seit" rückt mit, wenn ältere Einträge herausfallen.

Im Explorer sind die Spalten einer ersetzten Transaktion in jeder Sprache übersetzt. Tabellen lassen sich mit Bild auf und ab, Pos1 und Ende lesen, und die Tastenhilfe sagt, wie man die Suche mit Esc verlässt. Der Tooltip über dem Kachelfeld liegt auf demselben dunklen Untergrund wie die übrigen Angaben und bleibt damit auch über hellen Kacheln lesbar.

Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
