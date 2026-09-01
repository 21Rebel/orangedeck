# btcfeed

Live-Ansicht des Bitcoin-Mempools nach dem Vorbild von
[bitfeed.live](https://bitfeed.live): Block in der Mitte, Mempool als Halde
unten, neue Transaktionen fallen von oben hinein.

Heute laeuft das als Integration in die DankMaterialShell (Leistenpille,
Control-Center-Kachel, Desktop-Widget, Dashboard-Tab, eigenes Fenster). Das
Ziel ist eine portable Qt-Anwendung fuer jeden Linux-Desktop plus eine
Android-Fassung, die ein Tablet zur BlockClock macht — siehe `docs/ZIELBILD.md`.

## Aufbau

    daemon/           btcfeed (Python, stdlib): holt die Daten, bietet sie
                      unter http://127.0.0.1:21021 an
    ui/qml/           die Grafik. Haengt nur an QtQuick -- kein Quickshell
    app/              eigenstaendige Qt-Anwendung (CMake), laeuft auf jedem
                      Linux-Desktop und ist die Grundlage fuer Android
    shell/dms/        DMS-Plugin
    shell/quickshell/ eigenes Fenster
    tools/            install-links.sh verlinkt das System gegen dieses Repo
    upstream/bitfeed/ das Original, per git subtree (MIT, siehe NOTICE.md)
    packaging/        noch leer: Flatpak und Android

## Einrichten

    tools/install-links.sh

Setzt alle Symlinks unter `~/.local` und `~/.config`. Das Repo ist die Quelle
der Wahrheit, mehrfach aufrufbar.

## Eigenstaendige Anwendung bauen

    cmake -S app -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    ./build/btcfeed-app

Braucht Qt 6.5 oder neuer (Core, Gui, Qml, Quick). Sie benutzt dieselben
QML-Dateien wie das DMS-Plugin -- `ui/qml/` wird nur zusaetzlich ins
QML-Modul gepackt, nicht kopiert.

Tasten: `c` Farbe, `s` Groesse, `i` Blockangaben, `l` Legende, `+`/`-`
Deckkraft, `F11` Vollbild, `q` beenden.

**Fehlersuche:** Qt schickt seine Meldungen auf systemd-Systemen ans Journal,
nicht auf stderr -- QML-Fehler bleiben dadurch unsichtbar. Mit
`QT_FORCE_STDERR_LOGGING=1` starten, dann erscheinen sie.

## Wo weiterlesen

- `docs/ZIELBILD.md` — wohin es geht, in welcher Reihenfolge
- `docs/STAND.md` — offene Punkte, zuerst hier nachsehen
- `docs/DOKUMENTATION.md` — Mechanik und alle Stolperfallen
- `NOTICE.md` — Herkunft und Lizenzen
