# orangedeck.dev

Die Seite entsteht aus `tools/website.py`. **Eine weitere Sprache ist eine
Datei** in `website/texte/`, sonst nichts -- die Anwendung spricht dreizehn,
und die Seite soll ihr dorthin folgen koennen, ohne dass jede Aenderung
dreizehnmal gemacht werden muss.

    tools/website.py            bauen nach website/fertig/
    tools/website.py --pruefen  nur zeigen, was entstuende

## Aufbau

Angelehnt an shopatch.com: klebende Kopfleiste mit Navigation und Sprachwahl
rechts, Hero mit zwei Handlungsaufforderungen und Kennzahlen, Bildstreifen,
dann nummerierte Karten (Ansichten), Wirte, Gruende, Bezugswege, Fragen als
aufklappbare Zeilen, Fuss.

## Sprachen

`ORDNUNG` in `tools/website.py` ist die Reihenfolge aus `ui/qml/strings.js`,
damit Seite und Anwendung dieselbe Ordnung zeigen. Vorhanden sind `de` und
`en`; die uebrigen elf (`es fr it pt-pt nl ru ja zh pt-br pl cs`) fehlen noch
und erscheinen erst, wenn ihre Datei da ist -- eine halbe Uebersetzung ist
schlimmer als keine.

`fertig/index.html` waehlt die Sprache nach dem Browser und faellt auf
Englisch zurueck. Ohne JavaScript steht dort eine Liste zum Anklicken; eine
Seite, die ohne Skript leer bleibt, waere fuer einen Pruefer wertlos.

## Veroeffentlichen

`website/fertig/` ist mitgeliefert, damit Cloudflare Pages **ohne Bauschritt**
darauf zeigen kann:

    Build command:      (leer)
    Build output:       website/fertig

Wer lieber bauen laesst: `python3 tools/website.py` als Bauschritt, gleiches
Ausgabeverzeichnis.

## Was noch fehlt

- **Impressum und Datenschutzerklaerung.** Fuer eine aus Deutschland
  betriebene Seite sind sie Pflicht, und sie lassen sich nicht erfinden --
  Name, Anschrift und Kontakt muessen stimmen. Sie fehlen bewusst, statt mit
  Platzhaltern zu suggerieren, es sei erledigt.
- **Die elf uebrigen Sprachen.**
- **Der Spendenteil**: eine wechselnde Adresse, damit sich Zahlungen nicht
  einer einzigen zuordnen lassen. Braucht einen xpub und eine Ableitung, also
  mehr als eine statische Seite.
