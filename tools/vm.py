"""Eine QEMU-VM ohne Fenster steuern: Tasten senden und Bilder holen.

**Wofuer.** Um die Anwendung auf einem System laufen zu lassen, das nichts
von diesem Projekt weiss -- am 04.09.2026 ein frisches Ubuntu 24.04. Was nur
eine Umgebung angefasst hat, ist ungeprueft; drei der schwersten Funde des
Tages waren auf dem Entwicklungsrechner strukturell unsichtbar.

**Nicht zu verwechseln mit `xtest.py`.** Das arbeitet auf einem X-Server, den
man erreichen kann. Hier gibt es keinen: die VM laeuft mit `-display none`,
und der einzige Draht hinein ist der QEMU-Monitor auf einem Unix-Sockel.

    qemu-system-x86_64 -enable-kvm -m 3072 -smp 2 -cpu host \
        -drive file=ubuntu-24.04.4.iso,media=cdrom,readonly=on \
        -vga std -display none \
        -monitor unix:/pfad/mon.sock,server,nowait \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -boot d

Der Rest -- RAM-Overlay der Live-Sitzung, AppArmor, Medientausch -- steht in
`docs/DOKUMENTATION.md` unter "Pruefen in einer Live-Sitzung" und "Was die
Pruef-VM gefunden hat".
"""
import socket, time, subprocess, os
SOCK = "/tmp/claude-1000/-home-satoshoe/0ac3647d-cd2e-4635-884c-99697b0c2858/scratchpad/mon.sock"
SC = "/tmp/claude-1000/-home-satoshoe/0ac3647d-cd2e-4635-884c-99697b0c2858/scratchpad"

def _mon(befehl, warte=0.25):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    time.sleep(0.2)
    try:
        s.recv(65536)
    except Exception:
        pass
    s.sendall((befehl + "\n").encode())
    time.sleep(warte)
    aus = b""
    s.setblocking(False)
    try:
        aus = s.recv(65536)
    except Exception:
        pass
    s.close()
    return aus.decode("utf-8", "replace")

# QEMU kennt eigene Tastennamen. **Was hier fehlt, wird stillschweigend
# verschluckt** -- aus `lsblk -o NAME,LABEL,SIZE` wurde `NAMELABELSIZE`, und
# lsblk meldete eine unbekannte Spalte. Der Fehler sieht dann nach einem
# Problem im Gast aus und liegt in der Fernbedienung. Deshalb die Zusicherung
# am Ende der Datei: lieber ein lauter Abbruch als ein leiser Ausfall.
SONDER = {" ": "spc", "-": "minus", ".": "dot", "/": "slash", ":": "shift-semicolon",
          ",": "comma", "&": "shift-7", "|": "shift-backslash", "$": "shift-4",
          "(": "shift-9", ")": "shift-0", "'": "apostrophe", '"': "shift-apostrophe",
          "_": "shift-minus", "~": "shift-grave_accent", "*": "shift-8",
          "=": "equal", ";": "semicolon", "!": "shift-1",
          "?": "shift-slash", "<": "shift-comma", ">": "shift-dot",
          "#": "shift-3", "%": "shift-5", "@": "shift-2", "^": "shift-6",
          "[": "bracket_left", "]": "bracket_right", "\\": "backslash",
          "{": "shift-bracket_left", "}": "shift-bracket_right", "`": "grave_accent", "+": "shift-equal", "\n": "ret", "\t": "tab"}

def taste(name, warte=0.06):
    _mon("sendkey %s" % name, warte)

def tippe(text, warte=0.06):
    for z in text:
        if z in SONDER:
            taste(SONDER[z], warte)
        elif z.isupper():
            taste("shift-%s" % z.lower(), warte)
        else:
            taste(z, warte)

def zeile(text):
    """Eine Befehlszeile tippen und abschicken."""
    tippe(text)
    taste("ret")

def bild(name):
    p = "%s/vm_%s.ppm" % (SC, name)
    _mon("screendump %s" % p, 1.5)
    png = "%s/vm_%s.png" % (SC, name)
    subprocess.run(["magick", p, png], stderr=subprocess.DEVNULL)
    os.path.exists(p) and os.remove(p)
    return png


def _sauber(roh):
    """Die Monitor-Antwort vom Echo befreien.

    QEMU spiegelt jedes gesendete Zeichen einzeln zurueck, mit Steuerzeichen
    dazwischen. Was uebrig bleibt, ist die eigentliche Antwort.
    """
    import re
    t = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", roh)
    return [z for z in t.splitlines() if z.strip() and not z.startswith("(qemu)")]


def laufwerke():
    """Was gerade in welchem Laufwerk liegt."""
    return [z.strip() for z in _sauber(_mon("info block", 1.5)) if "/" in z]


def medium_wechseln(geraet, pfad):
    """Datentraeger tauschen.

    **Der Gast muss ihn vorher aushaengen.** Sonst scheitert es mit
    *Device is locked*. Und danach neu einhaengen, nicht nur `ls`: der Kernel
    liefert sonst weiter den alten Inhalt aus dem Cache -- der Dateiname war
    schon der neue, die Daten waren noch die alten.
    """
    _mon("eject -f %s" % geraet, 1.5)
    return _mon("change %s %s" % (geraet, pfad), 2.5)


# Ein fehlendes Zeichen faellt sonst erst auf, wenn der Gast Unsinn meldet.
_FEHLT = [z for z in "!\"#$%&()*+,-./:;<=>?@[]^_`{|}~ " if z not in SONDER]
assert not _FEHLT, "keine Taste hinterlegt fuer: %r" % _FEHLT
