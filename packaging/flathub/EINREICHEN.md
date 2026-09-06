# Flathub: was noch zu tun ist

> **Der erste Versuch ist am 06.09.2026 gescheitert, und zwar nicht an der
> Technik.** PR #10105 wurde eine Minute nach dem Absenden vom
> `submission-checker` automatisch geschlossen und mit dem Etikett *AI Slop*
> versehen. Zwei Ursachen, die zweite ist die schwerere -- beide stehen unten
> unter "Die Regel, an der der erste Versuch gescheitert ist".


Alles, was ohne ein GitHub-Konto geht, ist fertig. Was hier steht, muss der
Nutzer selbst tun -- die Einreichung laeuft ueber einen Pull Request und
haengt an einer Person, nicht an einem Werkzeug.

## Was fertig ist

- **Der Bauplan** `packaging/flatpak/dev.orangedeck.OrangeDeck.yml` --
  zieht aus dem oeffentlichen Repo, auf einen Commit festgenagelt. Genau die
  Form, die Flathub verlangt; ein `type: dir` wie im Bauplan zum Arbeiten
  waere abgelehnt worden.
- **Die Metadaten** bestehen `appstreamcli validate`, samt fuenf Screenshots.
- **Flathubs eigener Pruefer meldet keinen Fehler** (Stand 05.09.2026). Uebrig
  bleibt ein Hinweis auf eine neuere Laufzeit. **Welche, schwankt:** derselbe
  Pruefer nannte am 05.09. vormittags `org.kde.Platform 6.11` und
  nachmittags wieder 6.10. Die Zahl taugt also nicht als Zielangabe -- der
  Hinweis bleibt in jedem Fall eine Warnung und kein Fehler. Ein Wechsel
  zieht die Fassung von `layer-shell-qt` nach sich.
- **Die Berechtigungen** sind knapp gehalten: Netz, Wayland (mit Rueckfall auf
  X11), IPC und die Grafikkarte. **Kein `--filesystem`** -- die Anwendung
  fasst nichts auf dem Rechner an, ihre Einstellungen landen unter
  `~/.var/app/dev.orangedeck.OrangeDeck`.
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
    git rev-parse v0.1.0^{}     # muss den `commit:` aus dem Bauplan ergeben

**Die geschweiften Klammern gehoeren dazu.** Ein annotierter Tag (`-a`) ist
ein eigenes Objekt mit eigenem SHA; `git rev-parse v0.1.0` gibt **den**
zurueck, nicht den Commit darunter. Hier stand bis zum 05.09.2026 die Zeile
ohne `^{}` -- wer sie befolgt haette, haette den SHA des Tag-Objekts in den
Bauplan gesetzt, und `flatpak-builder` haette einen Commit gesucht, den es
nicht gibt. Aufgefallen beim Anwenden, nicht beim Schreiben.

Der Tag sitzt auf dem Commit mit den Metadaten, **nicht** auf dem darauf
folgenden, der den Bauplan nachzieht: was gebaut wird, ist der Tag; der
Bauplan selbst steckt nicht im Paket. Erst nach dem Push laesst sich der
Bauplan gegen die echte Adresse pruefen -- vorher gibt es den Commit auf
GitHub nicht.

### 2. Den Antrag stellen

**Zuerst: von welchem Konto?** Flathub fragt im Pruefgespraech, ob der
Einreichende der Entwickler ist. Der Antrag gehoert deshalb von dem Konto,
dem auch `21Rebel/orangedeck` gehoert. Am 05.09.2026 war `gh` auf diesem
Rechner als `Shopatch` angemeldet und hatte **kein** Push-Recht auf das
Projekt -- ein Antrag von dort haette dieselbe Rueckfrage ausgeloest wie eine
fremde Kennung. `gh auth status` sagt, wer gerade spricht.

Titel und Text des Antrags liegen fertig in `packaging/flathub/PR-TEXT.md`,
samt der Befehlsfolge mit `gh`.


Flathub nimmt Antraege als Pull Request gegen `flathub/flathub`, Zweig
`new-pr`. Hinein gehoert **nur** die Bauplan-Datei, und die heisst hier schon
richtig:

    packaging/flatpak/dev.orangedeck.OrangeDeck.yml

**Nicht umbenennen noetig.** Der Pruefer verlangt, dass der Dateiname der
Kennung entspricht (`appid-filename-mismatch`), und deshalb traegt der
Auslieferungs-Bauplan den kanonischen Namen -- der zum Arbeiten heisst
`...dev.yml`. So ist die eingereichte Datei byteweise dieselbe wie die
gepruefte.

Nach der Annahme legt Flathub ein eigenes Repo
`flathub/dev.orangedeck.OrangeDeck` an; ab dann wird dort gepflegt.

### 3. Womit im Pruefgespraech zu rechnen ist

**Die Kennung.** `dev.orangedeck.OrangeDeck` ist die umgedrehte Form von
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
        packaging/flatpak/dev.orangedeck.OrangeDeck.yml

    # Metadaten
    appstreamcli validate packaging/flatpak/dev.orangedeck.OrangeDeck.metainfo.xml

    # Flathubs eigener Pruefer (dasselbe Werkzeug wie in deren CI)
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder \
        manifest packaging/flatpak/dev.orangedeck.OrangeDeck.yml

**Und vorher auf einem fremden System laufen lassen.** Der Leitsatz des
04.09.2026: was nur eine Umgebung angefasst hat, ist ungeprueft. Das Buendel
dafuer erzeugt

    flatpak build-bundle <repo> orangedeck.flatpak dev.orangedeck.OrangeDeck \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo


## Die Regel, an der der erste Versuch gescheitert ist

### 1. Der PR-Rumpf **ist** die Pruefliste

`flathub/flathub` hat eine `pull_request_template.md`, und sie ist keine
Hoeflichkeit: ein Bot laeuft stuendlich, prueft die Haken und **schliesst den
PR automatisch**, wenn die Liste fehlt oder unvollstaendig ist. Wer den Rumpf
durch einen eigenen Text ersetzt, loescht damit die Pruefliste.

Der Text aus `PR-TEXT.md` gehoert also **in** die Vorlage (beim Punkt
"Please describe the application briefly"), nicht an ihre Stelle.

Was die Liste verlangt, mit dem, was hier fehlt:

| Haken | Stand |
|---|---|
| Beschreibung | steht in `PR-TEXT.md` |
| **Video der laufenden Flatpak-Fassung auf Linux** | **fehlt** |
| Kennung nach den Regeln | erfuellt, `dev.orangedeck.OrangeDeck` aus `orangedeck.dev` |
| Entwicklungsgeschichte, echter Gebrauch, Zusage zur Pflege | **fraglich, siehe unten** |
| **Offenlegung KI-erzeugten Materials, mit Umfang** | **noetig, siehe unten** |
| **Keine KI-Werkzeuge fuer diesen PR und seine Rueckmeldungen** | **war beim ersten Versuch verletzt** |
| Autor/Entwickler des Projekts | erfuellt |

### 2. KI darf den Antrag nicht stellen

Flathubs Generative-AI-Richtlinie, woertlich:

> AI tools or agents **must not open or automate Flathub submission pull
> requests**, or generate their commit messages, descriptions, review
> comments, or replies.

Beim ersten Versuch wurden alle vier Dinge von einem Agenten getan: der PR
geoeffnet, seine Beschreibung geschrieben, die Commit-Nachricht im Zweig
verfasst. Genau das hat der Bot erkannt.

**Praktisch heisst das:** der Antrag wird von Hand gestellt. Der Rumpf, die
Commit-Nachricht im Flathub-Zweig und **jede Antwort im Pruefgespraech**
gehoeren einem Menschen. Ein Agent darf recherchieren, bauen, messen und
diese Datei hier schreiben -- er darf nichts davon einreichen.

Der Zweig `dev.orangedeck.OrangeDeck` in der Abzweigung wurde deshalb
geloescht: sein einziger Commit trug eine maschinell geschriebene Nachricht,
und ein Zweig, den man nicht weiterverwenden darf, ist eine Falle. Neu
anlegen ist eine Zeile -- es geht um **eine** Datei.

### 3. Was ausserdem offengelegt werden muss

> Submitters must reveal any AI-generated code, documentation, packaging, or
> other material they know or reasonably believe is included in the
> application or its Flathub packaging, identifying affected parts and extent.

Der Umfang ist hier betraechtlich und laesst sich beziffern:

    git rev-list --count HEAD                          422 Commits
    git log --format=%b | grep -c Co-Authored-By: Claude    120

Betroffen sind Anwendung **und** Verpackung. Ausgenommen von der
Offenlegungspflicht ist nur, was zu Recherche, Gespraech und Fehlersuche
diente und nicht im Ergebnis steht -- das trifft hier nicht zu.

Nicht offengelegtes Material kann zur Ablehnung fuehren, wiederholte
Verstoesse zu einer dauerhaften Sperre. **Das ist kein Formular, das ist eine
Aussage.**

### 4. Die Entwicklungsgeschichte ist der schwerere Punkt

> Submissions must demonstrate a meaningful history of development or
> existence, evidence of real-world use and a clear commitment to ongoing
> maintenance. […] applications that have only existed for a very short
> period of time will generally not be accepted.

Die eigene Arbeit an OrangeDeck laeuft vom **01.09.2026 bis heute** -- sechs
Tage, 179 Commits, drei Tags. Dicht, aber kurz. "Evidence of real-world use"
gibt es nach sechs Tagen kaum, und das haengt nicht daran, wie gut das
Programm ist.

Das ist vor dem naechsten Anlauf zu entscheiden und nicht wegzuhaken: entweder
das Projekt laeuft eine Weile oeffentlich, sammelt Nutzung und Ausgaben --
oder der Antrag geht mit dem Wissen raus, dass dieser Punkt eine Rueckfrage
ausloest.
