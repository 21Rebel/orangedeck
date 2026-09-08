// Miner direkt abfragen -- ohne Daemon.
//
// **Warum es die Datei gibt.** Der Miner-Reiter fiel auf Android weg, und die
// Begruendung dafuer stand im Kopf von `DirectFeed.qml`: *"das Geraet steht im
// Heimnetz, da hilft kein Direktbezug."* Das stimmt fuer ein Handy im
// Mobilfunknetz. **Im selben WLAN steht es sehr wohl erreichbar da** -- und
// dort ist ein Handy neben dem Miner genau der Ort, an dem man auf seine
// Hashrate sehen will.
//
// Der Aufbau ist bewusst deckungsgleich mit `poll_miners` und `probe_axeos`
// im Daemon: `FeedState` schiebt beides durch dieselbe Auswertung, und
// `MinerView` merkt nicht, woher die Zahlen kommen.
//
// Was hier **nicht** geht und beim Daemon bleibt:
//   cgminer  -- ein roher TCP-Sockel auf Port 4028. QML hat keine Sockel;
//               das braucht C++ (`QTcpSocket`) und ist ein eigener Schritt.
//   Suchlauf -- `--discover-miners` geht das Subnetz ab, ebenfalls mit
//               Sockeln. Die Adresse kommt hier aus den Einstellungen.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // Die Adressen, wie sie in den Einstellungen stehen.
    property var hosts: []

    // Dieselben Werte wie im Daemon (MINER_INTERVAL, MINER_HISTORY,
    // DOMAIN_SMOOTH). Stehen sie hier anders, laufen die beiden Wege
    // auseinander, und niemand sieht es.
    property int intervalMs: 5000
    property int historyMax: 180
    property int domainSmooth: 12
    property int timeoutMs: 4000

    // --- Ergebnis, in der Form, die `FeedState` erwartet ------------------
    property var miners: []
    property var minerTotal: ({})
    property var minerHistory: ({})

    // Verlauf und Domaenenpuffer je Geraet. Kein `property`, weil daran keine
    // Bindung haengen soll -- die Anzeige liest `minerHistory`, und das wird
    // erst am Ende eines Durchlaufs gesetzt.
    property var __hist: ({})
    property var __dom: ({})

    // '1.23M' -> 1230000. Die Geraete melden die Bestleistung als Text mit
    // Einheit. Wortgleich zu `parse_diff` im Daemon.
    function parseDiff(v) {
        if (typeof v === "number")
            return v;
        if (!v)
            return 0;
        var t = String(v).trim();
        var mult = { "k": 1e3, "K": 1e3, "M": 1e6, "G": 1e9,
                     "T": 1e12, "P": 1e15, "E": 1e18 };
        var f = mult[t.slice(-1)];
        var zahl = parseFloat(f === undefined ? t : t.slice(0, -1));
        if (isNaN(zahl))
            return 0;
        return f === undefined ? zahl : zahl * f;
    }

    // AxeOS meldet GH/s -- hier wird ueberall in H/s gerechnet.
    function gh(v) {
        return typeof v === "number" ? v * 1e9 : null;
    }

    function normalisiere(url, d) {
        // Die Momentanrate schwankt um rund zehn Prozent. Fuer die Anzeige ist
        // der Zehnminutenwert der ehrlichere -- die Momentanrate bleibt
        // daneben stehen.
        var avg = root.gh(d.hashRate_10m) || root.gh(d.hashRate_1m)
                || root.gh(d.hashRate);

        // **Aus der Stratum-Adresse nur den Wirt.** Der Benutzername enthaelt
        // beim Solomining die Auszahlungsadresse -- die hat in keinem
        // Zustand, keiner Anzeige und keinem Protokoll etwas verloren.
        var pool = null;
        if (d.stratumURL) {
            var teile = String(d.stratumURL).split("//");
            pool = teile[teile.length - 1].split("/")[0] || null;
        }

        var asics = (d.hashrateMonitor && d.hashrateMonitor.asics) || [{}];
        return {
            "type": "axeos",
            "id": url,
            "name": d.hostname || d.ASICModel || d.boardVersion || "AxeOS",
            "model": d.ASICModel || d.boardVersion || "",
            "version": d.axeOSVersion || d.version || "",
            "online": true,
            "hashRate": avg || 0,
            "hashRateNow": root.gh(d.hashRate),
            "expected": root.gh(d.expectedHashrate),
            "bestDiff": root.parseDiff(d.bestDiff),
            "bestSessionDiff": root.parseDiff(d.bestSessionDiff),
            "poolDiff": root.parseDiff(d.poolDifficulty),
            "netDiffDevice": root.parseDiff(d.networkDifficulty),
            "blockFound": d.blockFound,
            "errorPct": d.errorPercentage,
            "temp": d.temp,
            "power": d.power,
            "fanRpm": d.fanrpm,
            "shares": d.sharesAccepted,
            "rejected": d.sharesRejected,
            "uptime": d.uptimeSeconds,
            "paused": d.miningPaused,
            "pool": pool,
            "domains": (asics[0] && asics[0].domains) || []
        };
    }

    // **Nicht erreichbar ist kein Fehler, sondern ein Zustand** -- die Geraete
    // sind oft schlicht aus. Derselbe Satz steht im Daemon.
    function unerreichbar(url, grund) {
        return {
            "type": "axeos",
            "id": url,
            "name": url,
            "online": false,
            "error": grund
        };
    }

    function pfad(url) {
        var u = String(url).trim();
        if (u.indexOf("://") < 0)
            u = "http://" + u;
        return u.replace(/\/+$/, "") + "/api/system/info";
    }

    // Ein Durchlauf ueber alle Adressen. Die Antworten kommen einzeln; erst
    // wenn alle da sind (oder abgelaufen), wird das Ergebnis gesetzt -- sonst
    // flackerte die Anzeige bei jedem Geraet einmal.
    function lauf() {
        var liste = root.hosts || [];
        if (!root.active || liste.length === 0) {
            if (root.miners.length > 0) {
                root.miners = [];
                root.minerTotal = ({});
                root.minerHistory = ({});
            }
            return;
        }

        var offen = liste.length;
        var ergebnis = new Array(liste.length);

        for (var i = 0; i < liste.length; i++)
            frage(liste[i], i);

        function frage(url, idx) {
            var req = new XMLHttpRequest();
            var fertig = false;
            var frist = null;
            function ab(satz) {
                // **Die Frist muss auf beiden Wegen weg.** Sie wurde nur im
                // Zeitablauf-Zweig zerstoert; nach einer Antwort lief sie
                // weiter und feuerte spaeter ins Leere. Aufgefallen am
                // 08.09.2026 am doppelten Protokoll -- zu jeder Meldung stand
                // eine zweite, obwohl `ab()` nur die erste annimmt. Bei fuenf
                // Sekunden Takt bleiben so 720 Objekte je Stunde liegen.
                if (frist) {
                    frist.stop();
                    frist.destroy();
                    frist = null;
                }
                if (fertig)
                    return;
                fertig = true;
                ergebnis[idx] = satz;
                offen -= 1;
                if (offen === 0)
                    root.uebernehmen(ergebnis);
            }
            req.onreadystatechange = function () {
                if (req.readyState !== XMLHttpRequest.DONE)
                    return;
                if (req.status !== 200) {
                    ab(root.unerreichbar(url, "HTTP " + req.status));
                    return;
                }
                try {
                    ab(root.normalisiere(url, JSON.parse(req.responseText)));
                } catch (e) {
                    ab(root.unerreichbar(url, String(e)));
                }
            };
            // Eigene Frist: `XMLHttpRequest` in QML kennt kein `timeout`, das
            // sich verlaesslich melden wuerde. Ohne sie bliebe ein Durchlauf
            // haengen, sobald ein Geraet nicht antwortet -- und `offen` ginge
            // nie auf null.
            frist = Qt.createQmlObject(
                'import QtQuick; Timer { }', root, "DirectMiner.frist");
            frist.interval = root.timeoutMs;
            frist.repeat = false;
            frist.triggered.connect(function () {
                req.abort();
                ab(root.unerreichbar(url, "keine Antwort"));
            });
            frist.start();
            try {
                req.open("GET", root.pfad(url));
                req.send();
            } catch (e2) {
                ab(root.unerreichbar(url, String(e2)));
            }
        }
    }

    function uebernehmen(gefunden) {
        var jetzt = Math.round(Date.now() / 1000);
        var live = [];
        var i, m;

        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m)
                continue;
            if (m.online)
                live.push(m);
        }

        // Verlauf fortschreiben. Gerundet abgelegt, wie im Daemon -- der
        // Zustand wird oft geschrieben, da zaehlt jede Stelle.
        var hist = root.__hist;
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online)
                continue;
            var h = hist[m.id];
            if (!h) {
                h = { "t": [], "hr": [], "hrNow": [], "temp": [], "err": [] };
                hist[m.id] = h;
            }
            h.t.push(jetzt);
            h.hr.push(Math.round((m.hashRate || 0) / 1e9 * 10) / 10);
            h.hrNow.push(m.hashRateNow
                         ? Math.round(m.hashRateNow / 1e9 * 10) / 10 : null);
            h.temp.push(m.temp === undefined || m.temp === null
                        ? null : Math.round(m.temp * 10) / 10);
            h.err.push(m.errorPct === undefined || m.errorPct === null
                       ? null : Math.round(m.errorPct * 10) / 10);
            var felder = ["t", "hr", "hrNow", "temp", "err"];
            for (var f = 0; f < felder.length; f++) {
                var arr = h[felder[f]];
                if (arr.length > root.historyMax)
                    arr.splice(0, arr.length - root.historyMax);
            }
        }

        // Hash-Domaenen glaetten -- dieselbe Begruendung wie im Daemon: die
        // Einzelmessung schwankt zu stark, um daraus ein Bild zu machen.
        var dom = root.__dom;
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online || !(m.domains && m.domains.length))
                continue;
            var buf = dom[m.id];
            if (!buf) {
                buf = [];
                dom[m.id] = buf;
            }
            buf.push(m.domains);
            if (buf.length > root.domainSmooth)
                buf.splice(0, buf.length - root.domainSmooth);
            var n = buf[0].length;
            for (var b = 1; b < buf.length; b++)
                n = Math.min(n, buf[b].length);
            var mittel = [];
            for (var k = 0; k < n; k++) {
                var summe = 0;
                for (b = 0; b < buf.length; b++)
                    summe += buf[b][k];
                mittel.push(Math.round(summe / buf.length * 10) / 10);
            }
            m.domainsAvg = mittel;
            m.domainSamples = buf.length;
        }

        // Verlaeufe verschwundener Geraete nicht ewig mitschleppen.
        var bekannt = {};
        for (i = 0; i < gefunden.length; i++)
            if (gefunden[i])
                bekannt[gefunden[i].id] = true;
        var schluessel = Object.keys(hist);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete hist[schluessel[i]];
        schluessel = Object.keys(dom);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete dom[schluessel[i]];

        var beste = 0;
        var summeHr = 0;
        for (i = 0; i < live.length; i++) {
            summeHr += live[i].hashRate || 0;
            beste = Math.max(beste, live[i].bestDiff || 0);
        }

        root.miners = gefunden;
        root.minerTotal = {
            "count": gefunden.length,
            "online": live.length,
            "hashRate": summeHr,
            "bestDiff": beste
        };
        // Neue Kennung, damit die Bindungen anspringen -- ein veraenderter
        // Inhalt derselben Abbildung loest in QML nichts aus.
        var kopie = ({});
        schluessel = Object.keys(hist);
        for (i = 0; i < schluessel.length; i++)
            kopie[schluessel[i]] = hist[schluessel[i]];
        root.minerHistory = kopie;
    }

    onHostsChanged: {
        root.__hist = ({});
        root.__dom = ({});
        root.lauf();
    }

    Timer {
        interval: root.intervalMs
        running: root.active && (root.hosts || []).length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.lauf()
    }
}
