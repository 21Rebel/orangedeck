package dev.orangedeck.OrangeDeck;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;

/**
 * Zeichnet eine Zahlenreihe als Kurve auf eine Bitmap.
 *
 * <p><b>Das ist der Weg, auf dem ein Widget zu einem Graphen kommt.</b>
 * RemoteViews kennt kein Canvas-Bauteil, aber ein {@code ImageView}, und
 * {@code setImageViewBitmap} nimmt ein fertiges Bild entgegen. Gezeichnet
 * wird hier also mit denselben Mitteln wie in der Anwendung, nur in Java
 * statt in QML.
 *
 * <p><b>RGB_565, nicht ARGB_8888.</b> Die Bitmap geht ueber Binder zum
 * Starter, und dafuer gilt eine Groessengrenze. 640x220 kosten in ARGB_8888
 * rund 563 kB, in RGB_565 die Haelfte. Durchsichtigkeit braucht das Bild
 * nicht: der Grund der Kachel ist ohnehin deckend, und die Farbe steht hier
 * mit drin.
 *
 * <p>Die Kurve bekommt einen Verlauf darunter, wie der Kursgraph der
 * Anwendung. Keine Achsen, keine Beschriftung: bei dieser Groesse waere
 * beides unlesbar, und die Zahlen stehen daneben.
 */
final class Graph {

    private Graph() { }

    static final int BREITE = 640;
    static final int HOEHE = 220;

    /** Grau der Beschriftung, wie in der Anwendung. */
    private static final int GRAU = 0xff9a94a6;
    /** Die Hilfslinien: kaum sichtbar, wie `gridColor` in MinerChart.qml. */
    private static final int LINIE = 0xff2b2735;

    /**
     * @param obenText   Beschriftung der oberen Hilfslinie (Hoechstwert)
     * @param untenText  Beschriftung der unteren Hilfslinie (Tiefstwert)
     * @param vonText    Datum links unten
     * @param bisText    Datum rechts unten
     * @param px         Bildflaeche in Geraetepixeln, siehe {@link Leinwand}
     */
    static Bitmap zeichne(double[] w, int linienFarbe, int grundFarbe,
                          String obenText, String untenText,
                          String vonText, String bisText, int[] px) {
        Leinwand l = new Leinwand(BREITE, HOEHE, px, grundFarbe);
        Canvas c = l.c;
        float bildH = l.hoehe;
        if (w == null || w.length < 2)
            return l.bild;

        double lo = w[0], hi = w[0];
        for (double v : w) {
            lo = Math.min(lo, v);
            hi = Math.max(hi, v);
        }
        double spanne = Math.max(hi - lo, Math.abs(hi) * 0.02);
        if (spanne <= 0)
            spanne = 1;

        Paint schrift = new Paint(Paint.ANTI_ALIAS_FLAG);
        schrift.setColor(GRAU);
        schrift.setTextSize(20f);

        // **Der Platz links richtet sich nach der Beschriftung.** In der
        // Anwendung stehen die beiden Preise am linken Rand; ohne Rueckstand
        // liefe die Kurve darueber.
        float randL = 6;
        if (obenText != null || untenText != null) {
            float br = 0;
            if (obenText != null)
                br = Math.max(br, schrift.measureText(obenText));
            if (untenText != null)
                br = Math.max(br, schrift.measureText(untenText));
            randL = br + 14;
        }
        float randR = 6, randO = 16;
        float randU = (vonText != null || bisText != null) ? 30 : 12;
        float breite = BREITE - randL - randR, hoehe = bildH - randO - randU;

        // Hilfslinien oben und unten, wie im Kursgraphen der Anwendung. Die
        // Kurve beruehrt sie: sie markieren Hoechst- und Tiefstwert, nicht
        // ein gerundetes Raster.
        Paint hl = new Paint();
        hl.setColor(LINIE);
        hl.setStrokeWidth(1.5f);
        c.drawLine(randL, randO, BREITE - randR, randO, hl);
        c.drawLine(randL, randO + hoehe, BREITE - randR, randO + hoehe, hl);

        if (obenText != null)
            c.drawText(obenText, 4, randO + 7, schrift);
        if (untenText != null)
            c.drawText(untenText, 4, randO + hoehe + 7, schrift);
        if (vonText != null)
            c.drawText(vonText, randL, bildH - 8, schrift);
        if (bisText != null) {
            schrift.setTextAlign(Paint.Align.RIGHT);
            c.drawText(bisText, BREITE - randR, bildH - 8, schrift);
            schrift.setTextAlign(Paint.Align.LEFT);
        }

        Path linie = new Path();
        for (int i = 0; i < w.length; i++) {
            float x = randL + breite * i / (w.length - 1);
            float y = randO + hoehe - (float) ((w[i] - lo) / spanne * hoehe);
            if (i == 0)
                linie.moveTo(x, y);
            else
                linie.lineTo(x, y);
        }

        Path flaeche = new Path(linie);
        flaeche.lineTo(randL + breite, randO + hoehe);
        flaeche.lineTo(randL, randO + hoehe);
        flaeche.close();

        Paint f = new Paint(Paint.ANTI_ALIAS_FLAG);
        // Der Verlauf mischt gegen den Grund, nicht gegen Durchsichtigkeit:
        // RGB_565 kennt kein Alpha.
        f.setShader(new LinearGradient(0, randO, 0, randO + hoehe,
                mischen(linienFarbe, grundFarbe, 0.45f), grundFarbe,
                Shader.TileMode.CLAMP));
        c.drawPath(flaeche, f);

        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(3f);
        p.setColor(linienFarbe);
        c.drawPath(linie, p);
        return l.bild;
    }

    /** Ein Hinweis statt einer Kurve, solange zu wenige Punkte da sind. */
    static Bitmap hinweis(String text, int grundFarbe, int[] px) {
        Leinwand l = new Leinwand(BREITE, HOEHE, px, grundFarbe);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setColor(0xff9a94a6);
        p.setTextSize(26f);
        p.setTextAlign(Paint.Align.CENTER);
        l.c.drawText(text, BREITE / 2f, l.hoehe / 2f + 9f, p);
        return l.bild;
    }

    /** Zwei Farben mischen, weil RGB_565 kein Alpha kann. */
    private static int mischen(int a, int b, float anteil) {
        int ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
        int br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
        int r = Math.round(ar * anteil + br * (1 - anteil));
        int g = Math.round(ag * anteil + bg * (1 - anteil));
        int bl = Math.round(ab * anteil + bb * (1 - anteil));
        return 0xff000000 | (r << 16) | (g << 8) | bl;
    }
}
