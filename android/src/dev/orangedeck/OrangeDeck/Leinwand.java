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
 * <p><b>ARGB_8888 mit durchsichtigem Grund, nicht RGB_565.</b> Bis zum
 * 10.09.2026 war die Bitmap RGB_565, um sie klein zu halten. Das hatte zwei
 * sichtbare Folgen, am Geraet nachgemessen: ohne Alphakanal musste das Bild
 * einen eigenen Grund malen, flach (24, 20, 32), waehrend der Verlauf der
 * Kachel darunter schon bei (14, 12, 20) stand -- die Kante war zu sehen.
 * Und mit fuenf Bit Rot sprang der orange Verlauf unter der Kurve in Stufen
 * von acht (101, 94, 86, 78 ...): Streifen. Jetzt scheint der Verlauf der
 * Kachel durch, und Verlaeufe haben 256 Stufen.
 *
 * <p><b>Ein Pixelbudget statt einer festen Groesse.</b> Die Flaeche einer
 * 4x2 sind am Geraet rund 1050x315 Pixel, in ARGB_8888 1,3 MB. Binder legt
 * eine Bitmap dieser Groesse in geteilten Speicher, statt sie in die 1-MB-
 * Transaktion zu kopieren; gemessen am 10.09.2026 ohne
 * TransactionTooLargeException. Das Budget begrenzt nur den Speicher im
 * Starter: eine groessere Flaeche wird mit weniger Aufloesung gezeichnet,
 * im selben Seitenverhaeltnis.
 */
final class Leinwand {

    private static final float PIXELBUDGET = 500_000f;

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
    Leinwand(int breite, int hoeheVorgabe, int[] px) {
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
        // Eine neue Bitmap ist ganz durchsichtig; der Grund kommt von der Kachel.
        bild = Bitmap.createBitmap(bb, bh, Bitmap.Config.ARGB_8888);
        c = new Canvas(bild);
        float m = (float) bb / breite;
        c.scale(m, m);
    }
}
