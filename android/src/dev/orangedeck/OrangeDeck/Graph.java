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

    static Bitmap zeichne(double[] w, int linienFarbe, int grundFarbe) {
        Bitmap b = Bitmap.createBitmap(BREITE, HOEHE, Bitmap.Config.RGB_565);
        Canvas c = new Canvas(b);
        c.drawColor(grundFarbe);
        if (w == null || w.length < 2)
            return b;

        double lo = w[0], hi = w[0];
        for (double v : w) {
            lo = Math.min(lo, v);
            hi = Math.max(hi, v);
        }
        // Etwas Luft, damit die Kurve nicht am Rand klebt. Dieselbe
        // Ueberlegung wie in `MinerChart.qml`: eine flache Reihe soll nicht
        // zu einer Zickzacklinie aufgeblasen werden.
        double spanne = Math.max(hi - lo, Math.abs(hi) * 0.02);
        if (spanne <= 0)
            spanne = 1;
        lo -= spanne * 0.15;
        hi += spanne * 0.15;

        float randL = 6, randR = 6, randO = 10, randU = 10;
        float breite = BREITE - randL - randR, hoehe = HOEHE - randO - randU;

        Path linie = new Path();
        for (int i = 0; i < w.length; i++) {
            float x = randL + breite * i / (w.length - 1);
            float y = randO + hoehe - (float) ((w[i] - lo) / (hi - lo) * hoehe);
            if (i == 0)
                linie.moveTo(x, y);
            else
                linie.lineTo(x, y);
        }

        // Die Flaeche darunter: derselbe Ton, nach unten auslaufend.
        Path flaeche = new Path(linie);
        flaeche.lineTo(randL + breite, HOEHE);
        flaeche.lineTo(randL, HOEHE);
        flaeche.close();

        Paint f = new Paint(Paint.ANTI_ALIAS_FLAG);
        // Der Verlauf mischt gegen den Grund, nicht gegen Durchsichtigkeit:
        // RGB_565 kennt kein Alpha.
        f.setShader(new LinearGradient(0, randO, 0, HOEHE,
                mischen(linienFarbe, grundFarbe, 0.45f), grundFarbe,
                Shader.TileMode.CLAMP));
        c.drawPath(flaeche, f);

        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(3f);
        p.setColor(linienFarbe);
        c.drawPath(linie, p);
        return b;
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
