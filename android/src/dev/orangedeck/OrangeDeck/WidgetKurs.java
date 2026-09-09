package dev.orangedeck.OrangeDeck;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;

/** Kurs in Euro, dazu die Moscow Time. */
public class WidgetKurs extends DeckWidget {

    @Override protected String titel(Context c) { return c.getString(R.string.widget_kurs); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject p = holeObjekt("/v1/prices");
        String schl = waehrungSchluessel(c), zeichen = waehrungZeichen(c);
        double kurs = p.optDouble(schl, 0);
        if (kurs <= 0)
            throw new IllegalStateException("kein Kurs");
        // Moscow Time: wie viele Satoshi es fuer eine Einheit Fiat gibt.
        long sats = Math.round(100000000.0 / kurs);
        // **Die Tagesveraenderung kostet 160 Byte.** `historical-price` ohne
        // Zeitstempel liefert die ganze Geschichte (1,5 MB) -- mit
        // Zeitstempel genau einen Punkt. Zweimal je Stunde waeren es sonst
        // 72 MB am Tag, und dafuer ist ein Widget der falsche Ort.
        String tag = null;
        try {
            long vor24h = System.currentTimeMillis() / 1000 - 86400;
            JSONObject h = holeObjekt("/v1/historical-price?currency=" + schl
                                      + "&timestamp=" + vor24h);
            JSONArray reihe = h.optJSONArray("prices");
            if (reihe != null && reihe.length() > 0) {
                double alt = reihe.getJSONObject(0).optDouble(schl, 0);
                if (alt > 0) {
                    double d = (kurs - alt) / alt * 100.0;
                    tag = c.getString(R.string.widget_tag,
                                      (d >= 0 ? "+" : "") + zahl(d, 2));
                }
            }
        } catch (Exception e) {
            // Zugabe, nicht Zweck: faellt sie aus, steht der Kurs trotzdem da.
        }
        // Der Dollar steht als zweite Zeile nur dann, wenn er nicht schon
        // oben steht.
        String zweit = (!"USD".equals(schl) && p.has("USD"))
            ? zahl(p.optDouble("USD", 0), 0) + " $" : null;
        return new String[] {
            zahl(kurs, 0) + " " + zeichen,
            c.getString(R.string.widget_moscow, zahl(sats, 0), zeichen),
            zweit,
            tag
        };
    }
}
