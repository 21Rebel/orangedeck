# Widgets auf dem Desktop -- ohne DMS

In DankMaterialShell legt man die Ansichten ueber die Einstellungen des
Plugins auf den Desktop. Ueberall sonst geht dasselbe mit **Layer-Shell**:

    orangedeck-app --layer <ebene> --anchor <kanten> [--width N] [--height N]
                [--margin N] [--exclusive N] [--view N] [--bare] [--id name]

**Nicht aus dem Flatpak.** Compositoren blenden privilegierte Protokolle vor
Sandkastenprogrammen aus (`wp_security_context_v1`), und Layer-Shell gehoert
dazu -- ein Programm im Sandkasten soll sich nicht ueber den ganzen Bildschirm
legen koennen. Aus dem Flatpak zeigt `--layer` deshalb nur ein gewoehnliches
Fenster. Fuer Widgets die Anwendung selbst bauen.

Das setzt `layer-shell-qt` (Qt6) beim Bauen voraus. Fehlt es, faellt nur
`--layer` weg -- `cmake` sagt das beim Einrichten. Getragen wird es von allen
wlroots-nahen Compositoren: **niri, sway, Hyprland, river, labwc, Wayfire**.
Auf X11 gibt es keine Layer-Shell; dort bleibt das gewoehnliche Fenster.

| Schalter | Bedeutung |
|---|---|
| `--layer` | `background`, `bottom` (Vorgabe), `top`, `overlay` |
| `--anchor` | Kanten mit Komma: `top,bottom,left,right`. Zwei gegenueberliegende dehnen die Flaeche |
| `--width` / `--height` | gewuenschte Groesse; an gedehnten Kanten entscheidet der Compositor |
| `--margin` | eine Zahl, oder `oben,rechts,unten,links` |
| `--exclusive` | Platz, den andere Fenster freilassen. `0` keiner, `-1` sich ueberlappen lassen |
| `--view` | `0` Feed, `1` Blockclock, `2` Miner, `3` Explorer, `4` Wallet, `5` Einstellungen |
| `--bare` | ohne Reiter, Kopf- und Fusszeile -- die Ansicht allein |
| `--id` | eigener Einstellungsspeicher (`~/.config/orangedeck/orangedeck-<name>.conf`) |

**`--id` ist der Punkt, an dem mehrere Widgets nebeneinander gehen.** Ohne ihn
teilen sich alle dieselbe Datei und schreiben sich gegenseitig um -- mit ihm
behaelt jedes seine Ansicht, seine Sprache, seine Waehrung.

## Beispiele

Blockclock als Kachel rechts oben, ohne Reiter:

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 \
                --margin 24 --view 1 --bare --id uhr

Der Feed als Leiste ueber die ganze Breite, unter den Fenstern, mit
freigehaltenem Platz:

    orangedeck-app --layer bottom --anchor bottom,left,right --height 110 \
                --exclusive 110 --view 0 --bare --id leiste

Der Miner links oben:

    orangedeck-app --layer top --anchor top,left --width 300 --height 300 \
                --margin 24 --view 2 --bare --id miner

## Beim Anmelden mitstarten

**niri** (`~/.config/niri/config.kdl`):

    spawn-at-startup "orangedeck-app" "--layer" "top" "--anchor" "top,right" \
        "--width" "300" "--height" "220" "--margin" "24" \
        "--view" "1" "--bare" "--id" "uhr"

**Hyprland** (`~/.config/hypr/hyprland.conf`):

    exec-once = orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr

**sway** (`~/.config/sway/config`):

    exec orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr

**labwc** (`~/.config/labwc/autostart`):

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr &

Ueberall gilt: der Daemon muss laufen. `tools/install-links.sh` richtet ihn als
Benutzerdienst ein, danach genuegt

    systemctl --user enable --now orangedeck.service

## Leisten statt Widgets

Wer nur eine Zahl in der vorhandenen Leiste will, braucht das alles nicht:
`packaging/bars/` hat fertige Bausteine fuer waybar und polybar, die den
Daemon direkt abfragen.
