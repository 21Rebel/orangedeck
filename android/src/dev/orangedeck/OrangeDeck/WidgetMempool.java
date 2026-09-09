package dev.orangedeck.OrangeDeck;

import android.content.Context;
import org.json.JSONObject;

/** Unbestaetigte Transaktionen und die Gebuehr, die gerade traegt. */
public class WidgetMempool extends DeckWidget {

    @Override protected String titel(Context c) { return c.getString(R.string.widget_mempool); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_FEED"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject m = holeObjekt("/mempool");
        long anzahl = m.optLong("count", 0);
        long vsize = m.optLong("vsize", 0);
        // Ein Block fasst rund 1 000 000 vB. Die Zahl sagt mehr ueber den
        // Rueckstau als die reine Byte-Menge.
        double bloecke = vsize / 1000000.0;

        String gebuehr = null;
        try {
            JSONObject g = holeObjekt("/v1/fees/recommended");
            gebuehr = c.getString(R.string.widget_satvb, zahl(g.optDouble("halfHourFee", 0), 0));
        } catch (Exception e) {
            // Die Gebuehr ist die Zugabe, nicht der Zweck: faellt sie aus,
            // steht die Anzahl trotzdem da.
        }
        return new String[] {
            zahl(anzahl, 0),
            gebuehr,
            c.getString(R.string.widget_bloecke, zahl(bloecke, 1))
        };
    }
}
