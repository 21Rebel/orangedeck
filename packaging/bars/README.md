# Anzeige in vorhandenen Leisten

Der billigste Weg zu einer Leistenanzeige auf **beliebigen** Systemen: nicht
selbst eine Leiste bauen, sondern die vorhandene fuettern. Kein Fenster, kein
Compositor-Sonderfall, kein Layer-Shell.

    btcfeed --waybar    JSON  {"text": ..., "tooltip": ..., "class": ...}
    btcfeed --polybar   eine Zeile  (auch i3blocks, yambar)
    btcfeed --genmon    XML  (XFCE-Genmon-Modul)

Alle drei fragen den **laufenden Dienst** auf `127.0.0.1:21021` ab und machen
keinen eigenen Feed auf -- sie sind damit billig genug fuer einen Aufruf alle
paar Sekunden und stoeren den Daemon nicht.

Antwortet der Dienst nicht, kommt `₿ --` mit der Klasse `offline` und einem
Hinweis im Tooltip, wie man ihn startet. Die Leiste bleibt also stehen statt
zu verschwinden.

## Vorlagen

- `waybar.jsonc` + `waybar-style.css`
- `polybar.ini` (gilt auch fuer i3blocks und yambar)
- XFCE: im Genmon-Modul als Befehl `~/.local/bin/btcfeed --genmon` eintragen,
  Ausgabeformat XML.

## Beispielausgabe

    ₿ 965.055 · 2,7 sat/vB

    Block 965.055
    Mempool: 83.487 unbestätigt
    Gebühren: 2,73 / 1,69 / 0,89 sat/vB (schnell/30 min/1 h)
    Kurs: 67.167 EUR
