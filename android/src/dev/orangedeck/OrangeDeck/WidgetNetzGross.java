package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Das Netz mit dem Verlauf der Hashrate ueber neunzig Tage.
 *
 * <p><b>Der Verlauf wird jedes Mal ganz geholt, nicht fortgeschrieben.</b>
 * Anders als beim Kurs ist er klein: {@code /v1/mining/hashrate/3m} sind
 * 6,4 kB (gemessen am 11.09.2026), zweimal je Stunde also rund 300 kB am Tag.
 * Dafuer lohnt kein eigener Speicher, und der Graph ist beim ersten Lauf
 * gleich voll.
 *
 * <p><b>Gezeichnet wird das Mittel ueber sieben Tage</b>, wie die kraeftige
 * Linie in der Anwendung ({@code NetworkChart.qml}): die Tageswerte sind
 * Schaetzungen aus rund 144 Bloecken und springen um zwanzig Prozent. In
 * dieser Groesse gibt es keinen Platz fuer eine blasse zweite Linie, also
 * nur das Mittel.
 */
public class WidgetNetzGross extends GraphWidget {

    /** Halbe Breite des Mittels in Sekunden: dreieinhalb Tage zu jeder Seite. */
    private static final long FENSTER = 302400;

    @Override protected String titel(Context c) { return Texte.t(c, "netz"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_NETWORK"; }
    @Override protected String einheit() { return " EH/s"; }
    @Override protected int punkte() { return 90; }

    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject h = holeObjekt("/v1/mining/hashrate/3m");
        double hashrate = h.optDouble("currentHashrate", 0);
        if (hashrate <= 0)
            throw new IllegalStateException("keine Hashrate");

        JSONArray a = h.optJSONArray("hashrates");
        int n = a == null ? 0 : a.length();
        long[] zeit = new long[n];
        double[] wert = new double[n];
        for (int i = 0; i < n; i++) {
            JSONObject p = a.getJSONObject(i);
            zeit[i] = p.optLong("timestamp", 0);
            // In EH/s, damit die Beschriftung der Hilfslinien lesbar bleibt
            wert[i] = p.optDouble("avgHashrate", 0) / 1e18;
        }
        double[] mittel = new double[n];
        int von = 0, bis = 0;
        double summe = 0;
        for (int i = 0; i < n; i++) {
            while (bis < n && zeit[bis] <= zeit[i] + FENSTER)
                summe += wert[bis++];
            while (zeit[von] < zeit[i] - FENSTER)
                summe -= wert[von++];
            mittel[i] = summe / (bis - von);
        }

        StringBuilder neben = new StringBuilder(Texte.t(c, "schwierigkeit_wert",
            kurz(String.valueOf(h.optDouble("currentDifficulty", 0)))));
        try {
            JSONObject d = holeObjekt("/v1/difficulty-adjustment");
            if (d.has("difficultyChange")) {
                double p = d.optDouble("difficultyChange", 0);
                neben.append(" · ").append(p >= 0 ? "+" : "\u2212")
                     .append(zahl(Math.abs(p), 1)).append(" %");
            }
        } catch (Exception e) {
            // Zugabe, nicht Zweck
        }

        return new String[] {
            kurz(String.valueOf(hashrate)) + "H/s",
            neben.toString(),
            alsText(mittel),
            n > 0 ? datum(zeit[0]) : null,
            n > 0 ? datum(zeit[n - 1]) : null
        };
    }

    private static String datum(long sekunden) {
        if (sekunden <= 0)
            return null;
        return new java.text.SimpleDateFormat("dd.MM.yyyy", java.util.Locale.getDefault())
            .format(new java.util.Date(sekunden * 1000));
    }
}
