package dev.orangedeck.OrangeDeck;

import android.content.Context;

import org.json.JSONObject;

/**
 * Miner mit Hashrate-Verlauf.
 *
 * <p><b>Der Verlauf entsteht erst im Betrieb.</b> AxeOS zeichnet nur auf,
 * wenn {@code statsFrequency} gesetzt ist, und die cgminer-Schnittstelle
 * kennt gar keinen Verlauf: derselbe Satz steht seit dem 02.09.2026 im Kopf
 * von {@code ui/qml/MinerChart.qml}. Das Widget schreibt deshalb selbst mit,
 * einen Punkt je Aktualisierung. Am Anfang ist der Graph leer; nach einem Tag
 * hat er rund achtundvierzig Punkte.
 *
 * <p>Aufgezeichnet wird der **Momentanwert** ({@code hashRate}), nicht der
 * geglaettete Zehnminutenwert. Der ist im Betrieb fast eine Waagerechte, und
 * genau deshalb ist er am 09.09.2026 aus dem Graphen der Anwendung
 * geflogen.
 */
public class WidgetMinerGross extends GraphWidget {

    private static final String SPEICHER = "miner";
    private static final int PUNKTE = 180;

    @Override protected String titel(Context c) { return Texte.t(c, "miner"); }
    @Override protected String aktion() { return "dev.orangedeck.OrangeDeck.VIEW_MINER"; }


    @Override
    protected String[] werte(Context c) throws Exception {
        String adresse = minerAdresse(c);
        if (adresse == null)
            return new String[] { "–", Texte.t(c, "miner_keine"), "" };

        JSONObject d = new JSONObject(holeVon("http://" + adresse + "/api/system/info", 4000));
        double gh = d.optDouble("hashRate", 0);
        double[] w = Verlauf.anhaengen(c, SPEICHER, gh, PUNKTE);

        String rate = gh >= 1025 ? zahl(gh / 1000.0, 2) + " TH/s" : zahl(gh, 0) + " GH/s";
        StringBuilder neben = new StringBuilder();
        if (d.has("temp"))
            neben.append(zahl(d.optDouble("temp", 0), 0)).append(" °C");
        if (d.has("bestDiff")) {
            if (neben.length() > 0)
                neben.append(" · ");
            neben.append(Texte.t(c, "beste", kurz(d.optString("bestDiff", ""))));
        }
        return new String[] { rate, neben.length() > 0 ? neben.toString() : null, alsText(w) };
    }
}
