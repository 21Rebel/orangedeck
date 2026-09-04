# Flathub: was noch zu tun ist

Alles, was ohne ein GitHub-Konto geht, ist fertig. Was hier steht, muss der
Nutzer selbst tun -- die Einreichung laeuft ueber einen Pull Request und
haengt an einer Person, nicht an einem Werkzeug.

## Was fertig ist

- **Der Bauplan** `packaging/flatpak/store._21rebel.orangedeck.git.yml` --
  zieht aus dem oeffentlichen Repo, auf einen Commit festgenagelt. Genau die
  Form, die Flathub verlangt; ein `type: dir` wie im Bauplan zum Arbeiten
  waere abgelehnt worden.
- **Die Metadaten** bestehen `appstreamcli validate`, samt fuenf Screenshots.
- **Die Berechtigungen** sind knapp gehalten: Netz, Wayland (mit Rueckfall auf
  X11), IPC und die Grafikkarte. **Kein `--filesystem`** -- die Anwendung
  fasst nichts auf dem Rechner an, ihre Einstellungen landen unter
  `~/.var/app/store._21rebel.orangedeck`.
- **Der Bauplan wird bei jedem Push gebaut** (`.github/workflows/build.yml`),
  damit er nicht unbemerkt veraltet.

## Was noch fehlt

### 1. Den Commit im Bauplan auf den Auslieferungsstand setzen

Im `...git.yml` steht ein `commit:`. Der muss auf den Stand zeigen, der
ausgeliefert werden soll -- **kein Zweigname**: dann baut jeder Lauf etwas
anderes, und niemand kann sagen, was in einem Paket steckt. Sinnvoll ist ein
Tag:

    git tag -a v0.1.0 -m "erste Auslieferung"
    git push origin v0.1.0
    git rev-parse v0.1.0        # diesen Wert in den Bauplan

Passend dazu gehoert ein `<release>`-Eintrag in die Metadaten.

### 2. Den Antrag stellen

Flathub nimmt Antraege als Pull Request gegen `flathub/flathub`, Zweig
`new-pr`. Hinein gehoert **nur** die Bauplan-Datei, benannt wie die Kennung:

    store._21rebel.orangedeck.yml

Nach der Annahme legt Flathub ein eigenes Repo
`flathub/store._21rebel.orangedeck` an; ab dann wird dort gepflegt.

### 3. Womit im Pruefgespraech zu rechnen ist

**Die Kennung.** `store._21rebel.orangedeck` ist die umgedrehte Form von
`21rebel.store`. Der Unterstrich davor ist **Flathubs eigene Vorgabe** fuer
Segmente, die mit einer Ziffer beginnen -- darauf laesst sich verweisen, falls
jemand stutzt. Voraussetzung ist, dass die Domain `21rebel.store` dem
Antragsteller gehoert; das ist der Fall.

**Kein Signaturzertifikat noetig.** Flathub signiert selbst; die
Entscheidung vom 02.09.2026, dass das Projekt nichts kosten darf, steht dem
also nicht im Weg. Nur Windows und macOS bleiben unsigniert.

**Die portierten Dateien.** `mondrian.js` und `colors.js` stammen aus
bitfeed (MIT). Das Repo fuehrt `LICENSE-bitfeed` und `NOTICE.md`; beides
gehoert erwaehnt, wenn jemand nach der Herkunft fragt.

## Nachpruefen vor dem Antrag

    # Baut aus nichts als Repo-Adresse und Commit?
    flatpak-builder --force-clean --disable-cache \
        --state-dir=/tmp/fp-state /tmp/fp-bau \
        packaging/flatpak/store._21rebel.orangedeck.git.yml

    # Metadaten
    appstreamcli validate packaging/flatpak/store._21rebel.orangedeck.metainfo.xml

    # Flathubs eigener Pruefer (dasselbe Werkzeug wie in deren CI)
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        manifest packaging/flatpak/store._21rebel.orangedeck.git.yml

**Und vorher auf einem fremden System laufen lassen.** Der Leitsatz des
04.09.2026: was nur eine Umgebung angefasst hat, ist ungeprueft. Das Buendel
dafuer erzeugt

    flatpak build-bundle <repo> orangedeck.flatpak store._21rebel.orangedeck \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
