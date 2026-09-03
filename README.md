# OrangeDeck

Ein Bitcoin-Dashboard fuer Linux und Android.

Angefangen hat es als Live-Ansicht des Mempools nach dem Vorbild von
[bitfeed.live](https://bitfeed.live) -- Block in der Mitte, Mempool als Halde
unten, neue Transaktionen fallen von oben hinein. Dazugekommen sind sechs
weitere Ansichten:

    Feed         der Mempool als Halde, Kacheln nach Alter, Gebuehr oder Art
    BlockClock   Blockhoehe gross, Kennzahlen, Kursverlauf bis 2013 zurueck
    Miner        AxeOS und cgminer im Heimnetz, Hashrate und Freigaben
    Explorer     Suche, Transaktionsfluss, Bloecke, geplante Bloecke
    Markt        Kerzen aus den Trades von Binance und Bybit, laufendes Band
    Wallet       watch-only ueber xpub, ypub oder zpub
    Einstellungen

Jede Ansicht laesst sich einzeln abschalten, und jede laeuft in fuenf
Umgebungen: als eigenstaendiges Fenster, als Quickshell-Fenster, als
Dashboard-Tab, im Popout der Leistenpille und als Desktop-Widget. Verdrahtet
sind sie **einmal**, in `ui/qml/FeedTabs.qml`.

Ziel bleibt eine portable Qt-Anwendung fuer jeden Linux-Desktop plus eine
Android-Fassung, die ein Tablet zur Wanduhr macht — siehe `docs/ZIELBILD.md`.

Die Daten kommen von [mempool.space](https://mempool.space) (kein eigener Node
noetig) und, allein fuer den Markt-Reiter, von den oeffentlichen
Handelsstroemen von Binance und Bybit. Ohne Schluessel, ohne Anmeldung.

## Aufbau

    daemon/           orangedeck (Python, stdlib): holt die Daten, bietet sie
                      unter http://127.0.0.1:21021 an
    ui/qml/           die Grafik. Haengt nur an QtQuick -- kein Quickshell,
                      kein Qt Quick Controls (sonst laeuft es nicht ueberall)
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
