package dev.orangedeck.OrangeDeck;

import android.content.Context;
import android.os.Bundle;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Mempool ausfuehrlich: die Blockkarten des Explorers.
 *
 * <p>Zwei geplante Bloecke links, zwei gefundene rechts, getrennt wie in der
 * Anwendung. Dieselben Felder wie in {@code BlockChain.qml}: Mediangebuehr
 * gross, dann Spanne bzw. Belohnung, Transaktionszahl, Groesse und zuletzt
 * Zeit und Pool. Farben ebenfalls von dort ({@code pendingColor #2f9e63},
 * {@code minedColor #7b5cd6}).
 *
 * <p><b>Nicht die Kachelgrafik.</b> Die braeuchte je Block eine Zeile pro
 * Transaktion ({@code /v1/block/<hash>/summary}, geschaetzt rund 500 kB bei
 * fuenftausend) und das je Aktualisierung. Und selbst dann waere ein Block im
 * Widget rund 150 px breit, also zwei Geraetepixel je Kachel: unter vier
 * passen Kachel und Fuge nicht beide hinein. Derselbe Befund wie am
 * 09.09.2026 im kleinen Fenster am Schreibtisch.
 */
public class WidgetMempoolGross extends DeckWidget {

    // Trennzeichen der Kartendaten. Druckbar und in keinem Wert vorkommend:
    // Zahlen, Poolnamen und Einheiten enthalten kein "|".
    private static final String KARTE = "|#|";
    private static final String FELD = "|~|";

    @Override protected String titel(Context c) { return Texte.t(c, "mempool"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_EXPLORER"; }
    @Override protected int layoutId() { return R.layout.widget_graph; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject m = holeObjekt("/mempool");
        long anzahl = m.optLong("count", 0);

        // **Die wartenden Transaktionen stehen klein darunter, nicht gross.**
        // Gross steht die Blockhoehe -- dieses Widget zeigt Bloecke, und ueber
        // den Karten liest man die Hoehe zuerst. Am 10.09.2026 so gewuenscht.
        // Das kleine Mempool-Widget behaelt die Anzahl als Hauptwert: dort
        // ist sie die Aussage, und fuer die Hoehe gibt es ein eigenes.
        String neben = Texte.t(c, "unbestaetigt", zahl(anzahl, 0));
        try {
            JSONObject g = holeObjekt("/v1/fees/recommended");
            neben += " · " + Texte.t(c, "satvb", zahl(g.optDouble("halfHourFee", 0), 0))
                   + " · " + Texte.t(c, "bloecke",
                                             zahl(m.optLong("vsize", 0) / 1000000.0, 1));
        } catch (Exception e) { /* Gebuehr und Rueckstau fallen weg */ }
        long hoehe = 0;

        StringBuilder karten = new StringBuilder();

        // **Die zwei geplanten, in der Reihenfolge der Anwendung:** der
        // uebernaechste links, der naechste rechts daneben. So laeuft die
        // Zeit auf die Trennlinie zu.
        try {
            JSONArray a = holeFeld("/v1/fees/mempool-blocks");
            for (int i = Math.min(1, a.length() - 1); i >= 0; i--) {
                JSONObject b = a.getJSONObject(i);
                double med = b.optDouble("medianFee", 0);
                JSONArray sp = b.optJSONArray("feeRange");
                String spanne = (sp != null && sp.length() >= 2)
                    ? zahl(sp.optDouble(0, 0), 1) + " – "
                      + zahl(sp.optDouble(sp.length() - 1, 0), 1)
                    : null;
                karte(karten, String.valueOf(Bloecke.gebuehrenTon(med)),
                      Texte.t(c, "in_min", (i + 1) * 10),
                      "~" + zahl(med, 1) + " sat/vB",
                      spanne,
                      Texte.t(c, "tx", zahl(b.optLong("nTx", 0), 0)),
                      zahl(b.optDouble("blockVSize", 0) / 1e6, 2) + " MB",
                      null, null);
            }
        } catch (Exception e) { /* Karten fallen weg */ }

        // Die zwei zuletzt gefundenen, neueste links an der Trennlinie.
        try {
            JSONArray a = holeFeld("/v1/blocks");
            if (a.length() > 0)
                hoehe = a.getJSONObject(0).optLong("height", 0);
            for (int i = 0; i < 2 && i < a.length(); i++) {
                JSONObject b = a.getJSONObject(i);
                JSONObject ex = b.optJSONObject("extras");
                double med = ex != null ? ex.optDouble("medianFee", 0) : 0;
                long min = Math.max(0,
                    (System.currentTimeMillis() / 1000 - b.optLong("timestamp", 0)) / 60);
                String pool = null;
                if (ex != null) {
                    JSONObject po = ex.optJSONObject("pool");
                    if (po != null)
                        pool = po.optString("name", null);
                }
                karte(karten, String.valueOf(Bloecke.GEFUNDEN),
                      zahl(b.optLong("height", 0), 0),
                      "~" + zahl(med, 1) + " sat/vB",
                      ex != null ? zahl(ex.optDouble("reward", 0) / 1e8, 3) + " BTC" : null,
                      Texte.t(c, "tx", zahl(b.optLong("tx_count", 0), 0)),
                      zahl(b.optLong("size", 0) / 1048576.0, 2) + " MB",
                      Texte.t(c, "vor_min", min),
                      pool);
            }
        } catch (Exception e) { /* Karten fallen weg */ }

        return new String[] { hoehe > 0 ? zahl(hoehe, 0) : "–", neben, karten.toString() };
    }

    private static void karte(StringBuilder s, String ton, String kopf, String... zeilen) {
        if (s.length() > 0)
            s.append(KARTE);
        s.append(ton).append(FELD).append(kopf == null ? "" : kopf);
        for (String z : zeilen)
            s.append(FELD).append(z == null ? "" : z);
    }

    @Override
    protected void fuelle(Context c, RemoteViews v, String[] z, Bundle optionen) {
        v.setTextViewText(R.id.widget_titel, titel(c));
        v.setTextViewText(R.id.widget_gross, z.length > 0 && z[0] != null ? z[0] : "");
        String neben = z.length > 1 ? z[1] : null;
        setzeZeile(v, R.id.widget_zeile1, neben);
        v.setTextColor(R.id.widget_zeile1, 0xff9a94a6);
        int[] px = bildFlaeche(c, optionen, neben != null && !neben.isEmpty());

        String roh = z.length > 2 && z[2] != null ? z[2] : "";
        if (roh.isEmpty()) {
            v.setImageViewBitmap(R.id.widget_bild,
                Graph.hinweis(Texte.t(c, "offline"), px));
            return;
        }
        // split() nimmt einen regulaeren Ausdruck: die Trennzeichen enthalten
        // "|" und muessen deshalb maskiert werden.
        String[] k = roh.split("\\|#\\|", -1);
        String[] kopf = new String[k.length];
        String[][] zeilen = new String[k.length][];
        int[] toene = new int[k.length];
        for (int i = 0; i < k.length; i++) {
            String[] f = k[i].split("\\|~\\|", -1);
            try {
                toene[i] = Integer.parseInt(f[0]);
            } catch (Exception e) {
                toene[i] = Bloecke.GEFUNDEN;
            }
            kopf[i] = f.length > 1 && !f[1].isEmpty() ? f[1] : null;
            zeilen[i] = new String[Math.max(0, f.length - 2)];
            for (int j = 2; j < f.length; j++)
                zeilen[i][j - 2] = f[j].isEmpty() ? null : f[j];
        }
        v.setImageViewBitmap(R.id.widget_bild,
                             Bloecke.zeichne(kopf, zeilen, toene, px));
    }
}
