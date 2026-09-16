<!-- Der Text unten ist der Entwurf fuer 0.2.10 (16.09.2026). "Tested on" und
     die Pruefsummen sind Platzhalter, bis Punkt 2 bis 8 erledigt sind. Die
     Texte von 0.2.8 und 0.2.9 stehen in der Geschichte dieser Datei.

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

This release removes the wallet from phones, tablets and Windows and fixes Android widgets that stayed empty.

## Removed since 0.2.9

- The watch-only wallet and the setting Data source > Service on another device are gone on phones, tablets and Windows. 0.2.9 announced both as new, but they never worked there: the app discarded the address you entered and kept asking itself. The wallet addresses would also have crossed your network unencrypted. On Linux both remain, and the address you enter is now actually used.
- A service address saved with 0.2.9 is ignored on these systems. There is nothing to clean up.

## What's new since 0.2.9

- Android widgets draw their last known values immediately and share one time budget for all requests. Several widgets updating at once no longer stay empty, and a request that gets no answer shows "offline" instead of "...".
- The market without a service shows long/short as soon as the first exchange answers instead of waiting for the slowest one. Bybit gets its own "listening since" time when it joined later, the heatmap keeps its last picture when Binance does not answer, and two-finger zoom centers on the point between your fingers.
- The comma key opens the settings. Pressing it again or Esc goes back.
- On Linux, the service fetches missed OKX liquidations when it reconnects, up to 3,000 entries back. On a quiet night that covers the hours nobody had the market open.

## Windows: `orangedeck-0.2.10-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.10-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.9.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.10-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux: `orangedeck-0.2.10.flatpak`

    flatpak install --user orangedeck-0.2.10.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other Linux computers on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- Windows 11 25H2 in a VM, with settings left over from 0.2.9 (a service address and the wallet switched on): no wallet tab and no service settings, the market loads directly from the exchanges, the comma key and Esc, a widget that stays on the desktop with Win+D, closing window and widget with Q. mempool.space did not answer this test network over IPv4 that day, so feed, clock and mining were not seen with data.
- Samsung Galaxy A55 with Android 16, this signed APK installed over 0.2.9: no wallet tab and no service settings, the back button closes the settings, feed and market with live data, long/short from all three exchanges, and the widgets refreshed with data after the update. Two-finger zoom was not checked with this build.
- This Flatpak bundle, freshly installed in live sessions of Ubuntu 24.04 with GNOME and Fedora 44 with KDE: all tabs, the settings with the comma key, and the market with live data through the service. Feed, clock, mining and explorer stayed empty there for the same reason.
- Not tested yet: macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    9c446d2b396cea1730b89f1dc4195c2a577c85609b4033a24edf5eeb0eafb04f  orangedeck-0.2.10-windows-x86_64.zip
    14e7b7014c84a3138102486781a87eac995d7a9574b5611ad862de676428d25c  orangedeck-0.2.10-arm64-v8a.apk
    50d0ab4b459459951b9c1178cc9a3a27b3b712d915250d9bbb4e58c2bcea2737  orangedeck-0.2.10.flatpak

---

## Deutsch

0.2.10 nimmt die Wallet auf Telefon, Tablet und Windows wieder heraus. 0.2.9 hatte sie dort über einen Dienst auf einem anderen Gerät angekündigt, angekommen ist sie nie, weil die App die eingetragene Adresse verwarf. Die Wallet-Adressen wären außerdem unverschlüsselt durchs Netz gegangen. Unter Linux bleiben Wallet und Dienst-Weg, und die eingetragene Adresse wird jetzt übernommen.

Android-Widgets zeigen sofort den letzten Stand und bleiben nicht mehr leer, wenn mehrere zugleich laden oder das Netz nicht antwortet. Der Markt ohne Dienst zeigt Long/Short, sobald die erste Börse antwortet, und zoomt um die Stelle zwischen zwei Fingern. Die Komma-Taste öffnet die Einstellungen.

Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
