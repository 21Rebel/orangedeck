#!/usr/bin/env python3
"""Erzeugt orangedeck.dev aus je einer Textdatei pro Sprache.

    tools/website.py            bauen nach website/fertig/
    tools/website.py --pruefen  nur zeigen, was entstuende

**Warum ein Erzeuger fuer eine einfache Seite.** Die Anwendung spricht
dreizehn Sprachen, und die Seite soll ihr dorthin folgen. Von Hand hiesse das
dreizehn HTML-Dateien, in denen jede Aenderung dreizehnmal gemacht werden
muss -- die erste vergessene macht die Seite unglaubwuerdig. So ist eine
weitere Sprache **eine Datei** in `website/texte/`, sonst nichts.

Ausgegeben wird nach `website/fertig/`:

    fertig/index.html      leitet nach der Browsersprache weiter
    fertig/en/index.html   je Sprache eine Seite
    fertig/de/index.html
    fertig/stil.css, fertig/bilder/...

Das Verzeichnis ist der Ausgabeordner fuer Cloudflare Pages.
"""
import argparse, html, json, pathlib, shutil

WURZEL = pathlib.Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "website"
ZIEL = QUELLE / "fertig"
# Die Reihenfolge aus ui/qml/strings.js -- so steht die Sprachwahl hier in
# derselben Ordnung wie in der Anwendung.
ORDNUNG = ["de", "en", "es", "fr", "it", "pt-pt", "nl", "ru", "ja", "zh",
           "pt-br", "pl", "cs"]


def sprachen():
    gefunden = {}
    for f in sorted(QUELLE.glob("texte/*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        gefunden[d["code"]] = d
    return [gefunden[c] for c in ORDNUNG if c in gefunden]


def e(s):
    return html.escape(s, quote=True)


def seite(d, alle):
    """Aufbau nach shopatch.com: Kopf mit Navigation und Sprachwahl, Hero mit
    zwei Handlungsaufforderungen und Kennzahlen, dann nummerierte Karten,
    Merkmale, Gruende, Fragen, Fuss."""
    nav = "".join('<a href="%s">%s</a>' % (e(z), e(t)) for t, z in d["nav"])
    wahl = "".join(
        '<a href="../%s/" hreflang="%s"%s>%s</a>'
        % (a["code"], a["code"],
           ' aria-current="true"' if a["code"] == d["code"] else "", e(a["name"]))
        for a in alle)
    badges = "".join('<span class="badge">%s</span>' % e(b) for b in d["badges"])
    absaetze = "".join("<p>%s</p>" % e(t) for t in d["was"])
    ansichten = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["ansichten"]))
    wo = "".join('<li><b>%s</b><span class="txt">%s</span></li>' % (e(n), e(t))
                 for n, t in d["wo"])
    warum = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["warum"]))
    holen = "".join(
        ('<a class="knopf" href="%s"><b>%s</b><span>%s</span></a>' % (e(u), e(n), e(t)))
        if u else ('<div class="knopf wartet"><b>%s</b><span>%s</span></div>' % (e(n), e(t)))
        for n, t, u in d["holen"])
    faq = "".join("<details><summary>%s</summary><p>%s</p></details>"
                  % (e(f), e(a)) for f, a in d["faq"])
    return """<!doctype html>
<html lang="%(code)s" dir="%(richtung)s">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(titel)s</title>
<meta name="description" content="%(beschreibung)s">
<meta property="og:title" content="%(titel)s">
<meta property="og:description" content="%(beschreibung)s">
<meta property="og:type" content="website">
<link rel="icon" href="../bilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="../stil.css">
%(alternativen)s
<body>
<div class="kopfleiste"><div class="mitte kopf">
  <a class="marke" href="#"><img src="../bilder/symbol.svg" alt="" width="34" height="34"><span>OrangeDeck</span></a>
  <nav class="nav">%(nav)s</nav>
  <nav class="sprachen">%(wahl)s</nav>
</div></div>

<div class="mitte">
  <header class="hero">
    <h1>%(hero_titel)s</h1>
    <p class="fuehrend">%(hero_text)s</p>
    <div class="knopfreihe">
      <a class="tat" href="%(cta1z)s">%(cta1)s</a>
      <a class="tat zweit" href="%(cta2z)s">%(cta2)s</a>
    </div>
    <div class="badges">%(badges)s</div>
  </header>

  <section class="schau">
    <div class="bilder">
      <img src="../bilder/feed.png" alt="Feed" loading="lazy">
      <img src="../bilder/uhr.png" alt="Clock" loading="lazy">
      <img src="../bilder/markt.png" alt="Market" loading="lazy">
    </div>
  </section>

  <section id="was">
    <h2>%(was_titel)s</h2>
    %(absaetze)s
  </section>

  <section id="ansichten">
    <h2>%(ansichten_titel)s</h2>
    <ul class="karten">%(ansichten)s</ul>
  </section>

  <section id="wo">
    <h2>%(wo_titel)s</h2>
    <ul class="karten schlicht">%(wo)s</ul>
  </section>

  <section id="warum">
    <h2>%(warum_titel)s</h2>
    <ul class="karten">%(warum)s</ul>
  </section>

  <section id="holen">
    <h2>%(holen_titel)s</h2>
    <div class="knopfreihe">%(holen)s</div>
  </section>

  <section id="faq">
    <h2>%(faq_titel)s</h2>
    <div class="fragen">%(faq)s</div>
  </section>

  <!-- Hier kommt spaeter der Spendenteil hin: eine wechselnde Adresse, damit
       sich Zahlungen nicht einer einzigen zuordnen lassen. Braucht einen xpub
       und eine Ableitung, also mehr als eine statische Seite -- deshalb
       bewusst noch nicht drin. -->

  <footer>
    <p class="fuss-tat"><a class="tat" href="#holen">%(fuss_cta)s</a></p>
    <p>%(fuss_lizenz)s %(fuss_herkunft)s</p>
    <p><a href="%(repo)s">github.com/21Rebel/orangedeck</a></p>
    <p class="klein">%(sprache_waehlen)s</p>
    <nav class="sprachen">%(wahl)s</nav>
  </footer>
</div>
</body>
</html>
""" % {"code": d["code"], "richtung": d["richtung"], "titel": e(d["titel"]),
       "beschreibung": e(d["beschreibung"]), "nav": nav, "wahl": wahl,
       "hero_titel": e(d["hero_titel"]), "hero_text": e(d["hero_text"]),
       "cta1": e(d["hero_cta1"]), "cta1z": e(d["hero_cta1_ziel"]),
       "cta2": e(d["hero_cta2"]), "cta2z": e(d["hero_cta2_ziel"]),
       "badges": badges, "was_titel": e(d["was_titel"]), "absaetze": absaetze,
       "ansichten_titel": e(d["ansichten_titel"]), "ansichten": ansichten,
       "wo_titel": e(d["wo_titel"]), "wo": wo,
       "warum_titel": e(d["warum_titel"]), "warum": warum,
       "holen_titel": e(d["holen_titel"]), "holen": holen,
       "faq_titel": e(d["faq_titel"]), "faq": faq,
       "fuss_cta": e(d["fuss_cta"]), "fuss_lizenz": e(d["fuss_lizenz"]),
       "fuss_herkunft": e(d["fuss_herkunft"]), "repo": e(d["repo"]),
       "sprache_waehlen": e(d["sprache_waehlen"]),
       "alternativen": "\n".join(
           '<link rel="alternate" hreflang="%s" href="https://orangedeck.dev/%s/">'
           % (a["code"], a["code"]) for a in alle)
       + '\n<link rel="alternate" hreflang="x-default" href="https://orangedeck.dev/en/">'}


def weiche(alle):
    """Die Wurzel waehlt die Sprache nach dem Browser, mit Englisch als Rueckfall.

    Ohne JavaScript landet man ueber das <noscript> trotzdem irgendwo -- eine
    Seite, die ohne Skript leer bleibt, waere fuer einen Pruefer wertlos.
    """
    codes = ",".join('"%s"' % a["code"] for a in alle)
    liste = " ".join('<a href="%s/">%s</a>' % (a["code"], e(a["name"])) for a in alle)
    return """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OrangeDeck</title>
<link rel="icon" href="bilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="stil.css">
<link rel="canonical" href="https://orangedeck.dev/en/">
<script>
  var da = [%s];
  var w = (navigator.languages || [navigator.language || "en"]);
  var ziel = "en";
  for (var i = 0; i < w.length && ziel === "en"; i++) {
    var l = String(w[i]).toLowerCase();
    if (da.indexOf(l) >= 0) { ziel = l; break; }
    var k = l.split("-")[0];
    if (da.indexOf(k) >= 0) { ziel = k; break; }
  }
  location.replace(ziel + "/");
</script>
<body>
<div class="mitte"><header>
  <div class="marke"><img src="bilder/symbol.svg" alt="" width="72" height="72"><h1>OrangeDeck</h1></div>
  <noscript><p class="unterzeile">%s</p></noscript>
</header></div>
</body>
</html>
""" % (codes, liste)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pruefen", action="store_true")
    args = ap.parse_args()
    tun = not args.pruefen
    alle = sprachen()
    if not alle:
        raise SystemExit("Keine Sprachdateien unter website/texte/")

    if tun and ZIEL.exists():
        shutil.rmtree(ZIEL)
    for d in alle:
        p = ZIEL / d["code"] / "index.html"
        if tun:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(seite(d, alle), encoding="utf-8")
        print("  %s %s" % ("schreibe" if tun else "wuerde", p.relative_to(WURZEL)))
    if tun:
        (ZIEL / "index.html").write_text(weiche(alle), encoding="utf-8")
        shutil.copy2(QUELLE / "stil.css", ZIEL / "stil.css")
        shutil.copytree(QUELLE / "bilder", ZIEL / "bilder")
    print("  %s website/fertig/index.html (Sprachweiche)" % ("schreibe" if tun else "wuerde"))
    print("  %s stil.css und bilder/" % ("kopiere" if tun else "wuerde kopieren"))
    print("\n%d Sprachen: %s" % (len(alle), ", ".join(a["code"] for a in alle)))


if __name__ == "__main__":
    main()
