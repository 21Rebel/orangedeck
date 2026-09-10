package dev.orangedeck.OrangeDeck;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.NumberFormat;
import java.util.Locale;

/**
 * Gemeinsamer Unterbau der Homescreen-Widgets.
 *
 * <p><b>Warum das hier Java ist und kein QML.</b> Ein Android-Widget zeichnet
 * nicht die Anwendung, sondern der Systemprozess des Launchers -- ueber
 * {@link RemoteViews}, also Text, Zahlen, Bilder, Fortschrittsbalken. Kein
 * Canvas, kein Qt, keine Kachelgrafik. Der Kommentar in
 * {@code res/xml/shortcuts.xml} sagt das seit dem 05.09.2026 voraus; hier ist
 * es eingeloest.
 *
 * <p><b>Und warum Java und nicht Kotlin:</b> das von androiddeployqt erzeugte
 * Gradle-Projekt legt zwar ein {@code kotlin.srcDirs} an, wendet aber kein
 * Kotlin-Plugin an -- Kotlin-Dateien fielen stillschweigend weg. Java aus
 * {@code android/src/} uebersetzt es ohne Zutun. Fuer Kotlin muessten wir eine
 * eigene {@code build.gradle} mitliefern und bei jedem Qt-Sprung nachziehen.
 *
 * <p><b>Der Takt ist nicht unsere Entscheidung.</b> {@code updatePeriodMillis}
 * laesst fruehestens alle 30 Minuten aktualisieren. Ein Widget ist damit immer
 * ein Standbild in grossen Abstaenden, nie ein laufender Mempool. Der Wert
 * steht in den {@code res/xml/widget_*.xml}.
 */
public abstract class DeckWidget extends AppWidgetProvider {

    /** Ueberschrift der Kachel. */
    protected abstract String titel(Context c);

    /**
     * Welches Layout die Kachel benutzt. Die grosse Blockuhr bringt ein
     * eigenes mit; alle anderen teilen sich {@code widget_deck}.
     */
    protected int layoutId() {
        return R.layout.widget_deck;
    }

    /**
     * Die Textfelder unter dem Hauptwert, von oben nach unten. Ein Widget mit
     * mehr Platz fuehrt hier mehr auf, und {@link #werte} darf entsprechend
     * mehr Zeilen liefern.
     */
    protected int[] zeilenIds() {
        return new int[] { R.id.widget_zeile1, R.id.widget_zeile2, R.id.widget_zeile3 };
    }

    /** Welche Ansicht beim Antippen aufgeht -- dieselben Aktionen wie die Verknuepfungen. */
    protected abstract String aktion();

    /**
     * Holt die Werte. Laeuft **nicht** im Vordergrund-Faden.
     *
     * @return bis zu vier Zeilen: gross, dann drei kleine. Ein {@code null}
     *         laesst die Zeile weg, und die uebrigen ruecken nach: bei 2x2
     *         bliebe sonst die untere Haelfte leer.
     */
    protected abstract String[] werte(Context c) throws Exception;

    private static final String API = "https://mempool.space/api";

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        // **Netz nie im Vordergrund-Faden.** `onUpdate` laeuft aus
        // `onReceive` heraus, und dort wirft jede Verbindung eine
        // NetworkOnMainThreadException. `goAsync()` haelt den Empfaenger am
        // Leben, bis der Faden fertig ist -- rund zehn Sekunden hat er dafuer.
        final PendingResult offen = goAsync();
        final Context c = context.getApplicationContext();
        new Thread(new Runnable() {
            @Override
            public void run() {
                String[] z;
                try {
                    z = werte(c);
                } catch (Exception e) {
                    // Kein leeres Widget: ein Strich sagt "gerade nichts da",
                    // eine leere Flaeche sieht aus wie ein Fehler im Launcher.
                    z = new String[] { "--", c.getString(R.string.widget_offline), null };
                }
                try {
                    zeichne(c, manager, ids, z);
                } finally {
                    offen.finish();
                }
            }
        }).start();
    }

    /**
     * Die Kachel wurde in der Groesse veraendert: neu zeichnen. Ohne das
     * bliebe ein Bild im Seitenverhaeltnis der alten Groesse stehen und
     * wuerde verzogen, bis in bis zu 30 Minuten der naechste Takt kommt.
     */
    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager,
                                          int id, Bundle neu) {
        onUpdate(context, manager, new int[] { id });
    }

    private void zeichne(Context c, AppWidgetManager manager, int[] ids, String[] z) {
        for (int id : ids) {
            RemoteViews v = new RemoteViews(c.getPackageName(), layoutId());
            fuelle(c, v, z, manager.getAppWidgetOptions(id));

            Intent i = new Intent(aktion());
            i.setClassName(c.getPackageName(), "org.qtproject.qt.android.bindings.QtActivity");
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // FLAG_IMMUTABLE ist ab Android 12 Pflicht; wir aendern die
            // Absicht ohnehin nicht mehr.
            v.setOnClickPendingIntent(R.id.widget_wurzel, PendingIntent.getActivity(
                    c, aktion().hashCode(), i,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));

            manager.updateAppWidget(id, v);
        }
    }

    /**
     * Traegt die Werte in die Kachel ein. Die Vorgabe passt zu
     * {@code widget_deck}: Ueberschrift, Hauptwert, dann die Zeilen aus
     * {@link #zeilenIds()}. Ein Widget mit eigenem Aufbau ueberschreibt das
     * ganz -- die grosse Blockuhr tut es, weil sie Spalten und einen Balken
     * hat und nicht nur Zeilen.
     */
    protected void fuelle(Context c, RemoteViews v, String[] z) {
        v.setTextViewText(R.id.widget_titel, titel(c));
        v.setTextViewText(R.id.widget_gross, z.length > 0 && z[0] != null ? z[0] : "");
        int[] felder = zeilenIds();
        for (int k = 0; k < felder.length; k++)
            setzeZeile(v, felder[k], z.length > k + 1 ? z[k + 1] : null);
    }

    /**
     * Wie {@link #fuelle(Context, RemoteViews, String[])}, mit den Optionen der
     * Kachel. Ueberschreibt, wer ein Bild zeichnet und dafuer die Groesse
     * braucht; alle anderen bleiben bei der Fassung ohne.
     */
    protected void fuelle(Context c, RemoteViews v, String[] z, Bundle optionen) {
        fuelle(c, v, z);
    }

    /**
     * Die Bildflaeche in {@code widget_graph}, in Geraetepixeln, oder
     * {@code null}, wenn der Starter keine Groesse meldet.
     *
     * <p>Der Starter nennt die Kachel nur als Spanne in dp: im Hochformat gilt
     * die kleinste Breite und die groesste Hoehe, quer umgekehrt. Davon gehen
     * die Abstaende aus {@code widget_graph.xml} ab -- 14dp Rand ringsum, 6dp
     * ueber dem Bild -- und die Textzeilen darueber in der Hoehe, die eine
     * {@code TextView} mit Schriftpolster wirklich hat. Die Schriftgroesse der
     * Einstellungen geht dabei mit ein.
     *
     * @param mitZeile ob die Nebenzeile unter dem Hauptwert zu sehen ist
     */
    protected static int[] bildFlaeche(Context c, Bundle o, boolean mitZeile) {
        if (o == null)
            return null;
        boolean quer = c.getResources().getConfiguration().orientation
                       == Configuration.ORIENTATION_LANDSCAPE;
        int bDp = o.getInt(quer ? AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
                                : AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH);
        int hDp = o.getInt(quer ? AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                                : AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT);
        if (bDp <= 0 || hDp <= 0)
            return null;

        DisplayMetrics dm = c.getResources().getDisplayMetrics();
        float b = (bDp - 2 * 14) * dm.density;
        float h = (hDp - 2 * 14 - 6) * dm.density
                  - zeilenHoehe(dm, 11, false)
                  - zeilenHoehe(dm, 30, true)
                  - (mitZeile ? zeilenHoehe(dm, 12, false) : 0);
        // Darunter lohnt kein Bild; dann lieber die alte feste Groesse.
        if (b < 32 || h < 32)
            return null;
        return new int[] { Math.round(b), Math.round(h) };
    }

    /** Hoehe einer einzeiligen TextView: {@code includeFontPadding} rechnet von top bis bottom. */
    private static float zeilenHoehe(DisplayMetrics dm, float sp, boolean fett) {
        Paint p = new Paint();
        p.setTextSize(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, dm));
        if (fett)
            p.setTypeface(Typeface.DEFAULT_BOLD);
        Paint.FontMetrics fm = p.getFontMetrics();
        return fm.bottom - fm.top;
    }

    protected static void setzeZeile(RemoteViews v, int id, String text) {
        if (text == null || text.isEmpty()) {
            v.setViewVisibility(id, android.view.View.GONE);
        } else {
            v.setViewVisibility(id, android.view.View.VISIBLE);
            v.setTextViewText(id, text);
        }
    }

    // ---------------------------------------------------------------- Hilfen

    /** Zahl mit den Trennzeichen der Geraetesprache -- 80.619, nicht 80619. */
    protected static String zahl(double d, int stellen) {
        NumberFormat f = NumberFormat.getInstance(Locale.getDefault());
        f.setMinimumFractionDigits(stellen);
        f.setMaximumFractionDigits(stellen);
        return f.format(d);
    }

    /**
     * Grosse Zahlen kurz: 673673426 wird zu "673 M".
     *
     * <p>Dieselbe Staffel wie {@code big()} in {@code ui/qml/MinerView.qml},
     * damit Widget und Anwendung dieselbe Zahl gleich schreiben. AxeOS liefert
     * {@code bestDiff} mal als Zeichenkette mit Suffix ("673M"), mal als blanke
     * Zahl; am 09.09.2026 stand deshalb "beste 673673426" auf dem
     * Startbildschirm.
     */
    protected static String kurz(String roh) {
        if (roh == null || roh.isEmpty())
            return null;
        String t = roh.trim();
        double n;
        try {
            n = Double.parseDouble(t);
        } catch (NumberFormatException e) {
            // Schon mit Suffix: so lassen, wie das Geraet es meldet.
            return t;
        }
        String[] u = { "", " k", " M", " G", " T", " P", " E" };
        int i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return zahl(n, n >= 100 ? 0 : 2) + u[i];
    }

    /** Dauer wie in der Anwendung: "9 Tage 9 Std", "11 Std", "40 Min". */
    protected static String dauer(Context c, long sekunden) {
        if (sekunden <= 0)
            return "";
        long tage = sekunden / 86400, std = (sekunden % 86400) / 3600;
        if (tage > 0)
            return c.getString(R.string.widget_tage_std, zahl(tage, 0), zahl(std, 0));
        if (std > 0)
            return c.getString(R.string.widget_std, zahl(std, 0));
        return c.getString(R.string.widget_min, zahl(sekunden / 60, 0));
    }

    protected static String hole(String pfad) throws Exception {
        return holeVon(API + pfad, 6000);
    }

    /**
     * Ein GET, mehr nicht. Kurze Fristen: `goAsync()` gibt uns rund zehn
     * Sekunden fuer alles zusammen.
     */
    protected static String holeVon(String url, int frist) throws Exception {
        HttpURLConnection v = (HttpURLConnection) new URL(url).openConnection();
        try {
            v.setConnectTimeout(frist);
            v.setReadTimeout(frist);
            v.setRequestProperty("User-Agent", "OrangeDeck-Widget");
            BufferedReader r = new BufferedReader(new InputStreamReader(v.getInputStream()));
            StringBuilder b = new StringBuilder();
            String zeile;
            while ((zeile = r.readLine()) != null)
                b.append(zeile);
            r.close();
            return b.toString();
        } finally {
            v.disconnect();
        }
    }

    protected static JSONObject holeObjekt(String pfad) throws Exception {
        return new JSONObject(hole(pfad));
    }

    protected static JSONArray holeFeld(String pfad) throws Exception {
        return new JSONArray(hole(pfad));
    }

    /**
     * Die Miner-Adresse aus den Einstellungen der Anwendung.
     *
     * <p>Qt legt sie ueber QSettings als schlichte ini-Datei ab
     * ({@code orangedeck/orangedeck.conf}, Schluessel {@code minerHostsRaw}).
     * Der Empfaenger laeuft im **eigenen** Prozess der Anwendung und kommt
     * damit an {@code getFilesDir()} -- eine Bruecke ueber C++ braucht es
     * nicht. Mehrere Adressen sind durch Komma getrennt; genommen wird die
     * erste.
     */
    protected static String minerAdresse(Context c) {
        String wert = ausEinstellungen(c, "minerHostsRaw");
        if (wert == null || wert.isEmpty())
            return null;
        // Mehrere Adressen sind durch Komma getrennt; genommen wird die erste.
        int komma = wert.indexOf(',');
        return komma < 0 ? wert : wert.substring(0, komma).trim();
    }

    /** Ein Wert aus Qts Einstellungsdatei, oder null. */
    protected static String ausEinstellungen(Context c, String schluessel) {
        File f = findeEinstellungen(c);
        if (f == null)
            return null;
        try {
            BufferedReader r = new BufferedReader(new java.io.FileReader(f));
            String zeile, wert = null;
            while ((zeile = r.readLine()) != null) {
                int gleich = zeile.indexOf('=');
                if (gleich < 0)
                    continue;
                if (!zeile.substring(0, gleich).trim().equals(schluessel))
                    continue;
                wert = zeile.substring(gleich + 1).trim();
                break;
            }
            r.close();
            return wert;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Sucht Qts Einstellungsdatei im eigenen Datenverzeichnis.
     *
     * <p><b>Warum gesucht und nicht angegeben.</b> Am 09.09.2026 stand hier
     * ein geratener Pfad ({@code .config/orangedeck/orangedeck.conf}), und das
     * Miner-Widget meldete daraufhin auf dem Geraet "Adresse in den
     * Einstellungen setzen", obwohl sie gesetzt war. Wo QSettings unter
     * Android wirklich ablegt, haengt an der Qt-Fassung
     * ({@code AppConfigLocation}) und kann sich mit ihr aendern. Ein Pfad, den
     * man nicht nachsehen kann, ist eine Vermutung: die Anwendung ist ein
     * Release-Bau, {@code adb run-as} greift also nicht.
     *
     * <p>Gesucht wird nur im eigenen {@code getFilesDir()}, hoechstens vier
     * Ebenen tief. Das sind eine Handvoll Dateien; die Suche kostet nichts und
     * haelt auch, wenn Qt den Ort verlegt.
     */
    private static File findeEinstellungen(Context c) {
        return suche(c.getFilesDir(), "orangedeck.conf", 4);
    }

    private static File suche(File verzeichnis, String name, int tiefe) {
        if (verzeichnis == null || tiefe < 0 || !verzeichnis.isDirectory())
            return null;
        File[] kinder = verzeichnis.listFiles();
        if (kinder == null)
            return null;
        for (File k : kinder) {
            if (k.isFile() && k.getName().equals(name))
                return k;
        }
        for (File k : kinder) {
            if (k.isDirectory()) {
                File t = suche(k, name, tiefe - 1);
                if (t != null)
                    return t;
            }
        }
        return null;
    }

    /**
     * Die eingestellte Waehrung, aus derselben ini wie die Miner-Adresse.
     *
     * <p><b>Vorgabe ist USD, nicht EUR.</b> Bitcoin wird weltweit in Dollar
     * notiert; Euro ist eine bewusste Wahl und muss gesetzt werden. Dieselbe
     * Vorgabe gilt in der Anwendung, damit Widget und Reiter nicht
     * auseinanderlaufen, wenn niemand etwas eingestellt hat.
     *
     * <p>Die Schluessel sind die aus {@code ui/qml/money.js}: eur, usd, gbp,
     * chf, cad, aud, jpy. {@code /v1/prices} fuehrt genau diese, in
     * Grossbuchstaben.
     */
    protected static String waehrung(Context c) {
        String w = ausEinstellungen(c, "currency");
        if (w == null || w.isEmpty())
            return "usd";
        return w.toLowerCase(java.util.Locale.ROOT);
    }

    /** Der Schluessel in `/v1/prices`: EUR, USD, ... */
    protected static String waehrungSchluessel(Context c) {
        return waehrung(c).toUpperCase(java.util.Locale.ROOT);
    }

    /** Das Zeichen dahinter, wie in `money.js`. */
    protected static String waehrungZeichen(Context c) {
        String w = waehrung(c);
        if (w.equals("eur")) return "€";
        if (w.equals("gbp")) return "£";
        if (w.equals("chf")) return "CHF";
        if (w.equals("cad")) return "CA$";
        if (w.equals("aud")) return "A$";
        if (w.equals("jpy")) return "¥";
        return "$";
    }

    /** Alle Widgets dieser Art sofort auffrischen -- fuer den Aufruf aus der Anwendung. */
    static void anstossen(Context c, Class<? extends DeckWidget> art) {
        AppWidgetManager m = AppWidgetManager.getInstance(c);
        int[] ids = m.getAppWidgetIds(new ComponentName(c, art));
        if (ids == null || ids.length == 0)
            return;
        Intent i = new Intent(c, art);
        i.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids);
        c.sendBroadcast(i);
    }
}
