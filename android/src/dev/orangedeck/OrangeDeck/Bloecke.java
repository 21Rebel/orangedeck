package dev.orangedeck.OrangeDeck;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;

/**
 * Zeichnet die Blockkarten des Explorers als ein Bild.
 *
 * <p><b>Warum ein Bild und nicht vier Layouts.</b> Die Karten haben runde
 * Ecken, einen Farbverlauf und einen schraegen Glanz. {@code
 * setBackgroundColor} ueber RemoteViews naehme die Rundung mit, und
 * {@code setBackgroundTintList} gibt es erst ab API 31, waehrend
 * {@code minSdk} 28 ist. Als Bild stimmt alles genau, und es ist derselbe Weg
 * wie beim Graphen.
 *
 * <p><b>Die Glasoptik ist aus {@code ui/qml/BlockCard.qml} uebernommen</b>,
 * Stufe fuer Stufe: Verlauf von {@code heller(1,18)} ueber den Grundton bei
 * 55 % nach {@code dunkler(1,4)}, darueber ein um sieben Grad gekippter
 * weisser Glanz ueber die obere Haelfte (0,22 nach 0, halbe Deckkraft), ein
 * Rand in {@code rgba(1,1,1,0.16)} und eine hellere Oberkante.
 *
 * <p><b>Zwischen den Karten scheint die Kachel durch.</b> Das Bild malt
 * keinen eigenen Grund mehr, siehe {@link Leinwand}. Die Verlaeufe sind
 * gedithert, damit auch die dunklen Karten ohne Baender auskommen.
 */
final class Bloecke {

    private Bloecke() { }

    static final int BREITE = 700;
    static final int HOEHE = 360;

    /** Wie {@code Qt.lighter}: der Helligkeitswert wird vervielfacht. */
    static int heller(int farbe, float f) {
        float[] hsv = new float[3];
        Color.colorToHSV(farbe, hsv);
        hsv[2] = Math.min(1f, hsv[2] * f);
        return Color.HSVToColor(hsv);
    }

    /** Wie {@code Qt.darker}: der Helligkeitswert wird geteilt. */
    static int dunkler(int farbe, float f) {
        float[] hsv = new float[3];
        Color.colorToHSV(farbe, hsv);
        hsv[2] = hsv[2] / f;
        return Color.HSVToColor(hsv);
    }

    /** `#2f9e63` als Farbton; Saettigung und Helligkeit wie `feeShade()`. */
    static int gebuehrenTon(double medianFee) {
        float[] hsv = new float[3];
        Color.colorToHSV(0xff2f9e63, hsv);
        float f = (float) Math.max(0, Math.min(1, medianFee / 12.0));
        return Color.HSVToColor(new float[] { hsv[0], 0.45f + 0.3f * f, 0.34f + 0.30f * f });
    }

    static final int GEFUNDEN = 0xff7b5cd6;

    /**
     * @param kopf   Ueberschrift ueber jeder Karte (Zeit oder Blockhoehe)
     * @param zeilen je Karte die Textzeilen; die erste steht gross
     * @param toene  Grundfarbe je Karte
     */
    static Bitmap zeichne(String[] kopf, String[][] zeilen, int[] toene, int[] px) {
        Leinwand l = new Leinwand(BREITE, HOEHE, px);
        Canvas c = l.c;

        int n = Math.min(kopf.length, Math.min(zeilen.length, toene.length));
        if (n == 0)
            return l.bild;

        float luecke = 9, trenner = 16, radius = 12;
        float breite = (BREITE - luecke * (n - 1) - trenner) / n;
        float kopfH = 24, oben = kopfH + 7, unten = l.hoehe - 4;
        int mitte = n / 2;

        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.DITHER_FLAG);
        Paint t = new Paint(Paint.ANTI_ALIAS_FLAG);
        t.setTextAlign(Paint.Align.CENTER);

        t.setTextSize(GROSS);
        Paint.FontMetrics fmG = t.getFontMetrics();
        t.setTextSize(KLEIN);
        Paint.FontMetrics fmK = t.getFontMetrics();
        float hG = fmG.descent - fmG.ascent, hK = fmK.descent - fmK.ascent;


        for (int i = 0; i < n; i++) {
            float x = i * (breite + luecke) + (i >= mitte ? trenner : 0);
            RectF r = new RectF(x, oben, x + breite, unten);

            // **Die Mittellinie sitzt in der Mitte der Luecke, nicht am Rand
            // der Karte.** Zwischen den beiden Haelften liegen `luecke` plus
            // `trenner`; der erste Anlauf zog nur `trenner/2` ab und stand
            // damit um eine halbe Luecke zu weit rechts.
            if (i == mitte) {
                p.setShader(null);
                p.setColor(0x33ffffff);
                float mx = x - (luecke + trenner) / 2f;
                c.drawRect(mx - 1, oben + 6, mx + 1, unten - 6, p);
            }

            if (kopf[i] != null) {
                t.setShader(null);
                t.setColor(0xff9a94a6);
                t.setTextSize(19f);
                t.setFakeBoldText(false);
                c.drawText(kopf[i], x + breite / 2, kopfH, t);
            }

            // Flaeche: Verlauf hell nach dunkel, wie `face` in BlockCard.
            p.setShader(new LinearGradient(0, oben, 0, unten,
                    new int[] { heller(toene[i], 1.18f), toene[i], dunkler(toene[i], 1.4f) },
                    new float[] { 0f, 0.55f, 1f }, Shader.TileMode.CLAMP));
            c.drawRoundRect(r, radius, radius, p);
            p.setShader(null);

            // Glanz: schraeger heller Streifen ueber die obere Haelfte,
            // beschnitten auf die runde Form.
            c.save();
            Path form = new Path();
            form.addRoundRect(r, radius, radius, Path.Direction.CW);
            c.clipPath(form);
            c.rotate(-7, x + breite / 2, oben + (unten - oben) * 0.31f);
            Paint g = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.DITHER_FLAG);
            float gh = (unten - oben) * 0.62f;
            g.setShader(new LinearGradient(0, oben - gh * 0.1f, 0, oben + gh,
                    0x38ffffff, 0x00ffffff, Shader.TileMode.CLAMP));
            c.drawRect(x - breite * 0.3f, oben - gh * 0.1f,
                       x + breite * 1.3f, oben + gh, g);
            c.restore();

            // Kanten: umlaufend zart, oben eine Spur heller.
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(1.5f);
            p.setColor(0x29ffffff);
            c.drawRoundRect(r, radius, radius, p);
            p.setStyle(Paint.Style.FILL);
            p.setColor(0x4dffffff);
            c.drawRect(x + radius, oben + 1, x + breite - radius, oben + 2.5f, p);

            // **Die Zeilen mittig.** Was nicht in die Karte passt, faellt von
            // unten weg: Pool und Zeit vor Gebuehr und Transaktionen.
            String[] z = belegt(zeilen[i]);
            int anz = z.length;
            while (anz > 1 && bedarf(anz, hG, hK) > unten - oben - 2 * RAND)
                anz--;
            if (anz == 0)
                continue;

            float y = oben + ((unten - oben) - bedarf(anz, hG, hK)) / 2f;
            for (int k = 0; k < anz; k++) {
                boolean gross = k == 0;
                t.setTextSize(gross ? GROSS : KLEIN);
                t.setFakeBoldText(gross);
                t.setColor(gross ? 0xffffffff : 0xe0ffffff);
                // **Nur die Zeile, die seitlich uebersteht, wird kleiner** --
                // ein langer Poolname soll nicht alle vier Karten verkleinern.
                float w = t.measureText(z[k]);
                if (w > breite - 2 * RAND)
                    t.setTextSize(t.getTextSize() * (breite - 2 * RAND) / w);
                c.drawText(z[k], x + breite / 2, y - (gross ? fmG : fmK).ascent, t);
                y += (gross ? hG : hK) + LUFT;
            }
            t.setFakeBoldText(false);
        }
        return l.bild;
    }

    /**
     * Schrift und Luft wie in {@code BlockChain.qml}: die erste Zeile in
     * voller Groesse, die uebrigen 0,72 davon, dazwischen 0,18 der vollen
     * Groesse Luft.
     *
     * <p>Die Faktoren 1,45 und 1,55 auf die Zeilenhoehe, die hier bis zum
     * 10.09.2026 standen, gleichen nichts in der Anwendung nach. Sie waren der
     * zweite Anlauf gegen die gedrueckte Schrift, deren Ursache die Streckung
     * des Bildes war (siehe {@link Leinwand}).
     */
    private static final float GROSS = 25f, KLEIN = 18f, LUFT = 0.18f * GROSS;

    /** Abstand der Zeilen zum Kartenrand, oben, unten und seitlich. */
    private static final float RAND = 6f;

    /**
     * **Fuer die Hoehe wird die Schrift nicht kleiner, es fallen Zeilen weg.**
     * In einer 4x2-Kachel ist die kleine Zeile in voller Groesse rund 8,5 dp
     * hoch; schon drei Viertel davon waeren auf dem Startbildschirm kaum zu
     * lesen, und fuenf Zeilen, die man nicht lesen kann, sagen weniger als
     * vier, die man lesen kann.
     */
    private static float bedarf(int m, float hG, float hK) {
        if (m <= 0)
            return 0;
        return hG + (m - 1) * (hK + LUFT);
    }

    /** Die Zeilen einer Karte ohne die leeren. */
    private static String[] belegt(String[] z) {
        int m = 0;
        for (String x : z)
            if (x != null && !x.isEmpty())
                m++;
        String[] r = new String[m];
        m = 0;
        for (String x : z)
            if (x != null && !x.isEmpty())
                r[m++] = x;
        return r;
    }
}
