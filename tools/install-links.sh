#!/usr/bin/env bash
# Verlinkt das laufende System gegen dieses Repo.
# Das Repo ist die Quelle der Wahrheit; alles unter ~/.local und ~/.config
# zeigt nur noch hierher. Mehrfach aufrufbar.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Aus dem Verzeichnis gelesen, nicht aufgezaehlt -- siehe Kommentar in
# daemon/btcfeed-dashtab: eine fest verdrahtete Liste vergisst man.
QMLFILES="$(cd "$R/ui/qml" && command ls -1 *.qml *.js 2>/dev/null)"

link() {  # link <ziel-im-repo> <ort-im-system>
  local src="$1" dst="$2"
  [ -e "$src" ] || { echo "fehlt im Repo: $src" >&2; return 1; }
  mkdir -p "$(dirname "$dst")"
  [ -L "$dst" ] && rm -f "$dst"
  [ -e "$dst" ] && rm -f "$dst"
  ln -s "$src" "$dst"
}

# QML-Grafik: der eine Ort, auf den Plugin und Quickshell-App zeigen
for f in $QMLFILES; do
  link "$R/ui/qml/$f" "$HOME/.local/share/btcfeed/qml/$f"
done

# Daemon und Werkzeuge
for f in btcfeed btcfeed-window btcfeed-dashtab; do
  chmod +x "$R/daemon/$f"
  link "$R/daemon/$f" "$HOME/.local/bin/$f"
done

# DMS-Plugin
P="$HOME/.config/DankMaterialShell/plugins/BitcoinFeed"
for f in BitcoinFeedDaemon.qml BitcoinFeedDesktop.qml BitcoinFeedSettings.qml BitcoinFeedWidget.qml plugin.json; do
  link "$R/shell/dms/$f" "$P/$f"
done
for f in DOKUMENTATION.md STAND.md ZIELBILD.md; do
  link "$R/docs/$f" "$P/$f"
done
# die QML-Dateien des Plugins zeigen weiter auf ~/.local/share/btcfeed/qml
for f in $QMLFILES; do
  link "$HOME/.local/share/btcfeed/qml/$f" "$P/$f"
done

# Eigenes Quickshell-Fenster
Q="$HOME/.config/quickshell/BitcoinFeedApp"
link "$R/shell/quickshell/shell.qml" "$Q/shell.qml"
for f in $QMLFILES; do
  link "$HOME/.local/share/btcfeed/qml/$f" "$Q/$f"
done

# --- Benutzerdienst ---------------------------------------------------------
# Ohne ihn laeuft btcfeed als loser Prozess und stirbt mit der Sitzung.
UNIT="$HOME/.config/systemd/user/btcfeed.service"
mkdir -p "$(dirname "$UNIT")"
[ -L "$UNIT" ] && rm -f "$UNIT"
ln -sf "$R/packaging/systemd/btcfeed.service" "$UNIT"
systemctl --user daemon-reload
systemctl --user enable btcfeed.service >/dev/null 2>&1 && echo "Dienst btcfeed eingerichtet"

echo "Verlinkt gegen $R"
