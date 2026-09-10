package dev.orangedeck.OrangeDeck;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;

/** Blockhoehe und wie lange der letzte Block her ist. */
public class WidgetUhr extends DeckWidget {

    @Override protected String titel(Context c) { return Texte.t(c, "uhr"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        // `/v1/blocks` liefert Hoehe und Zeitstempel in einem Zug -- sonst
        // waeren es zwei Abfragen (tip/height und dann der Block dazu), und
        // dafuer ist die Frist von `goAsync()` zu knapp.
        JSONArray a = holeFeld("/v1/blocks");
        if (a.length() == 0)
            throw new IllegalStateException("keine Bloecke");
        JSONObject b = a.getJSONObject(0);
        long hoehe = b.getLong("height");
        long zeit = b.getLong("timestamp");                 // Sekunden
        long min = Math.max(0, (System.currentTimeMillis() / 1000 - zeit) / 60);
        // Beides steckt schon in derselben Antwort: keine zweite Abfrage,
        // und die Frist von `goAsync()` bleibt unangetastet.
        String tx = b.has("tx_count")
            ? Texte.t(c, "tx", zahl(b.optLong("tx_count", 0), 0)) : null;
        String pool = null;
        JSONObject extras = b.optJSONObject("extras");
        if (extras != null) {
            JSONObject p = extras.optJSONObject("pool");
            if (p != null && p.has("name"))
                pool = p.optString("name", null);
        }
        return new String[] {
            zahl(hoehe, 0),
            Texte.t(c, "vor_min", min),
            tx,
            pool
        };
    }
}
