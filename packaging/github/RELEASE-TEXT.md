<!-- Text fuer das GitHub-Release der ersten Auslieferung. Vorbereitet am
     10.09.2026 fuer 0.2.5, am 11.09.2026 auf 0.2.6 nachgezogen (Mining-Reiter
     mit Netzwerk, zwei Widgets dazu) und nach dem Bildschirmdurchgang auf
     0.2.7, nach dem Bildschirmvergleich ueber alle Systeme auf 0.2.8. Vor
     dem Veroeffentlichen:
     **Die beiden VM-Laeufe fuer 0.2.8 sind am 12.09.2026 gelaufen** --
     Ubuntu 24.04 GNOME und Fedora 44 KDE, beide aus dem Buendel des
     getaggten Standes, alle sechs Ansichten geprueft. Was der Abschnitt
     "Tested on" ueber Linux sagt, stimmt damit.
     **Der Geraetelauf ist am 12.09.2026 gelaufen** und blieb ohne Befund:
     Galaxy A55 unter Android 16, als Update ueber 0.2.7 installiert, der
     Hash der installierten Datei gegen die Summe unten gehalten, vier
     echte Drehungen (mRotation nachgesehen, PID durchgehend dieselbe),
     alle fuenf Reiter, zehn Widgets registriert.

     Damit ist alles geprueft, was diese Datei behauptet.
     **Veroeffentlicht am 12.09.2026** mit ausdruecklichem OK des Anwenders:
     https://github.com/21Rebel/orangedeck/releases/tag/v0.2.8 -- beide
     Dateien danach von GitHub zurueckgeladen, Pruefsummen gleich.

     Fassung ersetzen, die beiden Pruefsummen aus
     ~/.local/share/orangedeck/auslieferung/PRUEFSUMMEN.txt eintragen, und
     nachsehen, ob jede Aussage fuer den getaggten Stand noch stimmt.
     Veroeffentlicht wird nur mit ausdruecklichem OK des Anwenders. -->

**First release.** · *Erste Auslieferung.*

A Bitcoin dashboard: the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, and a block explorer. MIT, no account.

## Android — `orangedeck-0.2.8-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a), Android 9 or newer.

- Feed, clock, mining and explorer; home screen shortcuts for feed, clock and explorer
- **The mining network:** hashrate and difficulty on one chart from 30 days back to 2009, the next adjustment, average block time and the pools of the last week — no miner needed
- **Full-screen block clock:** one tap hides the system bars and tabs, and the screen stays on — an old phone or tablet becomes a block clock on the wall. Tabs can switch on their own every 30 s to 10 min, and the clock can rotate the value it shows large
- **Your own Bitaxe, directly:** enter its address and the mining tab reads it over your Wi-Fi, with its chance of finding a block. If statistics are enabled in AxeOS, the chart shows up to twelve hours of history right away
- Ten home screen widgets: block height, mempool, price, miner and mining network, each as a compact tile and as a larger one with a chart or the explorer's block cards
- Follows your system language (13 languages) until you pick one; the widgets follow along
- **Not in the Android package:** the market tab and the watch-only wallet. Both need the OrangeDeck service that runs on Linux.

Widgets refresh every 30 minutes at most — Android does not allow a shorter interval.

**Check the signature before installing.** The APK is not from an app store, so this is the only way to confirm it comes from us:

    apksigner verify --print-certs orangedeck-0.2.8-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

## Linux — `orangedeck-0.2.8.flatpak`

Until the Flathub listing is through, as a bundle:

    flatpak install --user orangedeck-0.2.8.flatpak

It pulls the KDE runtime 6.9 from Flathub. On Linux all six views are included, market and wallet too.

## Tested on

- **Android:** Samsung Galaxy A55 (Android 16). In the emulator Android 9, 11 and 14, phone and tablet size — there with an x86_64 build of the same source, the arm64 package itself only on the Galaxy.
- **Linux (Flatpak):** Ubuntu 24.04 with GNOME and Fedora 44 with KDE Plasma, both fresh systems in a VM. CachyOS with niri, built from source.
- **Not yet:** real tablets, other manufacturers' home screens, Windows and macOS. If something looks wrong on your device, please open an issue.

## Checksums (SHA-256)

    9f854d42e71e8d71baae4e56b05e2049e23019dbde9ca638bb6c5898f5769dd0  orangedeck-0.2.8-arm64-v8a.apk
    46904a31e3a09fedbda5b022200498d150faa5f86d03c20def5521ef8f71c63f  orangedeck-0.2.8.flatpak

---

**Deutsch:** Die Android-Fassung bringt Feed, Uhr, Mining und Explorer mit, Verknüpfungen für Feed, Uhr und Explorer, ein Vollbild als Blockuhr (der Bildschirm bleibt an, die Reiter wechseln auf Wunsch von selbst) und zehn Widgets für den Startbildschirm. Der Mining-Reiter zeigt das ganze Netzwerk – Hashrate, Schwierigkeit, Pools – auch ohne eigenen Miner; den eigenen Bitaxe liest sie direkt über das WLAN. Markt und Watch-only-Wallet sind **nicht** dabei, sie brauchen den OrangeDeck-Dienst unter Linux. Vor dem Installieren bitte die Signatur prüfen (Befehl und Fingerabdruck oben).
