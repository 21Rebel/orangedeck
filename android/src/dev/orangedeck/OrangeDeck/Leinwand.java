package dev.orangedeck.OrangeDeck;

import android.graphics.Bitmap;
import android.graphics.Canvas;

/**
 * Eine Bitmap im Seitenverhaeltnis der Flaeche, auf der die Kachel sie zeigt.
 *
 * <p><b>Warum das noetig ist.</b> Bis zum 10.09.2026 hatten Graph und
 * Blockkarten eine feste Groesse (640x220 bzw. 700x360), und das
 * {@code ImageView} in {@code widget_graph} zog sie mit {@code fitXY} auf die
 * Kachel. In einer 4x2-Kachel ist die Bildflaeche unter den drei Textzeilen
 * aber rund viermal so breit wie hoch: alles darin wurde auf etwa die Haelfte
 * gestaucht, die Schrift eingeschlossen. Zwei Anlaeufe an den Zeilenabstaenden
 * haben daran nichts geaendert, und eine hoehere Kachel hat das Bild in die
 * andere Richtung verzogen -- beides folgt aus der Streckung, nicht aus den
 * Abstaenden.
 *
 * <p><b>Gezeichnet wird weiter auf eine feste logische Breite.</b> Die Hoehe
 * folgt dem wirklichen Seitenverhaeltnis, und die Bitmap bekommt die
 * Geraetepixel der Flaeche. Waagerecht sieht damit alles aus wie vorher, und
 * {@code fitXY} streckt nur noch um den Fehler der Hoehenschaetzung.
 *
 * <p><b>Ein Pixelbudget statt einer festen Groesse</b>, weil die Bitmap ueber
 * Binder geht: 250.000 Pixel sind in RGB_565 rund 500 kB, so viel wie die
 * alte 700x360. Eine groessere Flaeche wird mit weniger Aufloesung gezeichnet,
 * aber im selben Seitenverhaeltnis.
 */
final class Leinwand {

    private static final float PIXELBUDGET = 250_000f;

    final Bitmap bild;
    final Canvas c;
    /** Logische Breite: immer die, mit der die Aufrufer rechnen. */
    final float breite;
    /** Logische Hoehe: folgt dem Seitenverhaeltnis der Flaeche. */
    final float hoehe;

    /**
     * @param breite        logische Breite
     * @param hoeheVorgabe  logische Hoehe, wenn der Starter keine Groesse meldet
     * @param px            Breite und Hoehe der Flaeche in Geraetepixeln, oder
     *                      {@code null}; dann gilt die alte feste Groesse
     */
    Leinwand(int breite, int hoeheVorgabe, int[] px, int grund) {
        float pb = breite, ph = hoeheVorgabe;
        if (px != null && px[0] > 0 && px[1] > 0) {
            pb = px[0];
            ph = px[1];
        }
        float s = Math.min(1f, (float) Math.sqrt(PIXELBUDGET / (pb * ph)));
        int bb = Math.max(1, Math.round(pb * s));
        int bh = Math.max(1, Math.round(ph * s));

        this.breite = breite;
        this.hoehe = (float) breite * bh / bb;
        bild = Bitmap.createBitmap(bb, bh, Bitmap.Config.RGB_565);
        c = new Canvas(bild);
        c.drawColor(grund);
        float m = (float) bb / breite;
        c.scale(m, m);
    }
}
