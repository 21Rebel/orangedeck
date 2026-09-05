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

Geprueft wird:
  - der `commit:` ist ein Commit, kein Zweigname und kein Tag-Objekt,
  - er ist auf `origin` veroeffentlicht (sonst kann Flathub ihn nicht holen),
  - jede Datei, die der Bauplan anfasst, liegt in diesem Stand,
  - die Kennung in Dateinamen, Metadaten und `.desktop` ist dieselbe.
"""
import pathlib, re, subprocess, sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent


def git(*a):
    return subprocess.run(["git", "-C", str(WURZEL), *a],
                          capture_output=True, text=True)


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
    print("  Commit   %s (%s)" % (commit[:12], git("log", "--format=%s", "-1",
                                                   commit).stdout.strip()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
