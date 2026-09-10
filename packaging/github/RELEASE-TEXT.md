<!-- Text fuer das GitHub-Release der ersten Auslieferung. Vorbereitet am
     10.09.2026 fuer 0.2.5 und dort nicht mehr verwendet (siehe metainfo,
     die Nummer wanderte ein weiteres Mal). Vor dem Veroeffentlichen:
     Fassung ersetzen, die beiden Pruefsummen aus
     ~/.local/share/orangedeck/auslieferung/PRUEFSUMMEN.txt eintragen, und
     nachsehen, ob jede Aussage fuer den getaggten Stand noch stimmt.
     Veroeffentlicht wird nur mit ausdruecklichem OK des Anwenders. -->

**First release.** · *Erste Auslieferung.*

A Bitcoin dashboard: the mempool as a live tile mosaic, a block height clock, mining figures from your own Bitaxe, and a block explorer. MIT, no account.

## Android — `orangedeck-0.2.6-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a), Android 9 or newer.

- Feed, clock, miner and explorer; home screen shortcuts for feed, clock and explorer
- **Full-screen block clock:** one tap hides the system bars and tabs, and the screen stays on — an old phone or tablet becomes a block clock on the wall
- **Your own Bitaxe, directly:** enter its address and the miner tab reads it over your Wi-Fi. If statistics are enabled in AxeOS, the chart shows up to twelve hours of history right away
- Eight home screen widgets: block height, mempool, price and miner, each as a compact tile and as a larger one with a chart or the explorer's block cards
- Follows your system language (13 languages) until you pick one; the widgets follow along
- **Not in the Android package:** the market tab and the watch-only wallet. Both need the OrangeDeck service that runs on Linux.

Widgets refresh every 30 minutes at most — Android does not allow a shorter interval.

**Check the signature before installing.** The APK is not from an app store, so this is the only way to confirm it comes from us:

    apksigner verify --print-certs orangedeck-0.2.6-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux — `orangedeck-0.2.6.flatpak`

Until the Flathub listing is through, as a bundle:

    flatpak install --user orangedeck-0.2.6.flatpak

It pulls the KDE runtime 6.9 from Flathub. On Linux all six views are included, market and wallet too.

## Checksums (SHA-256)

    <PRUEFSUMME-APK>  orangedeck-0.2.6-arm64-v8a.apk
    <PRUEFSUMME-FLATPAK>  orangedeck-0.2.6.flatpak

---

**Deutsch:** Die Android-Fassung bringt Feed, Uhr, Miner und Explorer mit, Verknüpfungen für Feed, Uhr und Explorer, ein Vollbild als Blockuhr (der Bildschirm bleibt an) und acht Widgets für den Startbildschirm. Den eigenen Bitaxe liest sie direkt über das WLAN. Markt und Watch-only-Wallet sind **nicht** dabei, sie brauchen den OrangeDeck-Dienst unter Linux. Vor dem Installieren bitte die Signatur prüfen (Befehl und Fingerabdruck oben).
