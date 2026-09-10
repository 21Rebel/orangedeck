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
    // Der Verlauf, den das Geraet selbst fuehrt, je Adresse -- siehe
    // `holeStatistik`.
    property var __geraet: ({})

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
            // Sekunden zwischen zwei Eintraegen in der eigenen Aufzeichnung
            // des Geraets; 0 heisst: es zeichnet nicht auf.
            "statsFrequency": d.statsFrequency || 0,
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

    function basis(url) {
        var u = String(url).trim();
        if (u.indexOf("://") < 0)
            u = "http://" + u;
        return u.replace(/\/+$/, "");
    }

    function pfad(url) {
        return root.basis(url) + "/api/system/info";
    }

    // **Den Verlauf fuehrt das Geraet, wenn man es laesst.** AxeOS ab 2.x
    // schreibt selbst mit, sobald `statsFrequency` gesetzt ist -- bis zu
    // `statsLimit` Eintraege, auf dem Bitaxe am 10.09.2026 720.
    //
    // **`statsFrequency` ist nicht der Takt, sondern die Zielspanne.** Am
    // selben Tag auf 60 gesetzt, kamen die Eintraege trotzdem im
    // Sekundentakt. ESP-Miner (main/tasks/statistics_task.c) misst immer
    // jede Sekunde; ist der Puffer voll, duennt es aeltere Eintraege aus,
    // bis die Spanne `statsLimit * statsFrequency` erreicht ist -- hier
    // zwoelf Stunden, hinten dichter als vorn. Der Verlauf waechst also nach
    // dem Einschalten ueber zwoelf Stunden an, und die Abstaende sind
    // ungleich; MinerChart zeichnet deshalb nach den Zeitstempeln. Selbst mitgeschrieben hat sie nur, solange
    // sie offen war: nach jedem Start drei Punkte und drei gerade Striche,
    // am 10.09.2026 als "nicht aussagekraeftig" gemeldet.
    //
    // Nur die vier Spalten, die der Graph braucht: `columns` grenzt die
    // Antwort ein, der Zeitstempel kommt immer mit. Die Reihenfolge der
    // Spalten bestimmt das Geraet, nicht die Anfrage -- also nach `labels`
    // lesen.
    //
    // Der Zeitstempel zaehlt Millisekunden seit dem Start des Geraets, und
    // `currentTimestamp` ist dieselbe Uhr jetzt. Die Differenz ist das Alter
    // des Eintrags; eine Weltzeit kennt der Miner dafuer nicht.
    function holeStatistik(url, jetzt) {
        var g = root.__geraet[url] || { "geholt": 0, "laeuft": 0 };
        root.__geraet[url] = g;
        // Eine Anfrage, die nie zurueckkam, sperrt nicht fuer immer.
        if (g.laeuft && jetzt - g.laeuft < 30)
            return;
        g.laeuft = jetzt;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            g.laeuft = 0;
            g.geholt = jetzt;
            if (req.status !== 200)
                return;
            try {
                var d = JSON.parse(req.responseText);
                var lab = d.labels || [];
                var zeilen = d.statistics || [];
                var iT = lab.indexOf("timestamp"), iHr = lab.indexOf("hashrate"),
                    iHr10 = lab.indexOf("hashrate_10m"), iTemp = lab.indexOf("asicTemp"),
                    iErr = lab.indexOf("errorPercentage");
                if (iT < 0 || !d.currentTimestamp)
                    return;
                var r = { "t": [], "hr": [], "hrNow": [], "temp": [], "err": [] };
                var nun = Date.now() / 1000;
                function zahl(z, i, stellen) {
                    if (i < 0 || typeof z[i] !== "number")
                        return null;
                    var f = Math.pow(10, stellen);
                    return Math.round(z[i] * f) / f;
                }
                for (var k = 0; k < zeilen.length; k++) {
                    var z = zeilen[k];
                    r.t.push(Math.round(nun - (d.currentTimestamp - z[iT]) / 1000));
                    r.hr.push(zahl(z, iHr10 >= 0 ? iHr10 : iHr, 1));
                    r.hrNow.push(zahl(z, iHr, 1));
                    r.temp.push(zahl(z, iTemp, 1));
                    r.err.push(zahl(z, iErr, 1));
                }
                g.reihe = r;
            } catch (e) {
                // Keine Statistik ist kein Fehler: dann bleibt es beim
                // eigenen Mitschreiben.
            }
        };
        try {
            req.open("GET", root.basis(url)
                     + "/api/system/statistics?columns=hashrate,hashrate_10m,asicTemp,errorPercentage");
            req.send();
        } catch (e2) {
            g.laeuft = 0;
        }
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

        // Den Verlauf des Geraets auffrischen, so oft es neue Eintraege
        // haben kann -- hoechstens jede Minute. Die Antwort kommt erst im
        // naechsten Durchlauf zum Tragen.
        for (i = 0; i < gefunden.length; i++) {
            m = gefunden[i];
            if (!m || !m.online || !(m.statsFrequency > 0))
                continue;
            var gg = root.__geraet[m.id];
            if (!gg || jetzt - gg.geholt >= Math.max(60, m.statsFrequency))
                root.holeStatistik(m.id, jetzt);
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
        schluessel = Object.keys(root.__geraet);
        for (i = 0; i < schluessel.length; i++)
            if (!bekannt[schluessel[i]])
                delete root.__geraet[schluessel[i]];

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
        // **Auch die Arrays kopieren, nicht nur die Abbildung.** QML
        // vergleicht Arrays nach Kennung, nicht nach Inhalt -- und
        // `MinerChart` zeichnet neu bei `onHrChanged`:
        //
        //     readonly property var hr: (hist && hist.hr) || []
        //     onHrChanged: canvas.requestPaint()
        //
        // Wer in dasselbe Array hineinschiebt, aendert dessen Kennung nicht.
        // Damit feuerte `onHrChanged` nie, die Leinwand zeichnete nie, und
        // der Graph blieb **leer** -- am 08.09.2026 auf einem Galaxy A55
        // gemeldet ("kerzengerade").
        //
        // Der Daemon-Weg fiel nicht auf, weil dort jede Abfrage ein frisches
        // JSON-Objekt liefert: neue Arrays, neue Kennung, Neuzeichnen.
        //
        // Fuenf Arrays von hoechstens 180 Zahlen alle fuenf Sekunden zu
        // kopieren kostet nichts, was messbar waere.
        //
        // Fuehrt das Geraet einen Verlauf, ist er die Grundlage, und die
        // eigenen Punkte kommen nur fuer die Zeit nach seinem letzten
        // Eintrag dazu: dort liegt der aktuelle Stand, den es noch nicht
        // aufgeschrieben hat.
        var kopie = ({});
        var felderKopie = ["t", "hr", "hrNow", "temp", "err"];
        schluessel = Object.keys(hist);
        for (i = 0; i < schluessel.length; i++) {
            var q = hist[schluessel[i]];
            var g2 = root.__geraet[schluessel[i]];
            var basisReihe = g2 && g2.reihe && g2.reihe.t.length >= 2 ? g2.reihe : null;
            var ab = 0;
            if (basisReihe) {
                var letzte = basisReihe.t[basisReihe.t.length - 1];
                while (ab < q.t.length && q.t[ab] <= letzte)
                    ab++;
            }
            var z = ({});
            for (var fk = 0; fk < felderKopie.length; fk++) {
                var eigen = (q[felderKopie[fk]] || []).slice(ab);
                z[felderKopie[fk]] = basisReihe
                    ? basisReihe[felderKopie[fk]].concat(eigen) : eigen;
            }
            kopie[schluessel[i]] = z;
        }
        root.minerHistory = kopie;
    }

    // **Auf den Inhalt sehen, nicht auf die Kennung.** `minerHosts` wird aus
    // `minerHostsRaw` gerechnet und gibt bei jeder Auswertung ein **neues**
    // Array zurueck. QML vergleicht Arrays nach Kennung, nicht nach Inhalt --
    // also feuerte `onHostsChanged` bei jeder Neuauswertung der Bindung, und
    // jedes Mal lief ein Durchlauf an.
    //
    // Gemessen am 08.09.2026: die Zeitachse des Verlaufs sagte "60 Min" nach
    // zweieinhalb Minuten Laufzeit -- also rund fuenf Abfragen je Sekunde
    // statt einer alle fuenf. **Die Kurve war dadurch kerzengerade**, denn die
    // Werte lagen Millisekunden auseinander. Dazu fragte es den Miner
    // fuenfundzwanzigmal so oft ab wie gemeint.
    //
    // Der Verlauf wird nur geleert, wenn sich die Liste wirklich geaendert
    // hat; sonst waere er bei jeder Neuauswertung weg.
    // Die Liste als **Zeichenkette**. Alles, was sonst an `hosts` haengen
    // wuerde, haengt daran: Zeichenketten vergleicht QML nach Inhalt, Arrays
    // nach Kennung.
    property string hostsKey: ""

    onHostsChanged: {
        var jetzt = (root.hosts || []).join("|");
        if (jetzt === root.hostsKey)
            return;
        root.hostsKey = jetzt;
        root.__hist = ({});
        root.__dom = ({});
        root.__geraet = ({});
        root.lauf();
    }

    Timer {
        interval: root.intervalMs
        // **Nicht `root.hosts` in dieser Bedingung.** Das Array ist bei jeder
        // Auswertung ein neues Objekt, `running` wurde also neu zugewiesen --
        // und eine neu gestartete Uhr mit `triggeredOnStart` feuert sofort.
        // Damit loeste jede Neuauswertung eine Abfrage aus.
        //
        // Am 08.09.2026 gemessen: die Zeitachse des Verlaufs sagte "60 Min"
        // nach zweieinhalb Minuten Laufzeit, also rund fuenf Abfragen je
        // Sekunde statt einer alle fuenf. **Die Kurve war dadurch
        // kerzengerade** -- die Werte lagen Millisekunden auseinander -- und
        // der Miner wurde fuenfundzwanzigmal so oft gefragt wie gemeint.
        //
        // `hostsKey` ist eine Zeichenkette und wird nach Inhalt verglichen.
        running: root.active && root.hostsKey.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.lauf()
    }
}
