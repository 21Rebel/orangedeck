package dev.orangedeck.OrangeDeck;

import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.PersistableBundle;
import android.util.Log;

/**
 * Ein zweiter Versuch fuer ein Widget, dessen Abruf gescheitert ist.
 *
 * <p><b>Warum es das gibt.</b> Am 16.09.2026 um 08:53 wurde das APK bei
 * gesperrtem Galaxy installiert. Alle Widgets holten sofort, keins kam durch,
 * alle zeigten "gerade nicht erreichbar" -- und so blieb es bis 09:54, obwohl
 * die Anwendung um 09:47 im selben Netz Daten hatte. Nach einem Fehlschlag
 * gab es keinen Versuch bis zum naechsten Takt von {@code updatePeriodMillis},
 * und den liefert Android bei ruhendem Geraet verspaetet oder gar nicht.
 *
 * <p><b>JobScheduler, nicht AlarmManager.</b> Ein Job mit
 * {@code NETWORK_TYPE_ANY} laeuft erst, wenn Netz da ist, und bekommt dann
 * auch Netz -- ein Wecker liefe womoeglich wieder in dieselbe Sperre.
 *
 * <p><b>Begrenzt, je Widget-Art.</b> Das Miner-Widget scheitert ausser Haus
 * jedes Mal, und mempool.space antwortete am 15.09. einem VPN-Ausgang gar
 * nicht. Deshalb: Abstand 1, 2, 4, 8, 16 Minuten, nach fuenf Fehlschlaegen
 * Schluss bis zum naechsten Erfolg oder Takt. Ein Erfolg setzt den Zaehler
 * zurueck. Angestossen wird nur die Art, die scheiterte, nicht alle zehn.
 */
public class WidgetNachholen extends JobService {

    private static final String TAG = "OrangeDeck";
    private static final String ART = "art";
    private static final int VERSUCHE = 5;

    @Override
    public boolean onStartJob(JobParameters p) {
        String name = p.getExtras().getString(ART);
        try {
            Class<? extends DeckWidget> art = Class.forName(name).asSubclass(DeckWidget.class);
            Log.i(TAG, "Widget nachholen: " + art.getSimpleName());
            DeckWidget.anstossen(getApplicationContext(), art);
        } catch (Exception e) {
            Log.w(TAG, "Widget nachholen: " + name + ": " + e);
        }
        return false;
    }

    @Override
    public boolean onStopJob(JobParameters p) {
        return false;
    }

    private static SharedPreferences stand(Context c) {
        return c.getSharedPreferences("widget_nachholen", Context.MODE_PRIVATE);
    }

    private static int jobId(Class<?> art) {
        // Fester Bereich, damit keine Kennung eines anderen Jobs getroffen wird
        return 0x0D000000 | (art.getName().hashCode() & 0xFFFF);
    }

    /** Nach einem Fehlschlag: einen Versuch einplanen, wenn noch keiner wartet. */
    static void einplanen(Context c, Class<? extends DeckWidget> art) {
        JobScheduler js = (JobScheduler) c.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (js == null)
            return;
        int id = jobId(art);
        if (js.getPendingJob(id) != null)
            return;
        String k = art.getName();
        int n = stand(c).getInt(k, 0);
        if (n >= VERSUCHE) {
            Log.i(TAG, "Widget " + art.getSimpleName() + ": " + n + " Fehlschlaege, kein weiterer Versuch");
            return;
        }
        stand(c).edit().putInt(k, n + 1).apply();
        PersistableBundle extras = new PersistableBundle();
        extras.putString(ART, k);
        long abstand = 60_000L << n;
        js.schedule(new JobInfo.Builder(id, new ComponentName(c, WidgetNachholen.class))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setMinimumLatency(abstand)
                .setExtras(extras)
                .build());
        Log.i(TAG, "Widget " + art.getSimpleName() + ": Versuch " + (n + 1) + " in "
                   + (abstand / 60_000) + " min, sobald Netz da ist");
    }

    /** Nach einem Erfolg: Zaehler zurueck, wartender Versuch entfaellt. */
    static void erledigt(Context c, Class<? extends DeckWidget> art) {
        if (stand(c).getInt(art.getName(), 0) == 0)
            return;
        stand(c).edit().remove(art.getName()).apply();
        JobScheduler js = (JobScheduler) c.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (js != null)
            js.cancel(jobId(art));
    }
}
