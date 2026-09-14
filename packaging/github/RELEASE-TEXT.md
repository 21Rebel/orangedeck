<!-- Text fuer das GitHub-Release von 0.2.9. Die Vorlage fuer 0.2.8 ist am
     12.09.2026 veroeffentlicht worden (https://github.com/21Rebel/orangedeck/releases/tag/v0.2.8)
     und steht in der Geschichte dieser Datei.

     **Vor dem Veroeffentlichen, und erst dann:**

     1. ERLEDIGT 13.09.2026, zweimal: morgens auf 80aee84, abends auf
        053f502 mit dem Markt ohne Dienst. In der Windows-VM Kurs,
        Liquidationen und Heatmap mit Daten, Feed und Mining im Direktbezug,
        Zahnrad oeffnet und schliesst die Einstellungen, Q schliesst
        Hauptfenster und Widget (`tasklist` 1 -> 0), keine neue
        Defender-Erkennung. Gilt fuer den Tag, solange sich app/ und ui/
        nach 053f502 nicht mehr aendern.
     2. Geraetelauf auf dem Galaxy mit dem **Markt ohne Dienst**
        (`DirectMarket.qml`): am 13.09.2026 gesehen, Daten und Umbrueche in
        Ordnung. Danach am selben Tag gebaut und am Galaxy gesehen
        ("sieht jetzt gut aus"): Kurzknoepfe Kerze/Volumen, Zoomen mit zwei
        Fingern, fluessiges Ziehen mit Vorrat, Zahnrad statt Reiter
        "Einstellungen", eigener Zeitraum ohne Ueberlappung, Kerzen bleiben
        Kerzen. Windows danach nachgemessen, siehe Punkt 1. Der Weg "Dienst auf einem anderen Geraet" kam am
        13.09. auf dem Galaxy **nicht** an (App erreichte den Dienst nie,
        die Shell schon, Ursache offen) -- er bleibt fuer die Wallet, wird
        aber nicht als geprueft genannt.
     3. ERLEDIGT 14.09.2026: das Windows-ZIP aus dem CI-Lauf 34852519395 auf
        a5637b5 (die CI laeuft nicht auf Tags; a5637b5 aendert gegenueber
        v0.2.9 = 1147e7a nur den Pin im Flatpak-Bauplan), als
        `orangedeck-0.2.9-windows-x86_64.zip` gepackt, 72 Dateien und
        Bytezahl gegen das Artefakt gehalten.
     4. ERLEDIGT 14.09.2026: drei Pruefsummen eingetragen, APK-Zertifikat
        gegen den Fingerabdruck unten gehalten. Linux neu gemessen: das
        Buendel frisch in Ubuntu 24.04 GNOME und Fedora 44 KDE, Feed, Uhr,
        Mining, Explorer, Markt mit Daten. Zahnrad, Liquidationen und
        Heatmap dort nicht erreicht (in der VM kommen keine Klicks an).

     Veroeffentlicht wird nur mit ausdruecklichem OK des Anwenders. -->

**Windows, and the market on every device.** · *Windows, und der Markt auf jedem Geraet.*

A Bitcoin dashboard: the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, a block explorer and the BTC market. MIT, no account.

## What's new since 0.2.8

- **Windows.** A first Windows build, as a ZIP that runs without installation. Feed, clock, mining, explorer, market and settings work on their own; the wallet comes from an OrangeDeck service on another computer (see below).
- **Desktop widgets on Windows.** The same command line as on Linux turns any view into a frameless widget without a taskbar entry, above or below all other windows — and it stays on the desktop when you press Win+D.
- **The market without a service.** Phones, tablets, Windows and macOS now fetch candles, the trade tape, long/short account ratios and the liquidation heatmap themselves, from the public APIs of Binance, Bybit and OKX. Liquidations come in live while the view is open, plus the last day from OKX; the Linux service keeps listening around the clock and holds two days.
- **Watch-only wallet on phones, tablets and Windows.** New setting *Data source → Service on another device*: enter the address of the Linux computer running the OrangeDeck service, and the wallet appears. **The service then answers anyone on your network**, including with the wallet addresses; the settings page says so, and the service stays local until you open it yourself.
- On narrow screens the market header and the legends of liquidations and heatmap wrap instead of being cut off, candles/line and volume/CVD get compact buttons, and the chart zooms with two fingers.
- Settings open from a gear button next to the fullscreen button instead of a tab; on a phone the last tab used to sit under that button. Back on Android closes them.
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

- **Windows:** Windows 11 25H2 in a VM: feed and mining directly from mempool.space without a service, the market without a service (price, liquidations, heatmap), feed and market through a service, widgets including Win+D, closing window and widget with Q.
- **Android:** Samsung Galaxy A55, Android 16: the market without a service (candles, liquidations, heatmap) with compact buttons, two-finger zoom and the gear button, and the narrow layouts. The wallet through a service on another device did **not** connect on this phone and is untested.
- **Linux:** this Flatpak bundle, freshly installed in Ubuntu 24.04 with GNOME and Fedora 44 with KDE (live sessions in a VM): feed, clock, mining, explorer and the market with live data.
- **Not yet:** macOS, real tablets, displays above 100 % scaling on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    f4dc5d45e05bd51f71b839b11e26fcbc08ec86df4105541f22cb6f861b3e4f2d  orangedeck-0.2.9-windows-x86_64.zip
    bfd75987bf6be12465e75e5ee771eab4265f209842e11c0eed405fa180bd51ce  orangedeck-0.2.9-arm64-v8a.apk
    9e7a9fb7c3ad273790858b6b6cb515a335ab58a5d6af008ba0c43119569fde30  orangedeck-0.2.9.flatpak

---

**Deutsch:** 0.2.9 bringt die erste Windows-Fassung – als ZIP ohne Installation, unsigniert (SmartScreen warnt beim ersten Start) – samt Desktop-Widgets, die auch »Desktop anzeigen« stehen lassen. Neu auf allen Geräten ohne eigenen Dienst: Der Markt holt Kerzen, Band, Long/Short-Verhältnis und Heatmap selbst von Binance, Bybit und OKX; Liquidationen gibt es live und für den letzten Tag. Unter *Datenquelle → Dienst auf einem anderen Gerät* holen Telefon, Tablet und Windows die Watch-only-Wallet vom Linux-Rechner im eigenen Netz. Der Dienst antwortet dann jedem im Netz, auch mit den Wallet-Adressen; er bleibt lokal, bis man ihn selbst öffnet. Vor dem Installieren bitte Prüfsumme und Signatur prüfen.
