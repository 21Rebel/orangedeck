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
 * <p>Eine Zeile je Punkt: {@code zeit;wert}, die Zeit in Sekunden.
 *
 * <p><b>Der Zeitstempel kam am 09.09.2026 dazu.</b> Ohne ihn stand unter dem
 * Kursgraphen "+11 292,9 % ueber 180 Punkte" -- eine Zahl, die niemandem
 * etwas sagt, weil "180 Punkte" kein Zeitraum ist und der geholte Verlauf
 * Jahre zurueckreichte. Mit Zeitstempel steht dort, was tatsaechlich zu sehen
 * ist: "30 Tage". Zeilen im alten Format (nur der Wert) werden weiter
 * gelesen, damit ein vorhandener Verlauf nicht wegfaellt.
 */
final class Verlauf {

    private Verlauf() { }

    private static File datei(Context c, String name) {
        File d = new File(c.getFilesDir(), "widget");
        if (!d.isDirectory())
            d.mkdirs();
        return new File(d, name + ".txt");
    }

    /** Ein Punkt: Zeit in Sekunden und Wert. */
    static final class Punkt {
        final long zeit;
        final double wert;
        Punkt(long z, double w) { zeit = z; wert = w; }
    }

    static java.util.List<Punkt> lesen(Context c, String name) {
        ArrayList<Punkt> l = new ArrayList<>();
        File f = datei(c, name);
        if (!f.isFile())
            return l;
        try {
            BufferedReader r = new BufferedReader(new FileReader(f));
            String z;
            while ((z = r.readLine()) != null) {
                z = z.trim();
                if (z.isEmpty())
                    continue;
                try {
                    int semi = z.indexOf(';');
                    if (semi < 0)
                        // Altes Format: nur der Wert, Zeit unbekannt.
                        l.add(new Punkt(0, Double.parseDouble(z)));
                    else
                        l.add(new Punkt(Long.parseLong(z.substring(0, semi)),
                                        Double.parseDouble(z.substring(semi + 1))));
                } catch (Exception e) {
                    // Eine kaputte Zeile ueberspringen statt den ganzen
                    // Verlauf wegzuwerfen.
                }
            }
            r.close();
        } catch (Exception e) {
            return new ArrayList<>();
        }
        return l;
    }

    /** Nur die Werte, fuer den Graphen. */
    static double[] werte(Context c, String name) {
        java.util.List<Punkt> l = lesen(c, name);
        double[] w = new double[l.size()];
        for (int i = 0; i < w.length; i++)
            w[i] = l.get(i).wert;
        return w;
    }

    /** Zeitraum des Verlaufs in Sekunden, 0 wenn unbekannt. */
    static long spanne(Context c, String name) {
        java.util.List<Punkt> l = lesen(c, name);
        if (l.size() < 2)
            return 0;
        long a = l.get(0).zeit, b = l.get(l.size() - 1).zeit;
        return (a <= 0 || b <= 0) ? 0 : Math.max(0, b - a);
    }

    static void schreiben(Context c, String name, java.util.List<Punkt> p, int hoechstens) {
        int von = Math.max(0, p.size() - hoechstens);
        try {
            BufferedWriter w = new BufferedWriter(new FileWriter(datei(c, name)));
            for (int i = von; i < p.size(); i++) {
                w.write(Long.toString(p.get(i).zeit));
                w.write(';');
                w.write(Double.toString(p.get(i).wert));
                w.newLine();
            }
            w.close();
        } catch (Exception e) {
            // Ein Graph ohne Gedaechtnis ist ein Schoenheitsfehler, kein
            // Grund, das Widget scheitern zu lassen.
        }
    }

    /** Haengt einen Punkt an und kappt vorne. Liefert die neuen Werte. */
    static double[] anhaengen(Context c, String name, double wert, int hoechstens) {
        java.util.List<Punkt> l = lesen(c, name);
        l.add(new Punkt(System.currentTimeMillis() / 1000, wert));
        while (l.size() > hoechstens)
            l.remove(0);
        schreiben(c, name, l, hoechstens);
        double[] w = new double[l.size()];
        for (int i = 0; i < w.length; i++)
            w[i] = l.get(i).wert;
        return w;
    }

    static int laenge(Context c, String name) {
        return lesen(c, name).size();
    }

    static boolean leer(Context c, String name) {
        return laenge(c, name) < 2;
    }

    /**
     * Stammt der Verlauf aus einer Fassung ohne Zeitstempel?
     *
     * <p>Dann laesst sich sein Zeitraum nicht benennen, und beim Kurs kaeme
     * er ausserdem aus einem viel zu grossen Fenster. Wer das feststellt,
     * baut ihn neu auf, statt ihn weiterzuschleppen: die Datei liegt im
     * privaten Verzeichnis eines Release-Baus und laesst sich von aussen
     * nicht loeschen.
     */
    static boolean ohneZeit(Context c, String name) {
        for (Punkt p : lesen(c, name))
            if (p.zeit <= 0)
                return true;
        return false;
    }
}
