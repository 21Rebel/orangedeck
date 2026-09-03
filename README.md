# orangedeck

Live-Ansicht des Bitcoin-Mempools nach dem Vorbild von
[bitfeed.live](https://bitfeed.live): Block in der Mitte, Mempool als Halde
unten, neue Transaktionen fallen von oben hinein.

Heute laeuft das als Integration in die DankMaterialShell (Leistenpille,
Control-Center-Kachel, Desktop-Widget, Dashboard-Tab, eigenes Fenster). Das
Ziel ist eine portable Qt-Anwendung fuer jeden Linux-Desktop plus eine
Android-Fassung, die ein Tablet zur BlockClock macht — siehe `docs/ZIELBILD.md`.

## Aufbau

    daemon/           orangedeck (Python, stdlib): holt die Daten, bietet sie
                      unter http://127.0.0.1:21021 an
    ui/qml/           die Grafik. Haengt nur an QtQuick -- kein Quickshell
    app/              eigenstaendige Qt-Anwendung (CMake), laeuft auf jedem
                      Linux-Desktop und ist die Grundlage fuer Android
    shell/dms/        DMS-Plugin
    shell/quickshell/ eigenes Fenster
    tools/            install-links.sh verlinkt das System gegen dieses Repo
    upstream/bitfeed/ das Original, per git subtree (MIT, siehe NOTICE.md)
    packaging/        Flatpak, Android, systemd-Dienst, Layer-Shell-Widgets

## Einrichten

    tools/install-links.sh

Setzt alle Symlinks unter `~/.local` und `~/.config`. Das Repo ist die Quelle
der Wahrheit, mehrfach aufrufbar.

## Eigenstaendige Anwendung bauen

    cmake -S app -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    ./build/orangedeck-app

Braucht Qt 6.5 oder neuer (Core, Gui, Qml, Quick). Sie benutzt dieselben
QML-Dateien wie das DMS-Plugin -- `ui/qml/` wird nur zusaetzlich ins
QML-Modul gepackt, nicht kopiert.

Tasten: `c` Farbe, `s` Groesse, `i` Blockangaben, `l` Legende, `+`/`-`
Deckkraft, `F11` Vollbild, `q` beenden.

**Fehlersuche:** Qt schickt seine Meldungen auf systemd-Systemen ans Journal,
nicht auf stderr -- QML-Fehler bleiben dadurch unsichtbar. Mit
`QT_FORCE_STDERR_LOGGING=1` starten, dann erscheinen sie.

## Woher die Daten kommen

Zwei Wege, umschaltbar in den Einstellungen unter "Allgemein":

- **Eigener Dienst** (Vorgabe) -- `daemon/orangedeck` auf `127.0.0.1:21021`. Er
  haelt **eine** Verbindung fuer alle Fenster und Widgets, leitet Wallets aus
  dem xpub ab und fragt den Miner im Heimnetz.
- **Direkt** -- die Oberflaeche redet selbst mit mempool.space, ueber denselben
  WebSocket, den auch der Dienst benutzt. Kein Dienst noetig, kein systemd,
  keine Einrichtung. Dafuer fallen Miner und Wallet weg: das eine steht im
  Heimnetz, das andere ist Rechenarbeit des Dienstes.

Auf dem Rechner ist der Dienst die bessere Wahl, auf dem Handy gibt es ihn
nicht. Auf der Befehlszeile: `orangedeck-app --source direct`. Der Direktbezug
braucht `qt6-websockets`; fehlt das Paket, bleibt der Dienst.

## Als Flatpak

    flatpak install --user flathub org.kde.Platform//6.9 org.kde.Sdk//6.9
    flatpak-builder --user --install --force-clean \
        build-flatpak packaging/flatpak/store._21rebel.orangedeck.yml
    flatpak run --user store._21rebel.orangedeck

Das Paket bringt den Daemon mit und startet ihn, falls noch keiner laeuft.

## Als Widget auf dem Desktop

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 \
                --margin 24 --view 1 --bare --id uhr

Jede Ansicht laesst sich einzeln als Layer-Shell-Flaeche auf den Desktop
legen -- unter niri, sway, Hyprland, river, labwc. Alle Schalter und
Startzeilen stehen in `packaging/widgets/README.md`.

## Wo weiterlesen

- `docs/ZIELBILD.md` — wohin es geht, in welcher Reihenfolge
- `docs/STAND.md` — offene Punkte, zuerst hier nachsehen
- `docs/DOKUMENTATION.md` — Mechanik und alle Stolperfallen
- `NOTICE.md` — Herkunft und Lizenzen

## Lizenz

MIT, Copyright 2026 21Rebel — Text in `LICENSE`.

Unter `upstream/bitfeed/` liegt bitfeed selbst, ebenfalls MIT, Copyright
mononaut (`LICENSE-bitfeed`). Zwei Dateien in `ui/qml/` sind Portierungen
daraus. Herkunft und Umfang stehen in `NOTICE.md` — bitte vor jeder
Weitergabe lesen, die MIT-Lizenz verlangt beide Urhebervermerke.
