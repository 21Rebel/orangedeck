# Herkunft und Lizenzen

Dieses Repo vereint zwei Dinge:

## 1. Eigener Code

`daemon/`, `ui/qml/`, `shell/`, `tools/`, `docs/`, `app/`, `packaging/` — hier
entstanden. **Lizenz: MIT, Copyright 2026 21Rebel**, Text in `LICENSE`.

Dieselbe Lizenz wie bitfeed, und das mit Absicht: die beiden portierten
Dateien unten stehen damit unter derselben Bedingung wie ihre Vorlage.

Zwei Dateien darin sind **Portierungen aus bitfeed**, keine Nachempfindungen,
und als solche in ihren Dateikoepfen gekennzeichnet:

| eigene Datei | Vorlage |
|---|---|
| `ui/qml/mondrian.js` | `upstream/bitfeed/client/src/models/TxMondrianPoolScene.js` |
| `ui/qml/colors.js` | `upstream/bitfeed/client/src/utils/color.js` (dort ueber `d3-color`) |

`mondrian.js` weicht bewusst ab: statt der Slot-Liste des Originals fuehrt es
eine exakte Belegungskarte. Grund und Messwerte stehen in
`docs/DOKUMENTATION.md`, Stolperfalle 0.

`colors.js` ist laenger als die Vorlage, weil das Original die HCL-Umrechnung
an `d3-color` abgibt (`hcl(h*360, 78.225, l*150)`) und sie hier ausgeschrieben
ist.

## 2. bitfeed, vollstaendig unter `upstream/bitfeed/`

Am 01.09.2026 per `git subtree` eingehaengt, Historie erhalten (243 Commits).
Quelle: `github.com/bitfeed-project/bitfeed`, Stand `d2272e7` (v2.3.4).

**Lizenz: MIT, Copyright mononaut.** Vollstaendiger Text in `LICENSE-bitfeed`
und in `upstream/bitfeed/LICENSE`. Die MIT-Lizenz verlangt, den
Urheberrechtsvermerk und den Lizenztext mitzuliefern — das gilt fuer jede
Weitergabe dieses Repos.

Aktualisieren:

    git fetch bitfeed
    git subtree pull --prefix=upstream/bitfeed bitfeed master

Zu erwarten ist dabei nichts: **`master` ruht seit dem 13.06.2022.** Ueber alle
Zweige gibt es genau einen juengeren Commit (`display-mode`, 03.04.2023).
