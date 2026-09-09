package dev.orangedeck.OrangeDeck;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;

/**
 * Zeichnet die Blockkarten des Explorers als ein Bild.
 *
 * <p><b>Warum ein Bild und nicht vier Layouts.</b> Die Karten haben runde
 * Ecken und eine Farbe, die sich nach der Mediangebuehr richtet.
 * {@code setBackgroundColor} ueber RemoteViews wuerde die Rundung
 * mitnehmen, und {@code setBackgroundTintList} gibt es erst ab API 31,
 * waehrend {@code minSdk} 28 ist. Als Bild stimmen Rundung, Farbe und
 * Abstaende genau, und es ist derselbe Weg wie beim Graphen.
 *
 * <p>Die Farben stammen aus {@code ui/qml/BlockChain.qml}: geplante Bloecke
 * gruen ({@code pendingColor #2f9e63}), nach Mediangebuehr aufgehellt,
 * gefundene violett ({@code minedColor #7b5cd6}).
 */
final class Bloecke {

    private Bloecke() { }

    static final int BREITE = 700;
    static final int HOEHE = 330;

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
     * @param zeilen je Karte bis zu sechs Zeilen; die erste steht gross
     * @param toene  Farbe je Karte
     */
    static Bitmap zeichne(String[] kopf, String[][] zeilen, int[] toene, int grundFarbe) {
        Bitmap b = Bitmap.createBitmap(BREITE, HOEHE, Bitmap.Config.RGB_565);
        Canvas c = new Canvas(b);
        c.drawColor(grundFarbe);

        int n = Math.min(kopf.length, Math.min(zeilen.length, toene.length));
        if (n == 0)
            return b;

        // Die Trennlinie zwischen Geplantem und Gefundenem, wie im Explorer.
        float luecke = 10, trenner = 14;
        float breite = (BREITE - luecke * (n - 1) - trenner) / n;
        float kopfH = 26, oben = kopfH + 6;

        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        Paint t = new Paint(Paint.ANTI_ALIAS_FLAG);
        t.setTextAlign(Paint.Align.CENTER);

        for (int i = 0; i < n; i++) {
            // Nach der zweiten Karte kommt die Trennlinie: links das
            // Geplante, rechts das Gefundene.
            float x = i * (breite + luecke) + (i >= n / 2 ? trenner : 0);

            if (i == n / 2) {
                p.setColor(0xff3a3545);
                c.drawRect(x - trenner / 2 - 1, oben, x - trenner / 2 + 1, HOEHE - 4, p);
            }

            if (kopf[i] != null) {
                t.setColor(0xff9a94a6);
                t.setTextSize(19f);
                c.drawText(kopf[i], x + breite / 2, kopfH - 4, t);
            }

            p.setColor(toene[i]);
            c.drawRoundRect(new RectF(x, oben, x + breite, HOEHE - 4), 12, 12, p);

            String[] z = zeilen[i];
            float y = oben + 32;
            for (int k = 0; k < z.length && z[k] != null; k++) {
                if (k == 0) {
                    t.setColor(0xffffffff);
                    t.setTextSize(23f);
                    t.setFakeBoldText(true);
                } else {
                    t.setColor(0xd8ffffff);
                    t.setTextSize(17f);
                    t.setFakeBoldText(false);
                }
                c.drawText(z[k], x + breite / 2, y, t);
                y += (k == 0) ? 30 : 24;
            }
            t.setFakeBoldText(false);
        }
        return b;
    }
}
