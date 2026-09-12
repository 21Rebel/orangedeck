<!-- Text fuer das GitHub-Release von 0.2.9. Die Vorlage fuer 0.2.8 ist am
     12.09.2026 veroeffentlicht worden (https://github.com/21Rebel/orangedeck/releases/tag/v0.2.8)
     und steht in der Geschichte dieser Datei.

     **Vor dem Veroeffentlichen, und erst dann:**

     1. Die IPv4-Sperre von mempool.space muss weg sein
        (`curl -4 https://mempool.space/api/blocks/tip/height`). Dann in der
        Windows-VM den Direktbezug **mit Daten** sehen -- bisher lief Windows
        nur ueber den Dienst. Im selben Lauf: ein Widget mit Q schliessen.
     2. Geraetelauf auf dem Galaxy: das neue Feld "Dienst auf einem anderen
        Geraet" mit dem Rechner im WLAN -- Markt und Wallet muessen dort
        erscheinen. Gesehen ist das bisher nur unter Linux und Windows.
     3. Das Windows-ZIP aus dem getaggten Stand bauen lassen, als
        `orangedeck-0.2.9-windows-x86_64.zip` packen, Pruefsumme anhaengen.
     4. Die drei Pruefsummen unten eintragen, "Tested on" gegen das Gemessene
        halten, jede Aussage fuer den getaggten Stand nachsehen.

     Veroeffentlicht wird nur mit ausdruecklichem OK des Anwenders. -->

**Windows, and market and wallet on every device.** · *Windows, und Markt und Wallet auf jedem Geraet.*

A Bitcoin dashboard: the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, a block explorer and the BTC market. MIT, no account.

## What's new since 0.2.8

- **Windows.** A first Windows build, as a ZIP that runs without installation. Feed, clock, mining, explorer and settings work on their own; market and wallet come from an OrangeDeck service on another computer (see below).
- **Desktop widgets on Windows.** The same command line as on Linux turns any view into a frameless widget without a taskbar entry, above or below all other windows — and it stays on the desktop when you press Win+D.
- **Market and watch-only wallet on phones, tablets and Windows.** New setting *Data source → Service on another device*: enter the address of the Linux computer running the OrangeDeck service, and both views appear. **The service then answers anyone on your network**, including with the wallet addresses; the settings page says so, and the service stays local until you open it yourself.
- `--bare` widgets now really hide the header and footer, as documented.

## Windows — `orangedeck-0.2.9-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Windows 10/11, 64-bit.

**Not signed.** A certificate costs money every year and this project is meant to cost nothing. SmartScreen will warn when you start it for the first time (*More info → Run anyway*). Compare the checksum below before you do.

Widgets, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press **Q** to close it. Details in `packaging/widgets/README.md`.

## Android — `orangedeck-0.2.9-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a), Android 9 or newer. Everything from 0.2.8, plus market and wallet through a service on your network.

**Check the signature before installing:**

    apksigner verify --print-certs orangedeck-0.2.9-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux — `orangedeck-0.2.9.flatpak`

    flatpak install --user orangedeck-0.2.9.flatpak

It pulls the KDE runtime 6.9 from Flathub. On Linux all six views are included. To serve market and wallet to other devices on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- **Windows:** <GEMESSEN-WINDOWS> — bisher: Windows 11 25H2 in a VM, feed and market through a service, widgets including Win+D.
- **Android:** <GEMESSEN-ANDROID>
- **Linux:** <GEMESSEN-LINUX>
- **Not yet:** macOS, real tablets, displays above 100 % scaling on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    <PRUEFSUMME-WINDOWS>  orangedeck-0.2.9-windows-x86_64.zip
    <PRUEFSUMME-APK>  orangedeck-0.2.9-arm64-v8a.apk
    <PRUEFSUMME-FLATPAK>  orangedeck-0.2.9.flatpak

---

**Deutsch:** 0.2.9 bringt die erste Windows-Fassung – als ZIP ohne Installation, unsigniert (SmartScreen warnt beim ersten Start) – samt Desktop-Widgets, die auch »Desktop anzeigen« stehen lassen. Neu auf allen Geräten ohne eigenen Dienst: Unter *Datenquelle → Dienst auf einem anderen Gerät* holen Telefon, Tablet und Windows Markt und Watch-only-Wallet vom Linux-Rechner im eigenen Netz. Der Dienst antwortet dann jedem im Netz, auch mit den Wallet-Adressen; er bleibt lokal, bis man ihn selbst öffnet. Vor dem Installieren bitte Prüfsumme und Signatur prüfen.
