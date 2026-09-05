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

## Wonach zu suchen ist -- es gibt das Fenster zweimal

Je nachdem, wie OrangeDeck laeuft, traegt die Wayland-Flaeche eine andere
Kennung:

| So gestartet | `app_id` | Titel |
|---|---|---|
| eigenstaendig (`orangedeck-app`) | `dev.orangedeck.OrangeDeck` | `OrangeDeck` |
| im quickshell-Fenster | `org.quickshell` | `OrangeDeck` |

Die eigenstaendige Anwendung hat eine eigene Kennung; sie kommt aus
`QGuiApplication::setDesktopFileName()` (siehe `app/src/main.cpp`) und ist
dieselbe wie im Flatpak und in der `.desktop`-Datei. Danach laesst sich
sauber suchen.

**Das quickshell-Fenster nicht.** Alles, was quickshell zeigt, traegt
`org.quickshell` -- eine Regel darauf allein erwischt jedes andere
quickshell-Fenster mit. Hier bleibt nur der Titel, eingegrenzt durch die
app-id daneben.

Und damit die Warnung, die dazugehoert: **ein Titel ist Anzeigetext.** Er
aendert sich, wenn die Anwendung umbenannt wird, und die Regel greift danach
stillschweigend ins Leere -- kein Fehler, keine Meldung, nur kein Blur mehr.
Am 05.09.2026 genau so passiert: die Regel suchte noch `^Bitcoin Feed$`.
Wo der Titel unvermeidlich ist, gehoert er beim Umbenennen mit auf die
Liste.

## niri

In `~/.config/niri/config.kdl`:

    window-rule {
        match app-id=r#"^dev\.orangedeck\.OrangeDeck$"#
        match app-id=r#"^org\.quickshell$"# title=r#"^OrangeDeck$"#
        background-effect {
            blur true
            xray false
        }
    }

Zwei `match`-Zeilen sind ein Oder, zwei Angaben in **einer** Zeile ein Und --
die zweite trifft also nur das quickshell-Fenster, das OrangeDeck heisst,
und nicht jedes andere.

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
