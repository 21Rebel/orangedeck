# Weichzeichnen hinter dem Fenster

**Die Anwendung kann das nicht selbst.** Sie setzt ihre Deckkraft, mehr
liegt nicht in ihrer Hand -- was hinter einem Fenster steht, sieht ein
Wayland-Programm nie. Der milchige Eindruck entsteht erst, wenn der
Compositor die Flaeche dahinter weichzeichnet, und dazu braucht er eine
Regel.

Ohne diese Regel heisst eine Deckkraft unter 1 schlicht: man liest das
Fenster dahinter mit, scharf und quer durch die Graphen. Deshalb ist die
Vorgabe **deckend** (`bgOpacity 1,0`); wer den milchigen Look will, zieht
den Regler in den Einstellungen zurueck **und** legt hier eine Regel an.

## Die Kennung, nach der gesucht wird

    store._21rebel.orangedeck

Das ist die `app_id` der Wayland-Flaeche. Sie kommt aus
`QGuiApplication::setDesktopFileName()` (siehe `app/src/main.cpp`) und ist
dieselbe Kennung wie im Flatpak und in der `.desktop`-Datei.

**Nicht ueber den Fenstertitel gehen.** Der Titel ist Anzeigetext: er
aendert sich, wenn die Anwendung umbenannt wird, und eine Regel, die auf ihn
zeigt, greift danach stillschweigend ins Leere -- kein Fehler, keine
Meldung, nur kein Blur mehr. Genau das ist am 05.09.2026 aufgefallen, als
eine Regel auf `title="^Bitcoin Feed$"` nach der Umbenennung auf OrangeDeck
liegenblieb.

## niri

In `~/.config/niri/config.kdl`:

    window-rule {
        match app-id=r#"^store\._21rebel\.orangedeck$"#
        background-effect {
            blur true
            xray false
        }
    }

`xray false` zeichnet weich, was tatsaechlich dahinter liegt. Mit
`xray true` nimmt niri stattdessen den Hintergrund des Arbeitsbereichs --
ruhiger, aber die Fenster dahinter verschwinden dabei.

Pruefen mit `niri validate`, und die laufende Kennung zeigt

    niri msg windows

## Die uebrigen Compositoren

**Hier steht nichts Gemessenes, und darum steht hier auch keine Anleitung.**
Die niri-Regel oben ist auf diesem Rechner nachgeprueft; fuer Hyprland, KWin
und die anderen waere alles Weitere aus dem Gedaechtnis geschrieben, und ein
Rezept, das nicht stimmt, kostet mehr Zeit als keines. Was sich allgemein
sagen laesst:

- **wlroots-nahe Compositoren** (Hyprland, Wayfire, river) bringen einen
  Weichzeichner mit; er wird global eingeschaltet und dann fensterweise
  ausgenommen, nicht umgekehrt. Der Anhaltspunkt ist die `app_id` oben.
- **KWin** hat den Effekt "Weichzeichnen", greift aber nur dort, wo eine
  Anwendung ihn selbst anfordert (`org_kde_kwin_blur`). OrangeDeck tut das
  nicht -- ob es also ohne Weiteres wirkt, ist offen.
- **Mutter (GNOME)** zeichnet nicht weich, und es gibt keine unterstuetzte
  Stellschraube dafuer. Dort bleibt die Deckkraft besser auf 1; die Ansicht
  ist darauf ausgelegt und verliert nichts.

Wer eine Regel fuer einen dieser Compositoren **nachgeprueft** hat, darf sie
hier eintragen.
