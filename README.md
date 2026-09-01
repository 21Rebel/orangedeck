# btcfeed

Live-Ansicht des Bitcoin-Mempools nach dem Vorbild von
[bitfeed.live](https://bitfeed.live): Block in der Mitte, Mempool als Halde
unten, neue Transaktionen fallen von oben hinein.

Heute laeuft das als Integration in die DankMaterialShell (Leistenpille,
Control-Center-Kachel, Desktop-Widget, Dashboard-Tab, eigenes Fenster). Das
Ziel ist eine portable Qt-Anwendung fuer jeden Linux-Desktop plus eine
Android-Fassung, die ein Tablet zur BlockClock macht — siehe `docs/ZIELBILD.md`.

## Aufbau

    daemon/           btcfeed (Python, stdlib): holt die Daten, schreibt state.json
    ui/qml/           die Grafik. FeedCanvas und FeedPanel haengen nur an QtQuick
    shell/dms/        DMS-Plugin
    shell/quickshell/ eigenes Fenster
    tools/            install-links.sh verlinkt das System gegen dieses Repo
    upstream/bitfeed/ das Original, per git subtree (MIT, siehe NOTICE.md)
    packaging/        noch leer: Flatpak und Android

## Einrichten

    tools/install-links.sh

Setzt alle Symlinks unter `~/.local` und `~/.config`. Das Repo ist die Quelle
der Wahrheit, mehrfach aufrufbar.

## Wo weiterlesen

- `docs/ZIELBILD.md` — wohin es geht, in welcher Reihenfolge
- `docs/STAND.md` — offene Punkte, zuerst hier nachsehen
- `docs/DOKUMENTATION.md` — Mechanik und alle Stolperfallen
- `NOTICE.md` — Herkunft und Lizenzen
