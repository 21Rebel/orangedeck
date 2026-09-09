package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Kurs mit Verlauf.
 *
 * <p><b>Die Geschichte wird einmal geholt und danach fortgeschrieben.</b>
 * `historical-price` ohne Zeitstempel sind 1.477.817 Byte (gemessen am
 * 09.09.2026) und enthalten Stundenwerte ueber Monate. Zweimal je Stunde
 * abgerufen waeren das 72 MB am Tag: fuer ein Widget kein vertretbarer Preis.
 * Also einmal beim ersten Lauf, auf {@link #PUNKTE} Punkte ausgeduennt, in
 * {@link Verlauf} abgelegt. Danach kostet jede Aktualisierung nur noch den
 * aktuellen Kurs.
 */
public class WidgetKursGross extends GraphWidget {

    private static final String SPEICHER = "kurs";
    /** So viele Punkte traegt der Graph; mehr sind bei 640 px Breite nicht zu sehen. */
    private static final int PUNKTE = 180;

    @Override protected String titel(Context c) { return c.getString(R.string.widget_kurs); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_CLOCK"; }


    @Override
    protected String[] werte(Context c) throws Exception {
        JSONObject p = holeObjekt("/v1/prices");
        double eur = p.optDouble("EUR", 0);
        if (eur <= 0)
            throw new IllegalStateException("kein Kurs");

        double[] w;
        if (Verlauf.leer(c, SPEICHER)) {
            // Der einmalige grosse Abruf. Frist grosszuegig: er passiert
            // genau einmal, und ohne ihn bliebe der Graph tagelang leer.
            w = ersteGeschichte(c, eur);
        } else {
            w = Verlauf.anhaengen(c, SPEICHER, eur, PUNKTE);
        }

        // Die Veraenderung ueber den gezeigten Zeitraum, aus der Reihe selbst
        // gerechnet: keine zusaetzliche Abfrage.
        String neben = zahl(eur, 0) + " €";
        if (w.length >= 2 && w[0] > 0) {
            double d = (eur - w[0]) / w[0] * 100.0;
            neben = c.getString(R.string.widget_seit,
                                (d >= 0 ? "+" : "") + zahl(d, 1), w.length);
        }
        return new String[] { zahl(eur, 0) + " €", neben, alsText(w) };
    }

    private double[] ersteGeschichte(Context c, double jetzt) {
        try {
            JSONObject h = new JSONObject(
                holeVon("https://mempool.space/api/v1/historical-price?currency=EUR", 8000));
            JSONArray a = h.optJSONArray("prices");
            if (a == null || a.length() == 0)
                throw new IllegalStateException("kein Verlauf");
            // Die Reihe kommt neueste zuerst. Umdrehen und ausduennen.
            int schritt = Math.max(1, a.length() / PUNKTE);
            java.util.ArrayList<Double> l = new java.util.ArrayList<>();
            for (int i = a.length() - 1; i >= 0; i -= schritt) {
                double v = a.getJSONObject(i).optDouble("EUR", 0);
                if (v > 0)
                    l.add(v);
            }
            double[] w = new double[l.size()];
            for (int i = 0; i < w.length; i++)
                w[i] = l.get(i);
            Verlauf.schreiben(c, SPEICHER, w, PUNKTE);
            return w;
        } catch (Exception e) {
            // Faellt der grosse Abruf aus, faengt der Verlauf eben bei einem
            // Punkt an. Beim naechsten Lauf wird es noch einmal versucht.
            return Verlauf.anhaengen(c, SPEICHER, jetzt, PUNKTE);
        }
    }
}
