# Vorlage fuer den Antrag bei Flathub

Einzureichen ist **eine Datei**, unveraendert:

    packaging/flatpak/dev.orangedeck.OrangeDeck.yml

Ziel: Pull Request gegen `flathub/flathub`, Zweig **`new-pr`**. Der Zweig im
eigenen Fork heisst ueblicherweise wie die Kennung.

---

## Titel

    Add dev.orangedeck.OrangeDeck (OrangeDeck)

## Text

OrangeDeck is a live view of the Bitcoin mempool: waiting transactions fall
onto a heap as a tile mosaic, confirmed ones fly into the block. It also has a
block height clock, mining figures, a block explorer and watch-only addresses.

- Upstream: https://github.com/21Rebel/orangedeck
- Tag: `v0.2.0` (the manifest pins the commit, not a branch)
- License: MIT

**About the app ID.** `dev.orangedeck.OrangeDeck` is the reverse of the domain
`orangedeck.dev`, which I own and which serves the project's page.

**Third-party code.** `mondrian.js` and `colors.js` are ported from bitfeed
(MIT, mononaut). The repository carries `LICENSE-bitfeed` and `NOTICE.md`.

**Permissions.** Network, Wayland with X11 fallback, IPC and the GPU. No
`--filesystem` at all: the app touches nothing on the machine, its settings
live under `~/.var/app/dev.orangedeck.OrangeDeck`.

**Verified.** `flatpak-builder` builds from the public repository at the
tagged commit, `appstreamcli validate` is clean, and
`flatpak-builder-lint manifest` reports no errors -- only the hint about a
newer runtime. The bundle has been run on a machine that knows nothing about
the project (Ubuntu 24.04, no Qt 6.6, no Quickshell).

---

## Falle: `--body-file` zeigt nicht auf diese Datei

Diese Datei ist die **Vorlage**, nicht der Antragstext -- sie traegt deutsche
Ueberschriften, den Weg mit `gh` und diesen Hinweis. Wer sie als
`--body-file` uebergibt, reicht das alles mit ein. Der englische Abschnitt
unter "## Text" wird vorher herausgeschnitten.

## Vor dem Absenden

**Von welchem Konto?** Flathub fragt im Pruefgespraech, ob der Einreichende
der Entwickler ist. Der Antrag sollte deshalb von dem Konto kommen, dem auch
`21Rebel/orangedeck` gehoert -- sonst gibt es dort eine Rueckfrage, die man
sich sparen kann. Am 05.09.2026 war `gh` auf diesem Rechner als `Shopatch`
angemeldet, ohne Push-Recht auf das Projekt.

    gh auth status                 # welches Konto?
    gh auth login                  # gegebenenfalls wechseln

## Der Weg mit gh

    gh repo fork flathub/flathub --clone --remote=false -- /tmp/flathub
    cd /tmp/flathub
    git checkout -b dev.orangedeck.OrangeDeck origin/new-pr
    cp ~/Schreibtisch/orangedeck/packaging/flatpak/dev.orangedeck.OrangeDeck.yml .
    git add dev.orangedeck.OrangeDeck.yml
    git commit -m "Add dev.orangedeck.OrangeDeck (OrangeDeck)"
    git push -u origin dev.orangedeck.OrangeDeck
    # Nur den Abschnitt "## Text" herausschneiden -- siehe die Falle oben.
    awk '/^## Text$/{an=1;next} /^---$/{an=0} an' PR-TEXT.md > /tmp/pr-body.md
    gh pr create --repo flathub/flathub --base new-pr \
        --title "Add dev.orangedeck.OrangeDeck (OrangeDeck)" \
        --body-file /tmp/pr-body.md
