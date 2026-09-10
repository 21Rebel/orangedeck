package dev.orangedeck.OrangeDeck;

import android.content.Context;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.widget.RemoteViews;

/**
 * Gemeinsamer Unterbau der ausfuehrlichen Kacheln: Ueberschrift, Hauptwert,
 * eine Nebenzeile, darunter der Graph.
 *
 * <p>Die Unterklassen liefern die drei Texte wie gehabt ueber {@link #werte}
 * und dazu die Zahlenreihe ueber {@link #reihe}. Wo die Reihe herkommt, ist
 * ihre Sache: der Kurs holt sie einmalig und schreibt sie fort, der Miner
 * fuehrt sie von Anfang an selbst.
 */
public abstract class GraphWidget extends DeckWidget {

    /** Grund der Kachel; muss zu `widget_grund.xml` passen. */
    protected static final int GRUND = 0xff16131f;
    protected static final int ORANGE = 0xfff7931a;

    @Override protected int layoutId() { return R.layout.widget_graph; }

    /** Farbe der Kurve. Vorgabe ist das Orange der Anwendung. */
    protected int linienFarbe() { return ORANGE; }

    /** Wie viele Punkte der Verlauf fasst. */
    protected int punkte() { return 180; }

    /** Einheit hinter den Werten der Hilfslinien, z. B. " €". */
    protected String einheit() { return ""; }

    /** Nachkommastellen der Hilfslinien-Beschriftung. */
    protected int stellen() { return 0; }

    @Override
    protected void fuelle(Context c, RemoteViews v, String[] z, Bundle optionen) {
        v.setTextViewText(R.id.widget_titel, titel(c));
        v.setTextViewText(R.id.widget_gross, z.length > 0 && z[0] != null ? z[0] : "");
        setzeZeile(v, R.id.widget_zeile1, z.length > 1 ? z[1] : null);

        // Die Reihe steht in z[2] als Text, damit `werte()` die einzige
        // Stelle bleibt, die ins Netz geht: `fuelle()` laeuft sonst
        // moeglicherweise im Vordergrundfaden.
        // **Die Veraenderung in Farbe, wie in der Anwendung**: gruen wenn es
        // hinaufging, rot wenn hinunter, sonst grau.
        String neben = z.length > 1 ? z[1] : null;
        if (neben != null && neben.startsWith("+"))
            v.setTextColor(R.id.widget_zeile1, 0xff4ade80);
        else if (neben != null && (neben.startsWith("-") || neben.startsWith("\u2212")))
            v.setTextColor(R.id.widget_zeile1, 0xffef5350);
        else
            v.setTextColor(R.id.widget_zeile1, 0xff9a94a6);

        int[] px = bildFlaeche(c, optionen, neben != null && !neben.isEmpty());
        double[] w = ausText(z.length > 2 ? z[2] : null);
        // **Kein leeres schwarzes Feld.** Mempool und Miner fangen ohne
        // Verlauf an; bis genug Punkte da sind, steht dort, dass er entsteht,
        // statt einer Flaeche, die wie ein Fehler aussieht.
        Bitmap b;
        if (w.length < 3) {
            b = Graph.hinweis(Texte.t(c, "waechst", w.length, punkte()), GRUND, px);
        } else {
            double lo = w[0], hi = w[0];
            for (double x : w) {
                lo = Math.min(lo, x);
                hi = Math.max(hi, x);
            }
            b = Graph.zeichne(w, linienFarbe(), GRUND,
                              zahl(hi, stellen()) + einheit(),
                              zahl(lo, stellen()) + einheit(),
                              z.length > 3 ? z[3] : null,
                              z.length > 4 ? z[4] : null, px);
        }
        v.setImageViewBitmap(R.id.widget_bild, b);
    }

    /** Reihe als Text: Werte durch Semikolon getrennt. */
    protected static String alsText(double[] w) {
        if (w == null || w.length == 0)
            return "";
        StringBuilder s = new StringBuilder();
        for (int i = 0; i < w.length; i++) {
            if (i > 0)
                s.append(';');
            s.append(w[i]);
        }
        return s.toString();
    }

    private static double[] ausText(String s) {
        if (s == null || s.isEmpty())
            return new double[0];
        String[] t = s.split(";");
        double[] w = new double[t.length];
        int n = 0;
        for (String x : t) {
            try {
                w[n++] = Double.parseDouble(x);
            } catch (NumberFormatException e) {
                // Punkt ueberspringen statt die Kurve wegzuwerfen.
            }
        }
        if (n == w.length)
            return w;
        double[] k = new double[n];
        System.arraycopy(w, 0, k, 0, n);
        return k;
    }
}
