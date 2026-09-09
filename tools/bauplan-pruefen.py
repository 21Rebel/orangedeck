#!/usr/bin/env python3
"""Prueft den Auslieferungs-Bauplan, bevor er eingereicht wird.

    tools/bauplan-pruefen.py

**Warum es das gibt.** Der `commit:` im Bauplan ist die einzige Stelle im
Projekt, die von nichts nachgeprueft wird -- der CI-Lauf setzt ihn vor dem
Bauen auf den eigenen Stand, sonst pruefte er einen alten Baum. Am 05.09.2026
ist er deshalb **dreimal** hinterhergehinkt:

1. dreizehn Commits zurueck, auf einem Stand, der mit dem heutigen Bauplan
   nicht einmal mehr gebaut haette (`CMakeLists.txt` lag dort noch unter
   `app/`),
2. nach vier Oberflaechen-Korrekturen, die sonst nicht ausgeliefert worden
   waeren,
3. nach der Umbenennung auf `dev.orangedeck.OrangeDeck` -- der gepinnte Stand
   trug noch die alte Kennung, und die Datei, die der Bauplan installieren
   will, gab es dort gar nicht.

Der dritte Fall ist der lehrreiche: `flatpak-builder-lint` hat ihn **nicht**
gefunden, weil er nicht baut. Diese Pruefung sieht deshalb im gepinnten Stand
selbst nach.

**Und am 07. wie am 08.09.2026 hat sie zweimal "in Ordnung" gesagt, wo es
nicht in Ordnung war.** Beide Male hinkte der Pin um eine Fassung hinterher:
die Metadaten sagten 0.2.2, der gepinnte Stand enthielt 0.2.1. Die Form
stimmte -- der Commit lag auf `origin/main`, alle Dateien waren da -- also
sagte die Pruefung nichts. Sie prueft seither auch, ob **Nummer und Inhalt
zusammenpassen**, und das ist die einzige Frage, die sie nicht aus der Form
beantworten kann: sie muss die Fassung aus dem gepinnten Stand lesen.

Geprueft wird:
  - der `commit:` ist ein Commit, kein Zweigname und kein Tag-Objekt,
  - er ist auf `origin` veroeffentlicht (sonst kann Flathub ihn nicht holen),
  - jede Datei, die der Bauplan anfasst, liegt in diesem Stand,
  - die Kennung in Dateinamen, Metadaten und `.desktop` ist dieselbe,
  - der gepinnte Stand traegt dieselbe Fassung, die das Projekt jetzt
    ausliefern will, und traegt sie in sich selbst ueberall gleich.
"""
import pathlib, re, subprocess, sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent


def git(*a):
    return subprocess.run(["git", "-C", str(WURZEL), *a],
                          capture_output=True, text=True)


def bei_commit(commit, pfad):
    """Inhalt einer Datei im gepinnten Stand, oder None."""
    r = git("show", "%s:%s" % (commit, pfad))
    return r.stdout if r.returncode == 0 else None


# **Drei Dateien tragen die Nummer**, und jede in ihrer eigenen Schreibweise.
# Fehlt eine der drei Zeilen, gibt die Funktion None zurueck: eine Datei, die
# gar keine Fassung nennt, ist ein anderer Fehler als eine, die eine falsche
# nennt, und wird unten auch anders gemeldet.
FASSUNG = {
    "CMakeLists.txt":
        r"^project\([\w-]+ VERSION ([0-9][0-9.]*)",
    "packaging/flatpak/dev.orangedeck.OrangeDeck.metainfo.xml":
        r"<release\s+version=\"([^\"]+)\"",
    "android/AndroidManifest.xml":
        r"android:versionName=\"([^\"]+)\"",
}


def fassung(text, pfad):
    if text is None:
        return None
    m = re.search(FASSUNG[pfad], text, re.M)
    return m.group(1) if m else None


def main():
    baupläne = sorted(WURZEL.glob("packaging/flatpak/*.yml"))
    liefer = [p for p in baupläne if not p.name.endswith(".dev.yml")]
    if len(liefer) != 1:
        print("FEHLER: genau ein Auslieferungs-Bauplan erwartet, gefunden: %s"
              % [p.name for p in liefer])
        return 1
    plan = liefer[0]
    text = plan.read_text(encoding="utf-8")
    kennung = plan.name[:-len(".yml")]
    fehler = []

    m = re.search(r"^\s*commit:\s*([0-9a-f]{40})\s*$", text, re.M)
    if not m:
        fehler.append("kein vollstaendiger `commit:` im Bauplan "
                      "(ein Zweigname waere hier falsch)")
        commit = None
    else:
        commit = m.group(1)
        art = git("cat-file", "-t", commit).stdout.strip()
        if art != "commit":
            fehler.append("`commit:` ist kein Commit, sondern %r -- bei einem "
                          "annotierten Tag hilft `git rev-parse <tag>^{}`" % art)
        elif "origin/main" not in git("branch", "-r", "--contains", commit).stdout:
            fehler.append("der gepinnte Stand ist nicht auf origin/main -- "
                          "Flathub kann ihn nicht holen")

    # Jede Datei, die der Bauplan anfasst, muss im gepinnten Stand liegen.
    if commit:
        # **Nur Quellpfade, keine Ziele.** Ein `install -Dm644 QUELLE ZIEL`
        # traegt beide nebeneinander, und das Ziel im Sandkasten faengt mit
        # `/app/` an -- ohne die Negativ-Ruecksicht meldete die Pruefung
        # `app/share/metainfo/...` als fehlend, was es im Repo nie gab.
        dateien = set(re.findall(r"(?<![/\w])((?:app|ui|daemon|packaging)/"
                                 r"[\w./_-]+\.(?:xml|svg|desktop|yml|py|sh))", text))
        for d in sorted(dateien):
            if git("cat-file", "-e", "%s:%s" % (commit, d)).returncode != 0:
                fehler.append("im gepinnten Stand fehlt: %s" % d)

    # **Nummer und Inhalt.** Zwei getrennte Fragen, und die Reihenfolge ist
    # wichtig: erst muss der Baum hier mit sich selbst einig sein, sonst gibt
    # es keine Fassung, gegen die sich der Pin halten laesst.
    hier = {}
    for pfad in FASSUNG:
        datei = WURZEL / pfad
        hier[pfad] = fassung(datei.read_text(encoding="utf-8"), pfad) \
            if datei.exists() else None
    fehlt = [p for p, v in hier.items() if v is None]
    for p in sorted(fehlt):
        fehler.append("keine Fassungsnummer gefunden in %s" % p)

    genannt = sorted(set(v for v in hier.values() if v))
    if len(genannt) > 1:
        fehler.append("das Projekt nennt mehrere Fassungen: %s"
                      % ", ".join("%s in %s" % (v, p)
                                  for p, v in sorted(hier.items()) if v))
    soll = genannt[0] if len(genannt) == 1 else None

    if commit:
        # Was der gepinnte Stand von sich selbst sagt. Der Flatpak baut aus
        # diesem Baum -- was hier drinsteht, steht nachher im Paket.
        dort = {}
        for pfad in ("CMakeLists.txt",
                     "packaging/flatpak/"
                     "dev.orangedeck.OrangeDeck.metainfo.xml"):
            dort[pfad] = fassung(bei_commit(commit, pfad), pfad)
        dort_genannt = sorted(set(v for v in dort.values() if v))
        if len(dort_genannt) > 1:
            fehler.append("der gepinnte Stand ist mit sich selbst uneins: %s"
                          % ", ".join("%s in %s" % (v, p)
                                      for p, v in sorted(dort.items()) if v))
        elif not dort_genannt:
            fehler.append("im gepinnten Stand steht keine Fassungsnummer")
        elif soll and dort_genannt[0] != soll:
            fehler.append(
                "der Pin hinkt hinterher: der Bauplan zeigt auf einen Stand "
                "mit %s, ausgeliefert werden soll %s -- ein Bau daraus naehme "
                "die Nummer und liesse den Inhalt zurueck"
                % (dort_genannt[0], soll))

    # Die Kennung muss ueberall dieselbe sein.
    meta = WURZEL / ("packaging/flatpak/%s.metainfo.xml" % kennung)
    if not meta.exists():
        fehler.append("Metadaten fehlen: %s" % meta.name)
    else:
        mid = re.search(r"<id>([^<]+)</id>", meta.read_text(encoding="utf-8"))
        if not mid or mid.group(1) != kennung:
            fehler.append("<id> in den Metadaten ist %r, der Dateiname sagt %r"
                          % (mid.group(1) if mid else None, kennung))
    if not (WURZEL / ("app/%s.desktop" % kennung)).exists():
        fehler.append("app/%s.desktop fehlt" % kennung)

    if fehler:
        print("Bauplan %s -- %d Beanstandung(en):" % (plan.name, len(fehler)))
        for f in fehler:
            print("  * %s" % f)
        return 1
    print("Bauplan %s: in Ordnung." % plan.name)
    print("  Kennung  %s" % kennung)
    print("  Fassung  %s" % soll)
    print("  Commit   %s (%s)" % (commit[:12], git("log", "--format=%s", "-1",
                                                   commit).stdout.strip()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
