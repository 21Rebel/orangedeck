package dev.orangedeck.OrangeDeck;

import android.content.Context;
import org.json.JSONObject;

/** Kurs in Euro, dazu die Moscow Time. */
public class WidgetKurs extends DeckWidget {

    @Override protected String titel(Context c) { return c.getString(R.string.widget_kurs); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject p = holeObjekt("/v1/prices");
        double eur = p.optDouble("EUR", 0);
        if (eur <= 0)
            throw new IllegalStateException("kein Kurs");
        // Moscow Time: wie viele Satoshi es fuer eine Einheit Fiat gibt.
        long sats = Math.round(100000000.0 / eur);
        return new String[] {
            zahl(eur, 0) + " €",
            c.getString(R.string.widget_moscow, zahl(sats, 0)),
            p.has("USD") ? zahl(p.optDouble("USD", 0), 0) + " $" : null
        };
    }
}
