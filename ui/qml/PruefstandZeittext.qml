// Pruefstand: nur die Beschriftung des eigenen Zeitraums.
import QtQuick

Item {
    MarketView {
        id: m

        lang: "de"
    }

    Component.onCompleted: {
        var faelle = [
            [733000, "der Fall aus dem Bild (12215m)"],
            [60, "eine Minute"], [1800, "halbe Stunde"], [3599, "knapp eine Stunde"],
            [3600, "eine Stunde"], [5400, "anderthalb Stunden"], [129600, "36 Stunden"],
            [172800, "zwei Tage"], [259200, "drei Tage"], [734400, "8,5 Tage"],
            [2592000, "30 Tage"], [3888000, "45 Tage"], [5184000, "60 Tage"],
            [7776000, "90 Tage"], [15552000, "180 Tage"], [31535999, "knapp ein Jahr"],
            [31536000, "ein Jahr"], [47304000, "anderthalb Jahre"],
            [94608000, "drei Jahre"], [289000000, "gut neun Jahre"]
        ];
        for (var i = 0; i < faelle.length; i++) {
            var sek = faelle[i][0];
            var text = m.eigenText(sek);
            var zurueck = m.eigenSekunden(text);
            var abw = sek > 0 ? Math.round(100 * Math.abs(zurueck - sek) / sek) : 0;
            console.warn(("        " + sek).slice(-10) + " s  ->  "
                         + (text + "        ").slice(0, 8)
                         + "  zurueck " + (("       " + zurueck).slice(-10))
                         + " s (" + abw + " %)   " + faelle[i][1]);
        }
        Qt.quit();
    }
}
