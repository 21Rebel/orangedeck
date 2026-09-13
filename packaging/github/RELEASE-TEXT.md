<!-- Text fuer das GitHub-Release von 0.2.9. Die Vorlage fuer 0.2.8 ist am
     12.09.2026 veroeffentlicht worden (https://github.com/21Rebel/orangedeck/releases/tag/v0.2.8)
     und steht in der Geschichte dieser Datei.

     **Vor dem Veroeffentlichen, und erst dann:**

     1. ERLEDIGT 13.09.2026 (Stand 80aee84): IPv4-Sperre gefallen; in der
        Windows-VM Feed und Mining im Direktbezug mit Daten, Q schliesst
        Hauptfenster und Widget (`tasklist` leer). Siehe DOKUMENTATION.md,
        "Nachgemessen am 13.09.2026". Fuer den getaggten Stand gilt es erst,
        wenn sich app/ und ui/ bis zum Tag nicht aendern.
     2. Geraetelauf auf dem Galaxy mit dem **Markt ohne Dienst**
        (`DirectMarket.qml`): am 13.09.2026 gesehen, Daten und Umbrueche in
        Ordnung. **Offen davor:** Umschalter Kerze/Kurve und Volumen/CVD am
        Telefon, Zoomen mit zwei Fingern, Vollbildknopf ueber dem Reiter
        "Einstellungen" (Plan: Zahnrad statt Reiter). Der Weg "Dienst auf einem anderen Geraet" kam am
        13.09. auf dem Galaxy **nicht** an (App erreichte den Dienst nie,
        die Shell schon, Ursache offen) -- er bleibt fuer die Wallet, wird
        aber nicht als geprueft genannt.
     3. Das Windows-ZIP aus dem getaggten Stand bauen lassen, als
        `orangedeck-0.2.9-windows-x86_64.zip` packen, Pruefsumme anhaengen.
     4. Die drei Pruefsummen unten eintragen, "Tested on" gegen das Gemessene
        halten, jede Aussage fuer den getaggten Stand nachsehen.

     Veroeffentlicht wird nur mit ausdruecklichem OK des Anwenders. -->

**Windows, and the market on every device.** · *Windows, und der Markt auf jedem Geraet.*

A Bitcoin dashboard: the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, a block explorer and the BTC market. MIT, no account.

## What's new since 0.2.8

- **Windows.** A first Windows build, as a ZIP that runs without installation. Feed, clock, mining, explorer, market and settings work on their own; the wallet comes from an OrangeDeck service on another computer (see below).
- **Desktop widgets on Windows.** The same command line as on Linux turns any view into a frameless widget without a taskbar entry, above or below all other windows — and it stays on the desktop when you press Win+D.
- **The market without a service.** Phones, tablets, Windows and macOS now fetch candles, the trade tape, long/short account ratios and the liquidation heatmap themselves, from the public APIs of Binance, Bybit and OKX. Liquidations come in live while the view is open, plus the last day from OKX; the Linux service keeps listening around the clock and holds two days.
- **Watch-only wallet on phones, tablets and Windows.** New setting *Data source → Service on another device*: enter the address of the Linux computer running the OrangeDeck service, and the wallet appears. **The service then answers anyone on your network**, including with the wallet addresses; the settings page says so, and the service stays local until you open it yourself.
- On narrow screens the market header and the legends of liquidations and heatmap wrap instead of being cut off.
- `--bare` widgets now really hide the header and footer, as documented.

## Windows — `orangedeck-0.2.9-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Windows 10/11, 64-bit.

**Not signed.** A certificate costs money every year and this project is meant to cost nothing. SmartScreen will warn when you start it for the first time (*More info → Run anyway*). Compare the checksum below before you do.

Widgets, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press **Q** to close it. Details in `packaging/widgets/README.md`.

## Android — `orangedeck-0.2.9-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a), Android 9 or newer. Everything from 0.2.8, plus the market without a service and the wallet through a service on your network.

**Check the signature before installing:**

    apksigner verify --print-certs orangedeck-0.2.9-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux — `orangedeck-0.2.9.flatpak`

    flatpak install --user orangedeck-0.2.9.flatpak

It pulls the KDE runtime 6.9 from Flathub. On Linux all six views are included. To serve the wallet to other devices on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- **Windows:** <GEMESSEN-WINDOWS> — bisher: Windows 11 25H2 in a VM, feed and market through a service, feed and mining directly from mempool.space without a service, widgets including Win+D, closing window and widget with Q.
- **Android:** <GEMESSEN-ANDROID>
- **Linux:** <GEMESSEN-LINUX>
- **Not yet:** macOS, real tablets, displays above 100 % scaling on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    <PRUEFSUMME-WINDOWS>  orangedeck-0.2.9-windows-x86_64.zip
    <PRUEFSUMME-APK>  orangedeck-0.2.9-arm64-v8a.apk
    <PRUEFSUMME-FLATPAK>  orangedeck-0.2.9.flatpak

---

**Deutsch:** 0.2.9 bringt die erste Windows-Fassung – als ZIP ohne Installation, unsigniert (SmartScreen warnt beim ersten Start) – samt Desktop-Widgets, die auch »Desktop anzeigen« stehen lassen. Neu auf allen Geräten ohne eigenen Dienst: Der Markt holt Kerzen, Band, Long/Short-Verhältnis und Heatmap selbst von Binance, Bybit und OKX; Liquidationen gibt es live und für den letzten Tag. Unter *Datenquelle → Dienst auf einem anderen Gerät* holen Telefon, Tablet und Windows die Watch-only-Wallet vom Linux-Rechner im eigenen Netz. Der Dienst antwortet dann jedem im Netz, auch mit den Wallet-Adressen; er bleibt lokal, bis man ihn selbst öffnet. Vor dem Installieren bitte Prüfsumme und Signatur prüfen.
