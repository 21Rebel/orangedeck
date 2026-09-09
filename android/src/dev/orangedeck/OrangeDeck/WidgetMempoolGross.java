package dev.orangedeck.OrangeDeck;

import android.content.Context;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Mempool ausfuehrlich: die beiden zuletzt gefundenen Bloecke und die beiden
 * naechsten, wie im Feed der Anwendung.
 *
 * <p><b>Kein Verlauf, und das ist eine Entscheidung.</b> Die Anzahl im
 * Mempool laesst sich nicht herunterladen; ein Graph muesste erst tagelang
 * mitgeschrieben werden und stand bis dahin als leere Flaeche da. Die vier
 * Bloecke stehen sofort und sagen dasselbe deutlicher: was gerade
 * hineingeht, was gerade herauskommt.
 *
 * <p>Zwei Abfragen: {@code /v1/blocks} fuer das Gefundene,
 * {@code /v1/fees/mempool-blocks} fuer das Geplante (2 kB, acht Bloecke, wir
 * nehmen zwei).
 */
public class WidgetMempoolGross extends DeckWidget {

    @Override protected String titel(Context c) { return c.getString(R.string.widget_mempool); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_FEED"; }
    @Override protected int layoutId() { return R.layout.widget_bloecke; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject m = holeObjekt("/mempool");
        long anzahl = m.optLong("count", 0);

        String neben = null;
        try {
            JSONObject g = holeObjekt("/v1/fees/recommended");
            neben = c.getString(R.string.widget_satvb, zahl(g.optDouble("halfHourFee", 0), 0))
                  + " · " + c.getString(R.string.widget_bloecke,
                                        zahl(m.optLong("vsize", 0) / 1000000.0, 1));
        } catch (Exception e) { /* Nebenzeile faellt weg */ }

        // Die zwei zuletzt gefundenen. Neueste zuerst, also umgedreht
        // einsetzen, damit die Zeit von links nach rechts laeuft.
        String[] alt = new String[6];
        try {
            JSONArray a = holeFeld("/v1/blocks");
            for (int i = 0; i < 2 && i < a.length(); i++) {
                JSONObject b = a.getJSONObject(1 - i);
                long min = Math.max(0,
                    (System.currentTimeMillis() / 1000 - b.optLong("timestamp", 0)) / 60);
                alt[i * 3] = zahl(b.optLong("height", 0), 0);
                alt[i * 3 + 1] = c.getString(R.string.widget_tx_kurz,
                                             zahl(b.optLong("tx_count", 0), 0));
                alt[i * 3 + 2] = c.getString(R.string.widget_vor_min, min);
            }
        } catch (Exception e) { /* Spalten bleiben leer */ }

        // Die zwei naechsten.
        String[] neu = new String[6];
        try {
            JSONArray a = holeFeld("/v1/fees/mempool-blocks");
            for (int i = 0; i < 2 && i < a.length(); i++) {
                JSONObject b = a.getJSONObject(i);
                neu[i * 3] = c.getString(i == 0 ? R.string.widget_naechster
                                                : R.string.widget_danach);
                neu[i * 3 + 1] = c.getString(R.string.widget_tx_kurz,
                                             zahl(b.optLong("nTx", 0), 0));
                neu[i * 3 + 2] = c.getString(R.string.widget_satvb,
                                             zahl(b.optDouble("medianFee", 0), 1));
            }
        } catch (Exception e) { /* Spalten bleiben leer */ }

        String[] z = new String[14];
        z[0] = zahl(anzahl, 0);
        z[1] = neben;
        System.arraycopy(alt, 0, z, 2, 6);
        System.arraycopy(neu, 0, z, 8, 6);
        return z;
    }

    @Override
    protected void fuelle(Context c, RemoteViews v, String[] z) {
        v.setTextViewText(R.id.widget_titel, titel(c));
        v.setTextViewText(R.id.widget_gross, z.length > 0 && z[0] != null ? z[0] : "");
        setzeZeile(v, R.id.widget_zeile1, z.length > 1 ? z[1] : null);

        int[][] felder = {
            { R.id.b1_kopf, R.id.b1_tx, R.id.b1_fuss },
            { R.id.b2_kopf, R.id.b2_tx, R.id.b2_fuss },
            { R.id.b3_kopf, R.id.b3_tx, R.id.b3_fuss },
            { R.id.b4_kopf, R.id.b4_tx, R.id.b4_fuss },
        };
        for (int s = 0; s < 4; s++) {
            for (int r = 0; r < 3; r++) {
                int i = 2 + s * 3 + r;
                String t = (z.length > i && z[i] != null) ? z[i] : "–";
                v.setTextViewText(felder[s][r], t);
            }
        }
    }
}
