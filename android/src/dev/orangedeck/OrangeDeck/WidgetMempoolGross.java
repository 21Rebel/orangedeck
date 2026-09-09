package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONObject;

/**
 * Mempool mit Verlauf der Anzahl unbestaetigter Transaktionen.
 *
 * <p>Hier gibt es keine Geschichte zum Herunterladen: mempool.space liefert
 * den aktuellen Stand, nicht den Verlauf der Anzahl. Das Widget schreibt ihn
 * deshalb von Anfang an selbst mit. Nach einem halben Tag stehen rund
 * vierundzwanzig Punkte, und der Graph faengt an, etwas zu sagen.
 */
public class WidgetMempoolGross extends GraphWidget {

    private static final String SPEICHER = "mempool";
    private static final int PUNKTE = 180;
    /** Teal, wie die niedrigen Gebuehrenklassen in der Anwendung. */
    private static final int TEAL = 0xff2ad4c4;

    @Override protected String titel(Context c) { return c.getString(R.string.widget_mempool); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_FEED"; }
    @Override protected int linienFarbe() { return TEAL; }


    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject m = holeObjekt("/mempool");
        long anzahl = m.optLong("count", 0);
        double[] w = Verlauf.anhaengen(c, SPEICHER, anzahl, PUNKTE);

        String neben = null;
        try {
            JSONObject g = holeObjekt("/v1/fees/recommended");
            neben = c.getString(R.string.widget_satvb, zahl(g.optDouble("halfHourFee", 0), 0))
                  + " · " + c.getString(R.string.widget_bloecke,
                                        zahl(m.optLong("vsize", 0) / 1000000.0, 1));
        } catch (Exception e) { /* Nebenzeile faellt weg */ }

        return new String[] { zahl(anzahl, 0), neben, alsText(w) };
    }
}
