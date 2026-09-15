<!-- Der Text unten ist der von 0.2.9, veroeffentlicht am 14.09.2026
     (https://github.com/21Rebel/orangedeck/releases/tag/v0.2.9). Fuer die
     naechste Nummer wird er umgeschrieben; 0.2.8 und die abgehakte Liste von
     0.2.9 stehen in der Geschichte dieser Datei.

     **Die Pruefliste gilt fuer jede Nummer, nicht nur fuer die, bei der sie
     entstand.** Am 14.09.2026 nannte sie fuer 0.2.9 nur Windows und das
     Galaxy, weil am Vortag nur dort gemessen worden war; Linux fiel erst an
     einem leeren Platzhalter auf. Deshalb steht hier alles, jedes Mal, und
     was nicht gemessen ist, wird nicht als getestet genannt.

     **Vor dem Tag:**

     1. Metainfo (`packaging/flatpak/*.metainfo.xml`): Fassung, Datum, und die
        Beschreibung gegen das, was die Nummer wirklich bringt. Am 14.09.2026
        beschrieb sie noch den Markt ueber einen Dienst, einen Tag nachdem er
        ohne Dienst kam.
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

This release brings a first Windows build and the market on every device.

## What's new since 0.2.8

- A first Windows build, as a ZIP that runs without installation. Feed, clock, mining, explorer, market and settings work on their own. The wallet comes from an OrangeDeck service on another computer (see below).
- Desktop widgets on Windows. The same command line as on Linux turns any view into a frameless widget without a taskbar entry, above or below all other windows. Widgets stay on the desktop when you press Win+D.
- The market no longer needs a service. Phones, tablets and Windows fetch candles, the trade tape, long/short account ratios and the liquidation heatmap directly from the public APIs of Binance, Bybit and OKX. Liquidations arrive live while the view is open, and the last day is loaded from OKX. On Linux the service keeps listening around the clock and holds two days.
- Watch-only wallet on phones, tablets and Windows. Under Data source > Service on another device, enter the address of the Linux computer running the OrangeDeck service, and the wallet appears. The service then answers anyone on your network, including requests for the wallet addresses. The settings page points this out, and the service stays local until you open it yourself.
- On narrow screens, the market header and the legends of liquidations and heatmap wrap instead of being cut off. Candles/line and volume/CVD have compact buttons, and the chart zooms with two fingers.
- Settings open from a gear button next to the fullscreen button instead of a tab. On a phone, the last tab used to sit under that button. The Android back gesture closes the settings.
- Widgets started with `--bare` now hide the header and footer, as documented.

## Windows: `orangedeck-0.2.9-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.9-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Includes everything from 0.2.8, plus the market without a service and the wallet through a service on your network.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.9-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux: `orangedeck-0.2.9.flatpak`

    flatpak install --user orangedeck-0.2.9.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other devices on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- Windows 11 25H2 in a VM: feed and mining directly from mempool.space, the market without a service (price, liquidations, heatmap), feed and market through a service, widgets including Win+D, closing window and widget with Q.
- Samsung Galaxy A55 with Android 16: the market without a service (candles, liquidations, heatmap), compact buttons, two-finger zoom, the gear button and the narrow layouts. The wallet through a service on another device did not connect on this phone and remains untested.
- This Flatpak bundle, freshly installed in live sessions of Ubuntu 24.04 with GNOME and Fedora 44 with KDE: feed, clock, mining, explorer and the market with live data.
- Not tested yet: macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    f4dc5d45e05bd51f71b839b11e26fcbc08ec86df4105541f22cb6f861b3e4f2d  orangedeck-0.2.9-windows-x86_64.zip
    bfd75987bf6be12465e75e5ee771eab4265f209842e11c0eed405fa180bd51ce  orangedeck-0.2.9-arm64-v8a.apk
    9e7a9fb7c3ad273790858b6b6cb515a335ab58a5d6af008ba0c43119569fde30  orangedeck-0.2.9.flatpak

---

## Deutsch

0.2.9 bringt die erste Windows-Fassung. Sie kommt als ZIP ohne Installation und ist nicht signiert, daher warnt SmartScreen beim ersten Start. Die Desktop-Widgets bleiben auch bei „Desktop anzeigen“ stehen.

Der Markt braucht keinen Dienst mehr. Telefon, Tablet und Windows holen Kerzen, Handelsband, Long/Short-Verhältnis und Heatmap selbst von Binance, Bybit und OKX. Liquidationen kommen live, dazu der letzte Tag von OKX.

Unter Datenquelle > Dienst auf einem anderen Gerät holen Telefon, Tablet und Windows die Watch-only-Wallet vom Linux-Rechner im eigenen Netz. Der Dienst antwortet dann jedem im Netz, auch mit den Wallet-Adressen. Er bleibt lokal, bis man ihn selbst freigibt.

Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
