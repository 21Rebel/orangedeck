// Direktbezug fuer den Markt: Kerzen, Band, Liquidationen und Heatmap ohne
// Dienst.
//
// **Warum es die Datei gibt.** Bis zum 13.09.2026 gab es den Markt nur ueber
// den Dienst, auch auf dem Telefon -- dort ueber "Dienst auf einem anderen
// Geraet". Der Geraetelauf an dem Tag zeigte die Schwaeche: ein Rechner im
// selben WLAN, ein geoeffneter Port, und schon ein VPN am Telefon liess die
// App den Dienst nicht erreichen, waehrend die Shell auf demselben Geraet
// durchkam. Unterwegs geht es ohnehin nicht.
//
// **Die Antworten sind deckungsgleich mit dem Dienst** (`/market`,
// `/market/overview`, `/market/heatmap` in `daemon/orangedeck`). `FeedState`
// reicht `getJson` hierher durch, und die Ansichten merken den Unterschied
// nicht -- dieselbe Linie wie bei `DirectFeed`.
//
// Was hier anders ist als beim Dienst, und warum:
//
//   Liquidationen  Der Dienst hoert rund um die Uhr zu und haelt zwei Tage.
//                  Hier gibt es nur, was seit dem Oeffnen der Ansicht kam --
//                  **und** den letzten Tag von OKX: `liquidation-orders` gibt
//                  es auch per REST, am 13.09.2026 gemessen 402 Eintraege ueber
//                  rund 23 Stunden, danach ist die Liste zu Ende. Binance hat
//                  `allForceOrders` abgeschaltet (404), Bybit hat keinen Weg.
//   Band, Trades   Nur solange die Ansicht offen ist, wie beim Dienst auch.
//   Heatmap        Braucht nichts Gesammeltes: Kerzen und der Verlauf des
//                  offenen Interesses kommen beide per REST.
//
// **Eigene Datei**, aus demselben Grund wie `DirectFeed`: `import QtWebSockets`
// gibt es nicht ueberall, und als Loader faellt dann nur der Markt aus.
import QtQuick
import QtWebSockets

Item {
    id: root

    visible: false

    property bool active: true
    // Kurse von mempool.space, wie `DirectFeed` sie sammelt: {usd, eur, ...}.
    // Daraus der Umrechnungsfaktor -- derselbe Weg wie `markt_kurs()` im Dienst.
    property var preise: ({})

    // -- Konstanten, gleich wie im Dienst ------------------------------------
    readonly property int linger: 120          // MARKET_LINGER
    readonly property int tapeMin: 1000        // MARKET_TAPE_MIN, Dollar
    readonly property int tapeKeep: 400        // MARKET_TAPE_KEEP
    readonly property int liqSekunden: 172800  // LIQ_SEKUNDEN, zwei Tage
    readonly property int liqKeep: 20000       // LIQ_KEEP
    readonly property int oiMaxTage: 30        // OI_MAX_TAGE
    readonly property real okxKontrakt: 0.01   // BTC je Kontrakt BTC-USDT-SWAP
    readonly property int timeoutMs: 20000

    readonly property var spans: ({
        "1h": ["1m", 60], "12h": ["5m", 144], "24h": ["15m", 96],
        "7d": ["1h", 168], "30d": ["4h", 180], "1y": ["1d", 365],
        "all": ["1w", 1000]
    })
    readonly property var ladder: [["1m", 60], ["3m", 180], ["5m", 300],
        ["15m", 900], ["30m", 1800], ["1h", 3600], ["2h", 7200], ["4h", 14400],
        ["6h", 21600], ["12h", 43200], ["1d", 86400], ["3d", 259200],
        ["1w", 604800]]
    readonly property var kerzenTtl: ({
        "1m": 20, "5m": 60, "15m": 120, "1h": 300, "4h": 600, "1d": 1800,
        "1w": 3600
    })
    // Die Annahmen der Heatmap -- erfunden, nicht gemessen, siehe
    // `HEBEL_STUFEN` im Dienst. Sie gehen mit der Antwort hinaus.
    readonly property var hebel: [[5, 0.30], [10, 0.30], [25, 0.20], [50, 0.13], [100, 0.07]]
    readonly property real longAnteil: 0.5
    readonly property var oiRaster: [["5m", 300], ["15m", 900], ["30m", 1800],
        ["1h", 3600], ["2h", 7200], ["4h", 14400], ["6h", 21600],
        ["12h", 43200], ["1d", 86400]]

    // -- innerer Zustand ------------------------------------------------------
    property real __gefragt: 0
    property bool __erwuenscht: false
    readonly property bool laeuft: root.active && root.__erwuenscht

    property var __band: []
    property int __bandNr: 0
    property real __trades: 0

    // [ts, preis, menge, istLong, quelle]
    property var __liq: []
    property bool __liqUnsortiert: false
    property var __liqGesehen: ({})
    property int __liqGesehenZahl: 0
    property real __liqSeit: 0
    property real __bybitSeit: 0    // erstes Verbinden, Bybit hat keinen Rueckgriff
    property real __nachgeholt: 0

    property var __puffer: ({})     // url -> {t, d}
    property int __pufferZahl: 0
    property var __wartend: ({})    // url -> [done, ...]

    property var __ratio: []
    property real __ratioT: 0
    property bool __ratioLaeuft: false

    property var __ueb: ({ "t": 0, "d": [] })
    property var __uebWartend: null

    // -- Einstieg ---------------------------------------------------------------
    function getJson(pfad, done) {
        var a = root.__abfrage(pfad);
        if (a.pfad === "/market")
            root.__markt(a.q, done);
        else if (a.pfad === "/market/overview")
            root.__overview(a.q, done);
        else if (a.pfad === "/market/heatmap")
            root.__heat(a.q, done);
        else
            done(null, "im Direktbezug nicht verfuegbar");
    }

    // -- kleine Helfer ------------------------------------------------------------
    function __r(x, stellen) {
        var f = Math.pow(10, stellen);
        return Math.round(x * f) / f;
    }

    function __jetzt() {
        return Date.now() / 1000;
    }

    function __abfrage(pfad) {
        var i = pfad.indexOf("?");
        var q = {};
        if (i >= 0) {
            var teile = pfad.substring(i + 1).split("&");
            for (var k = 0; k < teile.length; k++) {
                var j = teile[k].indexOf("=");
                if (j > 0)
                    q[teile[k].substring(0, j)] = decodeURIComponent(teile[k].substring(j + 1));
            }
        }
        return { "pfad": i >= 0 ? pfad.substring(0, i) : pfad, "q": q };
    }

    function __ganz(v) {
        var n = parseInt(v, 10);
        return isNaN(n) ? 0 : n;
    }

    function __waehrung(q) {
        var c = String(q.cur || "");
        return /^[A-Za-z]{3}$/.test(c) ? c.toLowerCase() : "usd";
    }

    // [faktor, umgerechnet] -- `markt_kurs()` im Dienst
    function __kurs(cur) {
        if (cur === "usd")
            return [1.0, false];
        var p = root.preise || {};
        if (p[cur] && p.usd)
            return [p[cur] / p.usd, true];
        return [1.0, false];
    }

    // -- HTTP -----------------------------------------------------------------
    Component {
        id: fristC

        Timer {
            repeat: false
        }
    }

    // Eine Abfrage, JSON zurueck. **Laeuft dieselbe URL schon, haengt sich der
    // zweite Aufrufer an** -- die Ansicht fragt im Sekundentakt, eine langsame
    // Boerse wuerde sonst Anfragen stapeln.
    function __hol(url, done) {
        var liste = root.__wartend[url];
        if (liste) {
            liste.push(done);
            return;
        }
        root.__wartend[url] = [done];
        var req = new XMLHttpRequest();
        var fertig = false;
        // Eigene Frist, wie in `DirectMiner`: `XMLHttpRequest` in QML kennt
        // kein verlaessliches `timeout`. Und sie muss auf beiden Wegen weg.
        var frist = fristC.createObject(root, { "interval": root.timeoutMs });
        function ab(obj, err) {
            if (frist) {
                frist.stop();
                frist.destroy();
                frist = null;
            }
            if (fertig)
                return;
            fertig = true;
            var wer = root.__wartend[url] || [];
            delete root.__wartend[url];
            for (var i = 0; i < wer.length; i++)
                wer[i](obj, err);
        }
        frist.triggered.connect(function () {
            req.abort();
            ab(null, "keine Antwort");
        });
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            if (req.status !== 200) {
                ab(null, "HTTP " + req.status);
                return;
            }
            try {
                ab(JSON.parse(req.responseText), null);
            } catch (e) {
                ab(null, "Antwort nicht lesbar");
            }
        };
        frist.start();
        try {
            req.open("GET", url);
            req.send();
        } catch (e2) {
            ab(null, String(e2));
        }
    }

    // Gepuffert und schon umgeformt. Faellt die Quelle aus, kommt der letzte
    // Stand zurueck -- ein alter Kurs ist besser als ein leeres Bild.
    function __gepuffert(url, ttl, umformen, done) {
        var e = root.__puffer[url];
        if (e && root.__jetzt() - e.t < ttl) {
            done(e.d, null);
            return;
        }
        root.__hol(url, function (roh, err) {
            if (roh !== null && !err) {
                var d = umformen(roh);
                // Fenster in der Vergangenheit sind je Zug eine eigene URL.
                // Eine grobe Grenze reicht, damit das nicht endlos waechst.
                if (!root.__puffer[url] && ++root.__pufferZahl > 300) {
                    root.__puffer = {};
                    root.__pufferZahl = 1;
                }
                root.__puffer[url] = { "t": root.__jetzt(), "d": d };
                done(d, null);
            } else if (e) {
                done(e.d, null);
            } else {
                done(null, err);
            }
        });
    }

    // -- Kerzen -----------------------------------------------------------------
    // `raster_fuer()` (grenze 400) und `raster_heat()` (grenze 200) im Dienst
    function __rasterFuer(sekunden, grenze) {
        for (var i = 0; i < root.ladder.length; i++) {
            var laenge = root.ladder[i][1];
            if (sekunden / laenge <= grenze)
                return [root.ladder[i][0], Math.max(20, Math.min(1000, Math.round(sekunden / laenge)))];
        }
        return ["1w", 1000];
    }

    // [t, o, h, l, c, kauf, verkauf] -- Feld 9 bei Binance ist das Volumen der
    // Kaeufe, der Rest ist verkauft. Daran haengt der CVD.
    function __kerzenAus(roh) {
        var aus = [];
        for (var i = 0; i < (roh || []).length; i++) {
            var k = roh[i];
            var vol = Number(k[5]);
            var kauf = Number(k[9]);
            var o = Number(k[1]), h = Number(k[2]), l = Number(k[3]), c = Number(k[4]);
            if (isNaN(vol) || isNaN(kauf) || isNaN(o) || isNaN(h) || isNaN(l) || isNaN(c))
                continue;
            aus.push([Math.floor(Number(k[0]) / 1000), root.__r(o, 2), root.__r(h, 2),
                      root.__r(l, 2), root.__r(c, 2), root.__r(kauf, 3),
                      root.__r(Math.max(0, vol - kauf), 3)]);
        }
        return aus;
    }

    function __kerzen(raster, anzahl, von, bis, done) {
        var url = "https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval="
                + raster + "&limit=" + Math.min(1000, anzahl);
        if (von && bis && bis > von)
            url += "&startTime=" + Math.floor(von) * 1000 + "&endTime=" + Math.floor(bis) * 1000;
        else if (bis)
            url += "&endTime=" + Math.floor(bis) * 1000;
        // Vergangenes ist abgeschlossen -- eine Stunde Puffer schadet dort nicht
        var ttl = (bis && bis < root.__jetzt() - 120) ? 3600 : (root.kerzenTtl[raster] || 60);
        root.__gepuffert(url, ttl, root.__kerzenAus, function (d, err) {
            done(d || [], err);
        });
    }

    // Tageskerzen seit 2017, vier Seiten zu je 1000 -- `uebersicht()`
    function __uebersicht(done) {
        if (root.__ueb.d.length && root.__jetzt() - root.__ueb.t < 1800) {
            done(root.__ueb.d, null);
            return;
        }
        if (root.__uebWartend) {
            root.__uebWartend.push(done);
            return;
        }
        root.__uebWartend = [done];
        var aus = [];
        function ende(err) {
            var wer = root.__uebWartend || [];
            root.__uebWartend = null;
            // Bricht eine Seite ab, bleibt der alte Stand -- eine halbe
            // Geschichte waere ein falscher Schieber.
            if (!err)
                root.__ueb = { "t": root.__jetzt(), "d": aus };
            var d = root.__ueb.d;
            for (var i = 0; i < wer.length; i++)
                wer[i](d, d.length ? null : err);
        }
        function seite(start) {
            if (start >= root.__jetzt() || aus.length >= 6000) {
                ende(null);
                return;
            }
            root.__hol("https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=1d&limit=1000&startTime="
                       + start * 1000, function (roh, err) {
                if (err || !roh) {
                    ende(err || "leer");
                    return;
                }
                if (!roh.length) {
                    ende(null);
                    return;
                }
                aus = aus.concat(root.__kerzenAus(roh));
                // Die naechste Seite beginnt einen Tag nach der letzten Kerze
                var weiter = Math.floor(Number(roh[roh.length - 1][0]) / 1000) + 86400;
                if (weiter <= start)
                    ende(null);
                else
                    seite(weiter);
            });
        }
        seite(1501459200);    // 31.07.2017, der erste Handelstag bei Binance
    }

    // -- Long/Short-Verhaeltnis -------------------------------------------------
    // Drei Quellen nebeneinander; fertig ist es, wenn alle drei geantwortet
    // haben. Bis dahin gilt der letzte Stand -- `/market` wartet nicht darauf.
    function __ratioAuffrischen() {
        if (root.__ratioLaeuft || (root.__ratio.length && root.__jetzt() - root.__ratioT < 300))
            return;
        root.__ratioLaeuft = true;
        var aus = [], offen = 3;
        function geordnet() {
            var rang = { "okx": 0, "bybit": 1, "binance": 2 };
            var k = aus.map(function (x) {
                return { "id": x.id, "name": x.name, "long": root.__r(Math.max(0, Math.min(1, x.long)), 4) };
            });
            k.sort(function (a, b) {
                return rang[a.id] - rang[b.id];
            });
            return k;
        }
        // **Zwischenstaende, solange noch weniger da ist.** Bis zum 15.09.2026
        // galt die Liste erst, wenn alle drei geantwortet hatten -- beim
        // Oeffnen stand der Balken also so lange leer wie die langsamste
        // Boerse brauchte, bei einer haengenden bis zur Frist von 20 s. Ein
        // spaeteres Auffrischen ersetzt eine volle Liste nicht durch eine halbe.
        function fertig() {
            if (--offen > 0) {
                if (aus.length > root.__ratio.length)
                    root.__ratio = geordnet();
                return;
            }
            root.__ratioLaeuft = false;
            // Fielen alle aus, wird beim naechsten Mal neu gefragt
            if (aus.length) {
                root.__ratio = geordnet();
                root.__ratioT = root.__jetzt();
            }
        }
        root.__hol("https://www.okx.com/api/v5/rubik/stat/contracts/long-short-account-ratio?ccy=BTC&period=5m",
                   function (d) {
            try {
                // OKX gibt das Verhaeltnis long/short, nicht die Anteile
                var v = Number(d.data[0][1]);
                if (!isNaN(v))
                    aus.push({ "id": "okx", "name": "OKX", "long": v / (1 + v) });
            } catch (e) {}
            fertig();
        });
        root.__hol("https://api.bybit.com/v5/market/account-ratio?category=linear&symbol=BTCUSDT&period=5min&limit=1",
                   function (d) {
            try {
                var v = Number(d.result.list[0].buyRatio);
                if (!isNaN(v))
                    aus.push({ "id": "bybit", "name": "Bybit", "long": v });
            } catch (e) {}
            fertig();
        });
        root.__hol("https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=BTCUSDT&period=5m&limit=1",
                   function (d) {
            try {
                var v = Number(d[d.length - 1].longAccount);
                if (!isNaN(v))
                    aus.push({ "id": "binance", "name": "Binance", "long": v });
            } catch (e) {}
            fertig();
        });
    }

    // -- Trades und Band --------------------------------------------------------
    function __trade(ts, preis, menge, kauf, quelle) {
        if (!(preis > 0) || !(menge > 0))
            return;
        root.__trades += 1;
        var wert = preis * menge;
        if (wert < root.tapeMin)
            return;
        root.__bandNr += 1;
        root.__band.push([root.__bandNr, root.__r(ts, 2), root.__r(preis, 2),
                          Math.round(wert), kauf ? 1 : 0, quelle]);
        if (root.__band.length > root.tapeKeep)
            root.__band.splice(0, root.__band.length - root.tapeKeep);
    }

    // `band_seit()`: was nach `nr` kam, hoechstens die juengsten 120
    function __bandSeit(nr) {
        var b = root.__band;
        var i = b.length;
        while (i > 0 && b[i - 1][0] > nr)
            i--;
        var neu = b.slice(Math.max(i, b.length - 120));
        return [neu, b.length ? b[b.length - 1][0] : 0];
    }

    function __binanceNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        // `m` heisst "der Kaeufer war Maker" -- angegriffen hat dann ein Verkaeufer
        if (m.e === "aggTrade")
            root.__trade(Number(m.T) / 1000, Number(m.p), Number(m.q), !m.m, "binance");
    }

    function __bybitNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (String(m.topic || "").indexOf("publicTrade") !== 0)
            return;
        var d = m.data || [];
        for (var i = 0; i < d.length; i++)
            root.__trade(Number(d[i].T) / 1000, Number(d[i].p), Number(d[i].v), d[i].S === "Buy", "bybit");
    }

    // -- Liquidationen ------------------------------------------------------------
    function __liqAdd(ts, preis, menge, istLong, quelle) {
        if (!(preis > 0) || !(menge > 0) || isNaN(ts))
            return;
        // OKX schiebt beim Verbinden Zurueckliegendes nach, und der Rueckgriff
        // per REST liefert dieselben Eintraege noch einmal
        var schluessel = root.__r(ts, 3) + "|" + root.__r(preis, 2) + "|" + root.__r(menge, 6) + "|" + quelle;
        if (root.__liqGesehen[schluessel])
            return;
        root.__liqGesehen[schluessel] = true;
        if (++root.__liqGesehenZahl > root.liqKeep * 2) {
            root.__liqGesehen = {};
            root.__liqGesehenZahl = 0;
        }
        var l = root.__liq;
        if (l.length && l[l.length - 1][0] > ts)
            root.__liqUnsortiert = true;
        l.push([root.__r(ts, 2), root.__r(preis, 2), root.__r(menge, 6), istLong ? 1 : 0, quelle]);
    }

    function __liqAufraeumen() {
        var l = root.__liq;
        if (root.__liqUnsortiert) {
            l.sort(function (a, b) {
                return a[0] - b[0];
            });
            root.__liqUnsortiert = false;
        }
        var grenze = root.__jetzt() - root.liqSekunden;
        var weg = 0;
        while (weg < l.length && l[weg][0] < grenze)
            weg++;
        weg = Math.max(weg, l.length - root.liqKeep);
        if (weg > 0)
            l.splice(0, weg);
        // Was vor der Grenze lag, ist weg -- `seit` rueckt mit, wie im Dienst
        if (root.__liqSeit && root.__liqSeit < grenze)
            root.__liqSeit = Math.floor(grenze);
    }

    // `fenster()`: bei mehr als 400 die groessten, wieder nach Zeit sortiert
    function __liqFenster(von, bis) {
        var drin = [];
        for (var i = 0; i < root.__liq.length; i++) {
            var x = root.__liq[i];
            if (x[0] >= von && x[0] <= bis)
                drin.push(x);
        }
        if (drin.length > 400) {
            drin.sort(function (a, b) {
                return b[1] * b[2] - a[1] * a[2];
            });
            drin = drin.slice(0, 400);
            drin.sort(function (a, b) {
                return a[0] - b[0];
            });
        }
        return drin;
    }

    // `histogramm()`: auch die leeren Stufen gehen mit, sonst ist die
    // Preisachse keine Achse mehr
    function __liqHist(von, bis, tief, hoch) {
        var stufen = 24;
        if (hoch <= tief)
            return [];
        var breite = (hoch - tief) / stufen;
        var eimer = [];
        var i;
        for (i = 0; i < stufen; i++)
            eimer.push([0, 0]);
        for (i = 0; i < root.__liq.length; i++) {
            var x = root.__liq[i];
            if (x[0] < von || x[0] > bis || x[1] < tief || x[1] > hoch)
                continue;
            var s = Math.min(stufen - 1, Math.floor((x[1] - tief) / breite));
            eimer[s][x[3] ? 0 : 1] += x[1] * x[2];
        }
        var aus = [];
        for (i = 0; i < stufen; i++)
            aus.push([root.__r(tief + (i + 0.5) * breite, 2), Math.round(eimer[i][0]), Math.round(eimer[i][1])]);
        return aus;
    }

    function __okxEintraege(daten) {
        var aeltest = 0;
        for (var b = 0; b < (daten || []).length; b++) {
            // Der Kanal schuettet alle Swaps aus, `instFamily` wirkt dort nicht
            if (daten[b].instId && daten[b].instId !== "BTC-USDT-SWAP")
                continue;
            var det = daten[b].details || [];
            for (var i = 0; i < det.length; i++) {
                var ts = Number(det[i].ts);
                // `sz` sind Kontrakte; `posSide` sagt, was liquidiert wurde
                root.__liqAdd(ts / 1000, Number(det[i].bkPx), Number(det[i].sz) * root.okxKontrakt,
                              det[i].posSide === "long", "okx");
                if (!isNaN(ts) && (!aeltest || ts < aeltest))
                    aeltest = ts;
            }
        }
        return aeltest;
    }

    function __okxNachricht(text) {
        if (text === "pong")
            return;
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (!m.arg || m.arg.channel !== "liquidation-orders")
            return;
        root.__okxEintraege(m.data);
    }

    // `S` ist die Position, nicht die Zwangsorder: "Buy" heisst, ein Long
    // wurde liquidiert (am 04.09.2026 im Dienst nachgemessen)
    function __bybitLiqNachricht(text) {
        var m;
        try {
            m = JSON.parse(text);
        } catch (e) {
            return;
        }
        var t = String(m.topic || "");
        if (t.indexOf("allLiquidation") !== 0 && t.indexOf("liquidation") !== 0)
            return;
        var d = m.data || [];
        for (var i = 0; i < d.length; i++)
            root.__liqAdd(Number(d[i].T) / 1000, Number(d[i].p), Number(d[i].v), d[i].S === "Buy", "bybit-liq");
    }

    // Der letzte Tag von OKX, per REST. Blaettert mit `after` zurueck, bis die
    // Liste leer ist (am 13.09. nach fuenf Seiten, am 16.09. nach zwanzig). Hoechstens alle fuenf
    // Minuten -- danach traegt der Strom.
    //
    // **`liqSince` wird damit zum Beginn dieses Rueckgriffs.** Ohne es stuende
    // "zugehoert seit eben" ueber einem Tag voller Marken. Fuer Bybit ist das
    // zu grosszuegig, dort gibt es nur, was seit dem Verbinden kam -- deshalb
    // traegt seit dem 15.09.2026 jede Quelle in `liqSources` ihr eigenes
    // `since`, und die Ansicht nennt Bybit getrennt, wenn es spaeter kam.
    function __nachholen() {
        if (root.__jetzt() - root.__nachgeholt < 300)
            return;
        root.__nachgeholt = root.__jetzt();
        var basis = "https://www.okx.com/api/v5/public/liquidation-orders?instType=SWAP&instFamily=BTC-USDT&state=filled&limit=100";
        function seite(nach, nr) {
            root.__hol(basis + (nach ? "&after=" + nach : ""), function (d, err) {
                if (err || !d || d.code !== "0")
                    return;
                var aeltest = root.__okxEintraege(d.data);
                if (!aeltest)
                    return;
                var sek = Math.floor(aeltest / 1000);
                if (!root.__liqSeit || sek < root.__liqSeit)
                    root.__liqSeit = sek;
                // Bis OKX leer antwortet: es liefert genau 24 Stunden (gemessen
                // 16.09.2026, 20 Seiten). Feste 30 Seiten reichten am 15.09.
                // nur fuer 16,6 Stunden. 100 nur als Schutz, wie im Dienst.
                if (nr < 100 && (!nach || aeltest < nach))
                    seite(aeltest, nr + 1);
            });
        }
        seite(0, 1);
    }

    function __liqVerbunden() {
        if (!root.__liqSeit)
            root.__liqSeit = Math.floor(root.__jetzt());
    }

    // -- Antworten ------------------------------------------------------------------
    function __markt(q, done) {
        root.__gefragt = root.__jetzt();
        root.__pruefen();
        root.__ratioAuffrischen();

        var spanne = (root.spans[q.range] || q.range === "custom") ? q.range : "24h";
        var eigen = q.secs !== undefined ? Math.max(300, Math.min(400000000, root.__ganz(q.secs))) : 0;
        var bandAb = Math.max(0, root.__ganz(q.tape));
        var cur = root.__waehrung(q);
        var von = Math.max(0, root.__ganz(q.from));
        var bis = Math.max(0, root.__ganz(q.to));

        var rf, v = 0, b = 0;
        if (von && bis && bis > von) {
            rf = root.__rasterFuer(bis - von, 400);
            v = von;
            b = bis;
        } else if (bis) {
            if (spanne === "custom" && eigen) {
                v = bis - eigen;
                b = bis;
                rf = root.__rasterFuer(eigen, 400);
            } else {
                rf = root.spans[spanne] || root.spans["24h"];
                b = bis;
            }
        } else if (spanne === "custom" && eigen) {
            rf = root.__rasterFuer(eigen, 400);
        } else {
            rf = root.spans[spanne] || root.spans["24h"];
        }

        root.__kerzen(rf[0], rf[1], v, b, function (kerzen, err) {
            if (!kerzen.length && err) {
                done(null, err);
                return;
            }
            var band = root.__bandSeit(bandAb);
            root.__liqAufraeumen();
            var liqVon = kerzen.length ? kerzen[0][0] : 0;
            // Bis ans Ende der letzten Kerze, mindestens einen Tag -- wie im
            // Dienst. Pauschal ein Tag liess bei Wochenkerzen ("all") die
            // laufende Woche nach ihrem ersten Tag leer (16.09.2026).
            var schritt = kerzen.length > 1
                          ? kerzen[kerzen.length - 1][0] - kerzen[kerzen.length - 2][0] : 0;
            var liqBis = kerzen.length
                         ? kerzen[kerzen.length - 1][0] + Math.max(86400, schritt) : 0;
            var liq = liqVon ? root.__liqFenster(liqVon, liqBis) : [];
            var hist = [];
            if (kerzen.length) {
                var tief = Infinity, hoch = -Infinity;
                for (var i = 0; i < kerzen.length; i++) {
                    tief = Math.min(tief, kerzen[i][3]);
                    hoch = Math.max(hoch, kerzen[i][2]);
                }
                hist = root.__liqHist(liqVon, liqBis, tief, hoch);
            }
            var k = root.__kurs(cur);
            var f = k[0];
            var tape = band[0];
            if (f !== 1.0) {
                // Preise umrechnen, Mengen nicht -- die sind in Bitcoin
                kerzen = kerzen.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), root.__r(x[2] * f, 2),
                            root.__r(x[3] * f, 2), root.__r(x[4] * f, 2), x[5], x[6]];
                });
                tape = tape.map(function (t) {
                    return [t[0], t[1], root.__r(t[2] * f, 2), Math.round(t[3] * f), t[4], t[5]];
                });
                liq = liq.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), x[2], x[3], x[4]];
                });
                hist = hist.map(function (x) {
                    return [root.__r(x[0] * f, 2), Math.round(x[1] * f), Math.round(x[2] * f)];
                });
            }
            done({
                "range": spanne,
                "cur": cur,
                "converted": k[1],
                "candles": kerzen,
                "tape": tape,
                "tapeLast": band[1],
                "liq": liq,
                "liqHist": hist,
                "ratio": root.__ratio,
                "liqSince": Math.round(root.__liqSeit),
                "liqSources": [
                    { "id": "okx", "name": "OKX", "online": okxSock.status === WebSocket.Open,
                      "since": Math.round(root.__liqSeit) },
                    { "id": "bybit-liq", "name": "Bybit", "online": bybitLiqSock.status === WebSocket.Open,
                      "since": Math.round(root.__bybitSeit) }
                ],
                "sources": [
                    { "id": "binance", "name": "Binance", "online": binanceSock.status === WebSocket.Open },
                    { "id": "bybit", "name": "Bybit", "online": bybitSock.status === WebSocket.Open }
                ],
                "trades": root.__trades
            }, null);
        });
    }

    function __overview(q, done) {
        var cur = root.__waehrung(q);
        root.__uebersicht(function (kerzen, err) {
            if (!kerzen.length) {
                done(null, err || "leer");
                return;
            }
            var k = root.__kurs(cur);
            var f = k[0];
            if (f !== 1.0) {
                kerzen = kerzen.map(function (x) {
                    return [x[0], root.__r(x[1] * f, 2), root.__r(x[2] * f, 2),
                            root.__r(x[3] * f, 2), root.__r(x[4] * f, 2), x[5], x[6]];
                });
            }
            done({ "cur": cur, "converted": k[1], "candles": kerzen }, null);
        });
    }

    // -- Heatmap ---------------------------------------------------------------------
    function __oiRasterFuer(kerzen) {
        if (kerzen.length < 2)
            return "1h";
        var schritt = kerzen[1][0] - kerzen[0][0];
        for (var i = 0; i < root.oiRaster.length; i++) {
            if (root.oiRaster[i][1] >= schritt)
                return root.oiRaster[i][0];
        }
        return "1d";
    }

    // {zeiten: [s...], werte: [BTC...]}, aufsteigend
    function __oiAus(roh) {
        var paare = [];
        for (var i = 0; i < (roh || []).length; i++) {
            var t = Math.floor(Number(roh[i].timestamp) / 1000);
            var w = Number(roh[i].sumOpenInterest);
            if (!isNaN(t) && !isNaN(w))
                paare.push([t, w]);
        }
        paare.sort(function (a, b) {
            return a[0] - b[0];
        });
        return {
            "zeiten": paare.map(function (p) { return p[0]; }),
            "werte": paare.map(function (p) { return p[1]; })
        };
    }

    // `heatmap()` im Dienst, Schritt fuer Schritt: waechst das offene
    // Interesse, wurden Positionen zum geltenden Kurs eroeffnet; sie sterben
    // bei Kurs*(1-1/L) bzw. Kurs*(1+1/L), und ein Niveau lebt, bis der Kurs es
    // durchschreitet.
    function __heatmap(kerzen, oi) {
        var stufen = 64, schwelle = 0.004;
        if (kerzen.length < 3)
            return { "yAxis": [], "cells": [], "max": 0 };
        var tief = Infinity, hoch = -Infinity;
        var i, j, x, y;
        for (i = 0; i < kerzen.length; i++) {
            tief = Math.min(tief, kerzen[i][3]);
            hoch = Math.max(hoch, kerzen[i][2]);
        }
        var spanne = hoch - tief;
        if (spanne <= 0)
            return { "yAxis": [], "cells": [], "max": 0 };
        tief -= spanne * 0.04;
        hoch += spanne * 0.04;
        var breite = (hoch - tief) / stufen;
        var n = kerzen.length;

        var zeiten = oi.zeiten, werte = oi.werte;
        if (zeiten.length < 3)
            return { "yAxis": [], "cells": [], "max": 0, "kein_oi": true };

        function oiBei(ts) {
            if (ts < zeiten[0])
                return null;
            var links = 0, rechts = zeiten.length - 1;
            while (links < rechts) {
                var mitte = (links + rechts + 1) >> 1;
                if (zeiten[mitte] <= ts)
                    links = mitte;
                else
                    rechts = mitte - 1;
            }
            return werte[links];
        }

        var gitter = [];
        for (i = 0; i < n; i++) {
            var zeile = new Array(stufen);
            for (y = 0; y < stufen; y++)
                zeile[y] = 0;
            gitter.push(zeile);
        }
        var vorher = oiBei(kerzen[0][0]);
        var hoechst = 0;
        for (i = 1; i < n; i++) {
            var jetzt = oiBei(kerzen[i][0]);
            if (jetzt === null || vorher === null) {
                vorher = jetzt;
                continue;
            }
            var zuwachs = jetzt - vorher;
            vorher = jetzt;
            if (zuwachs <= 0)
                continue;
            var preis = kerzen[i][4];
            var wert = zuwachs * preis;
            for (var h = 0; h < root.hebel.length; h++) {
                for (var seite = 0; seite < 2; seite++) {
                    var istLong = seite === 0;
                    var teil = wert * root.hebel[h][1] * (istLong ? root.longAnteil : 1 - root.longAnteil);
                    var niveau = istLong ? preis * (1 - 1 / root.hebel[h][0])
                                         : preis * (1 + 1 / root.hebel[h][0]);
                    if (niveau < tief || niveau >= hoch)
                        continue;
                    y = Math.floor((niveau - tief) / breite);
                    for (j = i; j < n; j++) {
                        if (kerzen[j][3] <= niveau && niveau <= kerzen[j][2])
                            break;
                        gitter[j][y] += teil;
                        if (gitter[j][y] > hoechst)
                            hoechst = gitter[j][y];
                    }
                }
            }
        }
        var grenze = hoechst * schwelle;
        var zellen = [];
        for (x = 0; x < n; x++) {
            for (y = 0; y < stufen; y++) {
                if (gitter[x][y] > grenze)
                    zellen.push([x, y, Math.round(gitter[x][y])]);
            }
        }
        var achse = [];
        for (y = 0; y < stufen; y++)
            achse.push(root.__r(tief + (y + 0.5) * breite, 2));
        return { "yAxis": achse, "cells": zellen, "max": Math.round(hoechst) };
    }

    function __heat(q, done) {
        var spanne = (root.spans[q.range] || q.range === "custom") ? q.range : "24h";
        var eigen = q.secs !== undefined ? Math.max(300, Math.min(400000000, root.__ganz(q.secs))) : 0;
        var cur = root.__waehrung(q);

        var laenge = {};
        for (var i = 0; i < root.ladder.length; i++)
            laenge[root.ladder[i][0]] = root.ladder[i][1];
        var sp = root.spans[spanne];
        var gewuenscht = (spanne === "custom" && eigen) ? eigen
                       : (sp ? sp[1] * (laenge[sp[0]] || 3600) : 0);
        var grenze = root.oiMaxTage * 86400;
        var zuLang = gewuenscht > grenze;
        var rf;
        if (zuLang)
            rf = root.__rasterFuer(grenze, 200);
        else if (spanne === "custom" && eigen)
            rf = root.__rasterFuer(eigen, 200);
        else
            rf = root.__rasterFuer(gewuenscht > 0 ? gewuenscht : 86400, 200);

        root.__kerzen(rf[0], rf[1], 0, 0, function (kerzen, err) {
            if (!kerzen.length && err) {
                done(null, err);
                return;
            }
            var raster = root.__oiRasterFuer(kerzen);
            root.__gepuffert("https://fapi.binance.com/futures/data/openInterestHist?symbol=BTCUSDT&period="
                             + raster + "&limit=500", 240, root.__oiAus, function (oi, oiErr) {
                // **Keine Antwort ist nicht "kein offenes Interesse".** Bis zum
                // 15.09.2026 wurde aus einem Ausfall von Binance Futures eine
                // Heatmap mit `kein_oi`, und die Ansicht zeigte sie eine Minute
                // lang als gueltig. Jetzt ein Fehler: die Ansicht behaelt das
                // letzte Bild und fragt bald wieder.
                if (!oi && oiErr) {
                    done(null, oiErr);
                    return;
                }
                var d = root.__heatmap(kerzen, oi || { "zeiten": [], "werte": [] });
                var k = root.__kurs(cur);
                var f = k[0];
                if (f !== 1.0) {
                    d.yAxis = d.yAxis.map(function (v) { return root.__r(v * f, 2); });
                    d.cells = d.cells.map(function (c) { return [c[0], c[1], Math.round(c[2] * f)]; });
                    d.max = Math.round(d.max * f);
                }
                d.converted = k[1];
                d.clamped = zuLang;
                d.maxDays = root.oiMaxTage;
                d.times = kerzen.map(function (x) { return x[0]; });
                d.closes = kerzen.map(function (x) { return f !== 1.0 ? x[4] * f : x[4]; });
                d.model = { "leverage": root.hebel, "longShare": root.longAnteil };
                done(d, null);
            });
        });
    }

    // -- Verbindungen -----------------------------------------------------------------
    // Die Stroeme laufen nur, solange jemand `/market` fragt, und noch
    // `linger` Sekunden danach -- `gefragt()`/`erwuenscht()` im Dienst.
    function __pruefen() {
        var soll = root.__jetzt() - root.__gefragt < root.linger;
        if (soll !== root.__erwuenscht)
            root.__erwuenscht = soll;
    }

    // **Nicht gebunden, sondern gesetzt.** Zum Neuverbinden muss `active` kurz
    // aus und wieder an; eine Zuweisung zerstoert aber eine Bindung, und danach
    // folgte der Strom dem Schalter nicht mehr.
    function __schalten() {
        var an = root.laeuft;
        binanceSock.active = an;
        bybitSock.active = an;
        okxSock.active = an;
        bybitLiqSock.active = an;
        if (an)
            root.__nachholen();
    }

    onLaeuftChanged: root.__schalten()

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.__pruefen()
    }

    // Wieder anklopfen, wenn eine Verbindung weg ist
    Timer {
        interval: 5000
        repeat: true
        running: root.laeuft

        onTriggered: {
            var alle = [binanceSock, bybitSock, okxSock, bybitLiqSock];
            for (var i = 0; i < alle.length; i++) {
                var s = alle[i];
                if (s.status === WebSocket.Error || s.status === WebSocket.Closed) {
                    s.active = false;
                    s.active = true;
                }
            }
        }
    }

    // OKX schliesst nach 30 s Stille, Bybit nach rund zehn Minuten ohne Ping
    Timer {
        interval: 18000
        repeat: true
        running: root.laeuft

        onTriggered: {
            if (okxSock.status === WebSocket.Open)
                okxSock.sendTextMessage("ping");
            if (bybitSock.status === WebSocket.Open)
                bybitSock.sendTextMessage('{"op":"ping"}');
            if (bybitLiqSock.status === WebSocket.Open)
                bybitLiqSock.sendTextMessage('{"op":"ping"}');
        }
    }

    WebSocket {
        id: binanceSock

        url: "wss://stream.binance.com:9443/ws/btcusdt@aggTrade"
        active: false
        onTextMessageReceived: function (message) {
            root.__binanceNachricht(message);
        }
    }

    WebSocket {
        id: bybitSock

        url: "wss://stream.bybit.com/v5/public/spot"
        active: false
        onStatusChanged: {
            if (bybitSock.status === WebSocket.Open)
                bybitSock.sendTextMessage(JSON.stringify({ "op": "subscribe", "args": ["publicTrade.BTCUSDT"] }));
        }
        onTextMessageReceived: function (message) {
            root.__bybitNachricht(message);
        }
    }

    WebSocket {
        id: okxSock

        url: "wss://ws.okx.com:8443/ws/v5/public"
        active: false
        onStatusChanged: {
            if (okxSock.status === WebSocket.Open) {
                okxSock.sendTextMessage(JSON.stringify({
                    "op": "subscribe",
                    "args": [{ "channel": "liquidation-orders", "instType": "SWAP" }]
                }));
                root.__liqVerbunden();
            }
        }
        onTextMessageReceived: function (message) {
            root.__okxNachricht(message);
        }
    }

    WebSocket {
        id: bybitLiqSock

        url: "wss://stream.bybit.com/v5/public/linear"
        active: false
        onStatusChanged: {
            if (bybitLiqSock.status === WebSocket.Open) {
                bybitLiqSock.sendTextMessage(JSON.stringify({ "op": "subscribe", "args": ["allLiquidation.BTCUSDT"] }));
                root.__liqVerbunden();
                if (!root.__bybitSeit)
                    root.__bybitSeit = Math.floor(root.__jetzt());
            }
        }
        onTextMessageReceived: function (message) {
            root.__bybitLiqNachricht(message);
        }
    }
}
