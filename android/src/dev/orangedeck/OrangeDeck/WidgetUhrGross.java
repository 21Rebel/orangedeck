package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Die grosse Blockuhr: dieselben Werte wie der Reiter "Uhr" in der Anwendung.
 *
 * <p><b>Fuenf Abfragen in einer Frist.</b> `goAsync()` haelt den Empfaenger
 * rund zehn Sekunden am Leben, und hier laufen fuenf Aufrufe nacheinander.
 * Deshalb steht die Frist je Aufruf auf drei Sekunden statt sechs: ein
 * langsamer Server darf die anderen vier nicht mitreissen. Jeder Block ist
 * einzeln abgesichert; faellt einer aus, fehlt seine Zeile und der Rest steht.
 *
 * <p>Die Reihenfolge ist nach Wichtigkeit sortiert. Was zuerst kommt, hat die
 * beste Aussicht, die Frist noch zu erwischen.
 */
public class WidgetUhrGross extends DeckWidget {

    /** Halving alle 210 000 Bloecke; das letzte lag bei 840 000. */
    private static final long HALVING_ABSTAND = 210000;

    @Override protected String titel(Context c) { return c.getString(R.string.widget_uhr_gross); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }
    @Override protected int layoutId() { return R.layout.widget_uhr_gross; }

    @Override
    protected int[] zeilenIds() {
        return new int[] { R.id.widget_zeile1, R.id.widget_zeile2, R.id.widget_zeile3,
                           R.id.widget_zeile4, R.id.widget_zeile5 };
    }

    @Override
    protected String[] werte(Context c) throws Exception {
        // 1. Block: ohne ihn gibt es keine Uhr.
        JSONArray a = new JSONArray(holeVon("https://mempool.space/api/v1/blocks", 3000));
        if (a.length() == 0)
            throw new IllegalStateException("keine Bloecke");
        JSONObject b = a.getJSONObject(0);
        long hoehe = b.getLong("height");
        long min = Math.max(0, (System.currentTimeMillis() / 1000 - b.getLong("timestamp")) / 60);

        String uhrzeit = new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date());
        String z1 = uhrzeit + " · " + c.getString(R.string.widget_vor_min, min);

        // 2. Kurs und Moscow Time
        String z2 = null;
        try {
            JSONObject p = new JSONObject(holeVon("https://mempool.space/api/v1/prices", 3000));
            double eur = p.optDouble("EUR", 0);
            if (eur > 0)
                z2 = zahl(eur, 0) + " € · "
                   + c.getString(R.string.widget_moscow, zahl(Math.round(1e8 / eur), 0));
        } catch (Exception e) { /* Zeile faellt weg */ }

        // 3. Mempool und Gebuehr
        String z3 = null;
        try {
            JSONObject m = new JSONObject(holeVon("https://mempool.space/api/mempool", 3000));
            String s = zahl(m.optLong("count", 0), 0) + " "
                     + c.getString(R.string.widget_mempool_kurz);
            try {
                JSONObject g = new JSONObject(
                    holeVon("https://mempool.space/api/v1/fees/recommended", 3000));
                s += " · " + c.getString(R.string.widget_satvb,
                                         zahl(g.optDouble("halfHourFee", 0), 0));
            } catch (Exception e) { /* nur die Gebuehr fehlt */ }
            z3 = s;
        } catch (Exception e) { /* Zeile faellt weg */ }

        // 4. Schwierigkeit
        String z4 = null;
        try {
            JSONObject d = new JSONObject(
                holeVon("https://mempool.space/api/v1/difficulty-adjustment", 3000));
            double aend = d.optDouble("difficultyChange", 0);
            z4 = c.getString(R.string.widget_schwierigkeit,
                             (aend >= 0 ? "+" : "") + zahl(aend, 1),
                             zahl(d.optLong("remainingBlocks", 0), 0));
        } catch (Exception e) { /* Zeile faellt weg */ }

        // 5. Halving: reine Rechnung, keine Abfrage.
        long naechstes = (hoehe / HALVING_ABSTAND + 1) * HALVING_ABSTAND;
        String z5 = c.getString(R.string.widget_halving,
                                zahl(naechstes, 0), zahl(naechstes - hoehe, 0));

        return new String[] { zahl(hoehe, 0), z1, z2, z3, z4, z5 };
    }
}
