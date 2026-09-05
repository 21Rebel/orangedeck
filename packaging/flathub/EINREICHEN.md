# Flathub: was noch zu tun ist

Alles, was ohne ein GitHub-Konto geht, ist fertig. Was hier steht, muss der
Nutzer selbst tun -- die Einreichung laeuft ueber einen Pull Request und
haengt an einer Person, nicht an einem Werkzeug.

## Was fertig ist

- **Der Bauplan** `packaging/flatpak/store._21rebel.orangedeck.yml` --
  zieht aus dem oeffentlichen Repo, auf einen Commit festgenagelt. Genau die
  Form, die Flathub verlangt; ein `type: dir` wie im Bauplan zum Arbeiten
  waere abgelehnt worden.
- **Die Metadaten** bestehen `appstreamcli validate`, samt fuenf Screenshots.
- **Flathubs eigener Pruefer meldet keinen Fehler** (Stand 05.09.2026). Uebrig
  bleibt ein Hinweis auf die neuere Laufzeit -- inzwischen
  `org.kde.Platform 6.11`, gestern war es noch 6.10; die Zahl wandert weiter,
  der Hinweis bleibt eine Warnung und kein Fehler. Ein Wechsel dorthin zieht
  die Fassung von `layer-shell-qt` nach sich.
- **Die Berechtigungen** sind knapp gehalten: Netz, Wayland (mit Rueckfall auf
  X11), IPC und die Grafikkarte. **Kein `--filesystem`** -- die Anwendung
  fasst nichts auf dem Rechner an, ihre Einstellungen landen unter
  `~/.var/app/store._21rebel.orangedeck`.
- **Der Bauplan wird bei jedem Push gebaut** (`.github/workflows/build.yml`).
  **Aber nicht mit dem Commit, der darin steht:** der Lauf setzt ihn erst auf
  den eigenen Stand, sonst prueft er einen alten Baum statt des neuen. Das ist
  fuer den Lauf richtig und heisst zugleich, dass **der festgenagelte Commit
  die einzige Stelle im Projekt ist, die nichts nachprueft**. Er stand darum
  13 Commits lang auf `3234e0d`, einem Stand, der die beiden in der VM
  gefundenen Korrekturen nicht enthielt und mit dem heutigen Bauplan nicht
  einmal durchgebaut haette (die `CMakeLists.txt` lag dort noch unter `app/`).
  **Vor jeder Einreichung von Hand nachsehen.**

## Was noch fehlt

### 1. Tag setzen und beides veroeffentlichen

**Vorbereitet ist das schon.** Der `<release>`-Eintrag in den Metadaten nennt
`0.1.0`, und der `commit:` im Bauplan zeigt auf den Stand, der ausgeliefert
werden soll -- **kein Zweigname**: dann baut jeder Lauf etwas anderes, und
niemand kann sagen, was in einem Paket steckt.

Was fehlt, ist der Tag auf demselben Stand und der Push:

    git tag -a v0.1.0 <der Commit aus dem Bauplan> -m "erste Auslieferung"
    git push origin main v0.1.0
    git rev-parse v0.1.0        # muss den `commit:` aus dem Bauplan ergeben

Der Tag sitzt auf dem Commit mit den Metadaten, **nicht** auf dem darauf
folgenden, der den Bauplan nachzieht: was gebaut wird, ist der Tag; der
Bauplan selbst steckt nicht im Paket. Erst nach dem Push laesst sich der
Bauplan gegen die echte Adresse pruefen -- vorher gibt es den Commit auf
GitHub nicht.

### 2. Den Antrag stellen

Flathub nimmt Antraege als Pull Request gegen `flathub/flathub`, Zweig
`new-pr`. Hinein gehoert **nur** die Bauplan-Datei, und die heisst hier schon
richtig:

    packaging/flatpak/store._21rebel.orangedeck.yml

**Nicht umbenennen noetig.** Der Pruefer verlangt, dass der Dateiname der
Kennung entspricht (`appid-filename-mismatch`), und deshalb traegt der
Auslieferungs-Bauplan den kanonischen Namen -- der zum Arbeiten heisst
`...dev.yml`. So ist die eingereichte Datei byteweise dieselbe wie die
gepruefte.

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
        packaging/flatpak/store._21rebel.orangedeck.yml

    # Metadaten
    appstreamcli validate packaging/flatpak/store._21rebel.orangedeck.metainfo.xml

    # Flathubs eigener Pruefer (dasselbe Werkzeug wie in deren CI)
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        manifest packaging/flatpak/store._21rebel.orangedeck.yml

**Und vorher auf einem fremden System laufen lassen.** Der Leitsatz des
04.09.2026: was nur eine Umgebung angefasst hat, ist ungeprueft. Das Buendel
dafuer erzeugt

    flatpak build-bundle <repo> orangedeck.flatpak store._21rebel.orangedeck \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
