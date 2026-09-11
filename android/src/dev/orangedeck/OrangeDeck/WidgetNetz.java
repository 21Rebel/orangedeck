package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONObject;

/**
 * Das Netz: Hashrate, Schwierigkeit, naechste Anpassung, Blockzeit.
 *
 * <p>Dieselben Kennzahlen wie oben auf der Seite "Netz" im Miner-Reiter
 * ({@code ui/qml/NetworkView.qml}), aus denselben Quellen. Zwei kleine
 * Abfragen: {@code /v1/mining/hashrate/3d} (292 Byte, gemessen am
 * 11.09.2026) traegt die aktuelle Hashrate und Schwierigkeit,
 * {@code /v1/difficulty-adjustment} (345 Byte) die Anpassung und die
 * Blockzeit.
 */
public class WidgetNetz extends DeckWidget {

    @Override protected String titel(Context c) { return Texte.t(c, "netz"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_NETWORK"; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject h = holeObjekt("/v1/mining/hashrate/3d");
        double hashrate = h.optDouble("currentHashrate", 0);
        if (hashrate <= 0)
            throw new IllegalStateException("keine Hashrate");
        String schwierigkeit = Texte.t(c, "schwierigkeit_wert",
                                       kurz(String.valueOf(h.optDouble("currentDifficulty", 0))));

        // Zugabe, nicht Zweck: faellt sie aus, stehen Hashrate und
        // Schwierigkeit trotzdem da.
        String anpassung = null, blockzeit = null;
        try {
            JSONObject d = holeObjekt("/v1/difficulty-adjustment");
            anpassung = anpassung(c, d);
            blockzeit = blockzeit(c, d.optDouble("timeAvg", 0));
        } catch (Exception e) {
            // siehe oben
        }
        return new String[] { kurz(String.valueOf(hashrate)) + "H/s", schwierigkeit,
                              anpassung, blockzeit };
    }

    /**
     * "Anpassung +3,1 %" -- **ohne die Restzeit.** In 2x2 passen rund 22
     * Zeichen; "Adjustment +3.0 % · 7 days 20 h" stand am 11.09.2026
     * abgeschnitten da. Die Restzeit steht in der Anwendung.
     */
    static String anpassung(Context c, JSONObject d) {
        if (!d.has("difficultyChange"))
            return null;
        double p = d.optDouble("difficultyChange", 0);
        return Texte.t(c, "anpassung", (p >= 0 ? "+" : "\u2212") + zahl(Math.abs(p), 1));
    }

    /** "Ø Blockzeit 9:43 Min" -- aus Millisekunden, wie `minSek()` in NetworkView */
    static String blockzeit(Context c, double ms) {
        if (!(ms > 0))
            return null;
        long s = Math.round(ms / 1000);
        long sek = s % 60;
        return Texte.t(c, "blockzeit",
                       Texte.t(c, "min", (s / 60) + ":" + (sek < 10 ? "0" : "") + sek));
    }
}
