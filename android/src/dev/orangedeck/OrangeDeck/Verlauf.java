package dev.orangedeck.OrangeDeck;

import android.content.Context;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.ArrayList;

/**
 * Ein kleiner Zahlenspeicher fuer die Graph-Widgets.
 *
 * <p><b>Warum ueberhaupt einer.</b> Ein Widget kann sich seine Geschichte
 * nicht jedes Mal holen. Beim Kurs kostet der volle Verlauf 1.477.817 Byte
 * (gemessen am 09.09.2026); zweimal je Stunde waeren das 72 MB am Tag. Beim
 * Miner gibt es ihn gar nicht: AxeOS zeichnet nur auf, wenn
 * {@code statsFrequency} gesetzt ist, und die cgminer-Schnittstelle kennt
 * keinen Verlauf. Deshalb schreibt das Widget mit, so wie der Daemon es fuer
 * die Miner tut.
 *
 * <p>Eine Zeile je Wert, als Text. Kein Zeitstempel: die Punkte stehen im
 * Abstand des Aktualisierungstakts, und ein Graph ohne Achsenbeschriftung
 * braucht nicht mehr. Faellt ein Lauf aus, fehlt ein Punkt und die Kurve ist
 * an der Stelle etwas gestreckt. Das ist ehrlicher als ein erfundener Wert.
 */
final class Verlauf {

    private Verlauf() { }

    private static File datei(Context c, String name) {
        File d = new File(c.getFilesDir(), "widget");
        if (!d.isDirectory())
            d.mkdirs();
        return new File(d, name + ".txt");
    }

    static double[] lesen(Context c, String name) {
        File f = datei(c, name);
        if (!f.isFile())
            return new double[0];
        ArrayList<Double> l = new ArrayList<>();
        try {
            BufferedReader r = new BufferedReader(new FileReader(f));
            String z;
            while ((z = r.readLine()) != null) {
                z = z.trim();
                if (z.isEmpty())
                    continue;
                try {
                    l.add(Double.valueOf(z));
                } catch (NumberFormatException e) {
                    // Eine kaputte Zeile ueberspringen statt den ganzen
                    // Verlauf wegzuwerfen.
                }
            }
            r.close();
        } catch (Exception e) {
            return new double[0];
        }
        double[] w = new double[l.size()];
        for (int i = 0; i < w.length; i++)
            w[i] = l.get(i);
        return w;
    }

    static void schreiben(Context c, String name, double[] werte, int hoechstens) {
        int von = Math.max(0, werte.length - hoechstens);
        try {
            BufferedWriter w = new BufferedWriter(new FileWriter(datei(c, name)));
            for (int i = von; i < werte.length; i++) {
                w.write(Double.toString(werte[i]));
                w.newLine();
            }
            w.close();
        } catch (Exception e) {
            // Ein Graph ohne Gedaechtnis ist ein Schoenheitsfehler, kein
            // Grund, das Widget scheitern zu lassen.
        }
    }

    /** Haengt einen Punkt an und kappt vorne. Liefert den neuen Verlauf. */
    static double[] anhaengen(Context c, String name, double wert, int hoechstens) {
        double[] alt = lesen(c, name);
        double[] neu = new double[alt.length + 1];
        System.arraycopy(alt, 0, neu, 0, alt.length);
        neu[alt.length] = wert;
        if (neu.length > hoechstens) {
            double[] kurz = new double[hoechstens];
            System.arraycopy(neu, neu.length - hoechstens, kurz, 0, hoechstens);
            neu = kurz;
        }
        schreiben(c, name, neu, hoechstens);
        return neu;
    }

    static boolean leer(Context c, String name) {
        return lesen(c, name).length < 2;
    }
}
