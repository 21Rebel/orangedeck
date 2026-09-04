"""Echte Maus- und Tastenereignisse in einen X-Server einspeisen.

**Zum Pruefen, nicht zum Ausliefern.** Ein Standbild zeigt Geometrie, kein
Verhalten -- alles was an einem Zeiger haengt (Ziehen, Rad, Halten) braucht
einen Zeiger. Gedacht fuer den Xvfb, in dem ohnehin abgebildet wird, nicht
fuer die Sitzung des Nutzers.

    xvfb-run -a --server-args="-screen 0 1400x900x24" bash -c \
        'env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb ./build/orangedeck-app & \
         sleep 10; python3 tools/xtest.py 695 700; import -window root /tmp/b.png'

Braucht `python-xlib` und `libXtst`.
"""
from Xlib import display, X
from Xlib.ext import xtest

d = display.Display()
wurzel = d.screen().root

def fenster_suchen(tiefe=0, w=None):
    w = w or wurzel
    for k in w.query_tree().children:
        geo = k.get_geometry()
        attr = k.get_attributes()
        if attr.map_state == X.IsViewable and geo.width > 200 and geo.height > 200:
            return k
        gefunden = fenster_suchen(tiefe + 1, k)
        if gefunden:
            return gefunden
    return None

def groesse(w, breite, hoehe):
    w.configure(width=breite, height=hoehe, x=0, y=0)
    d.sync()

def maus_nach(x, y):
    xtest.fake_input(d, X.MotionNotify, x=x, y=y)
    d.sync()

def klick(x=None, y=None, taste=1):
    if x is not None:
        maus_nach(x, y)
        time.sleep(0.1)
    xtest.fake_input(d, X.ButtonPress, taste)
    d.sync()
    time.sleep(0.05)
    xtest.fake_input(d, X.ButtonRelease, taste)
    d.sync()

def rad(hoch=True, mal=1):
    taste = 4 if hoch else 5
    for _ in range(mal):
        xtest.fake_input(d, X.ButtonPress, taste); d.sync()
        xtest.fake_input(d, X.ButtonRelease, taste); d.sync()
        time.sleep(0.05)

def ziehen(x0, y0, x1, y1, schritte=25):
    maus_nach(x0, y0); time.sleep(0.15)
    xtest.fake_input(d, X.ButtonPress, 1); d.sync(); time.sleep(0.1)
    for i in range(1, schritte + 1):
        maus_nach(int(x0 + (x1-x0)*i/schritte), int(y0 + (y1-y0)*i/schritte))
        time.sleep(0.03)
    time.sleep(0.15)
    xtest.fake_input(d, X.ButtonRelease, 1); d.sync()

if __name__ == "__main__":
    f = fenster_suchen()
    if not f:
        print("kein Fenster gefunden"); sys.exit(1)
    g = f.get_geometry()
    print("Fenster gefunden: %dx%d" % (g.width, g.height))
    if len(sys.argv) > 2:
        groesse(f, int(sys.argv[1]), int(sys.argv[2]))
        time.sleep(1.0)
        g = f.get_geometry()
        print("auf %dx%d gesetzt" % (g.width, g.height))
