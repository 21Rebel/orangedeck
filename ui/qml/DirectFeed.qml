// Direktbezug: die Oberflaeche redet selbst mit mempool.space.
//
// Der Daemon bleibt die bessere Wahl, wo mehrere Fenster nebeneinander laufen
// -- er haelt **eine** Verbindung fuer alle. Auf einem Handy gibt es ihn aber
// nicht, und ein Widget, das nur laeuft, solange der Heimrechner an ist, ist
// kein Widget. Deshalb dieselbe Aufbereitung noch einmal hier, in QML.
//
// Der Aufbau ist bewusst deckungsgleich mit `/state` und `/block` des
// Daemons: `FeedState` schiebt beides durch dieselbe Auswertung, und keine
// einzige Ansicht merkt, woher die Zahlen kommen.
//
// **Eigene Datei, absichtlich.** `import QtWebSockets` gibt es nicht auf jedem
// Rechner (Paket `qt6-websockets`). Stuende die Zeile in `FeedState.qml`,
// fiele bei einem fehlenden Paket die ganze Anwendung aus; so faellt nur der
// Direktbezug aus, und der Daemon traegt weiter.
//
// Was hier **nicht** geht und beim Daemon bleibt:
//   Wallets  -- die Ableitung aus dem xpub ist Punktarithmetik auf secp256k1,
//               das gehoert nicht in QML nachgebaut.
//   Miner    -- das Geraet steht im Heimnetz, da hilft kein Direktbezug.
import QtQuick
import QtWebSockets
import "mondrian.js" as Mondrian
import "txtype.js" as TxType
import "colors.js" as Colors

Item {
    id: root

    visible: false

    property bool active: true
    property string host: "mempool.space"
    readonly property string api: "https://" + root.host + "/api"
    readonly property string wsUrl: "wss://" + root.host + "/api/v1/ws"

    // Wie oft der gesammelte Zustand nach aussen gereicht wird. Der Daemon
    // schreibt in demselben Takt; alles darunter kostet nur Rechenzeit, weil
    // die Anzeige ohnehin nicht schneller ist.
    property int pushMs: 400

    // Ergebnis -- gleicher Aufbau wie beim Daemon
    property var snap: ({})
    property var block: ({})

    // Obergrenzen wie im Daemon, damit dieselben Bilder herauskommen
    readonly property int recentKeep: 120
    readonly property int maxTiles: 8000
    readonly property int projectedKeep: 8
    // Solange jemand hinsieht, bleibt der geplante Block abonniert. Danach
    // wird abbestellt -- das ist der teuerste Strom, den der Server schickt.
    readonly property int projectedLinger: 20

    // -- innerer Zustand ---------------------------------------------------
    property int __seq: 0
    property var __recent: []
    property var __mempool: ({ "count": 0, "vsize": 0, "totalFee": 0 })
    property var __fees: ({})
    property int __vbps: 0
    property var __nextBlock: ({})
    property var __projected: []
    property var __tip: ({})
    property var __price: ({})
    property real __blockEvent: 0
    property var __difficulty: ({})
    property var __hashrate: ({})
    property string __source: "start"
    property string __error: ""
    property bool __dirty: true
    property string __summaryFor: ""
    property bool __summaryBusy: false

    // Geplante Bloecke: Rang -> { txid: Zeile }. Die Zeilen kommen so vom
    // Server: [txid, fee, vsize, value, rate, flags]
    property var __projRows: ({})
    property var __projAt: ({})
    property int __want: -1        // gewuenschter Rang, -1 = keiner
    property int __tracked: -1     // was tatsaechlich abonniert ist
    property real __trackUntil: 0

    // -- Hilfen ------------------------------------------------------------
    function __num(v) {
        var n = Number(v);
        return isFinite(n) ? n : 0;
    }

    function __round(v, n) {
        var f = Math.pow(10, n);
        return Math.round(root.__num(v) * f) / f;
    }

    // Die zwei Ziffern je Kachel: Kantenlaenge und Gebuehrenklasse. Dieselbe
    // Rechnung wie im Daemon -- die Bilder muessen sich decken.
    function __tile(valueSats, rate) {
        return String(Mondrian.txSize(valueSats, 5)) + String(Colors.feeBucket(rate));
    }

    function __kind(flags, isCoinbase) {
        var k = TxType.fromFlags(flags, isCoinbase);
        var i = TxType.KINDS.indexOf(k);
        return String(i < 0 ? 0 : i);
    }

    function __send(obj) {
        if (sock.status === WebSocket.Open)
            sock.sendTextMessage(JSON.stringify(obj));
    }

    // -- Nachrichten des Servers -------------------------------------------
    function __handle(text) {
        var msg;
        try {
            msg = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (!msg || typeof msg !== "object")
            return;

        var p = msg["projected-block-transactions"];
        if (p !== undefined && p !== null) {
            root.__handleProjected(p);
            return;
        }

        if (msg.mempoolInfo) {
            var mi = msg.mempoolInfo;
            root.__mempool = {
                "count": Math.round(root.__num(mi.size)),
                "vsize": Math.round(root.__num(mi.bytes)),
                "totalFee": Math.round(root.__num(mi.total_fee) * 1e8)
            };
            root.__dirty = true;
        }
        if (msg.transactions)
            root.__addTxs(msg.transactions);
        if (msg["mempool-blocks"])
            root.__setProjected(msg["mempool-blocks"]);
        if (msg.fees) {
            var f = msg.fees;
            root.__fees = {
                "fastest": root.__round(f.fastestFee, 2),
                "halfHour": root.__round(f.halfHourFee, 2),
                "hour": root.__round(f.hourFee, 2),
                "economy": root.__round(f.economyFee, 2),
                "minimum": root.__round(f.minimumFee, 2)
            };
            root.__dirty = true;
        }
        if (msg.vBytesPerSecond !== undefined) {
            root.__vbps = Math.round(root.__num(msg.vBytesPerSecond));
            root.__dirty = true;
        }
        if (msg.conversions) {
            // Der Server schickt alle Waehrungen mit -- sie kosten nichts
            // extra und ersparen der Oberflaeche jedes eigene Umrechnen.
            var c = msg.conversions;
            var np = {};
            var waehrungen = ["USD", "EUR", "GBP", "CAD", "CHF", "AUD", "JPY"];
            for (var i = 0; i < waehrungen.length; i++) {
                var k = waehrungen[i];
                if (c[k])
                    np[k.toLowerCase()] = c[k];
            }
            root.__price = np;
            root.__dirty = true;
        }
        if (msg.blocks && msg.blocks.length)
            root.__setTip(msg.blocks[msg.blocks.length - 1], false);
        if (msg.block)
            root.__setTip(msg.block, true);
    }

    function __addTxs(txs) {
        var rec = root.__recent.slice();
        for (var i = 0; i < txs.length; i++) {
            var t = txs[i];
            if (!t)
                continue;
            var vsize = root.__num(t.vsize) || 1;
            var rate = (t.rate === undefined || t.rate === null)
                ? root.__num(t.fee) / vsize : root.__num(t.rate);
            root.__seq += 1;
            rec.push({
                "n": root.__seq,
                "t": t.txid || "",
                "v": root.__round(vsize, 1),
                "r": root.__round(rate, 3),
                "a": Math.round(root.__num(t.value)),
                "f": Math.round(root.__num(t.fee))
            });
        }
        if (rec.length > root.recentKeep)
            rec = rec.slice(rec.length - root.recentKeep);
        root.__recent = rec;
        root.__dirty = true;
    }

    function __setProjected(blocks) {
        if (!blocks || !blocks.length)
            return;
        var b = blocks[0];
        root.__nextBlock = {
            "nTx": Math.round(root.__num(b.nTx)),
            "vsize": Math.round(root.__num(b.blockVSize)),
            "medianFee": root.__round(b.medianFee, 2),
            "totalFees": Math.round(root.__num(b.totalFees)),
            "feeRange": (b.feeRange || []).map(function (v) {
                return root.__round(v, 2);
            })
        };
        var liste = [];
        for (var i = 0; i < blocks.length && i < root.projectedKeep; i++) {
            var x = blocks[i];
            liste.push({
                "nTx": Math.round(root.__num(x.nTx)),
                "blockSize": Math.round(root.__num(x.blockSize)),
                "blockVSize": Math.round(root.__num(x.blockVSize)),
                "medianFee": root.__round(x.medianFee, 2),
                "totalFees": Math.round(root.__num(x.totalFees)),
                "feeRange": (x.feeRange || []).map(function (v) {
                    return root.__round(v, 2);
                })
            });
        }
        root.__projected = liste;
        root.__dirty = true;
    }

    function __setTip(b, isNew) {
        if (!b)
            return;
        var height = Math.round(root.__num(b.height));
        if (height && height === root.__num(root.__tip.height) && !isNew)
            return;
        var ex = b.extras || {};
        root.__tip = {
            "height": height,
            "id": b.id || "",
            "time": Math.round(root.__num(b.timestamp)),
            "nTx": Math.round(root.__num(b.tx_count)),
            "size": Math.round(root.__num(b.size)),
            "weight": Math.round(root.__num(b.weight)),
            "medianFee": root.__round(ex.medianFee, 2),
            "totalFees": Math.round(root.__num(ex.totalFees)),
            "reward": Math.round(root.__num(ex.reward)),
            "pool": (ex.pool && ex.pool.name) || ""
        };
        if (isNew)
            root.__blockEvent = Date.now() / 1000;
        root.__dirty = true;
        root.__fetchSummary();
    }

    // -- Der geplante Block, lebendig --------------------------------------
    //
    // Zuerst kommt die Vollform, danach nur noch Aenderungen. Anders als beim
    // Daemon braucht es hier **kein** Aenderungsbuch: es gibt keinen zweiten
    // Prozess, der einen Rueckstand aufholen muesste. Die Zeilen werden
    // gepflegt, die Ansicht holt sich den jeweils gueltigen Stand.
    function __handleProjected(p) {
        var idx = parseInt(p.index, 10);
        if (isNaN(idx))
            return;

        var rows = p.blockTransactions;
        var karte;
        if (rows) {
            karte = {};
            for (var i = 0; i < rows.length; i++) {
                if (rows[i])
                    karte[rows[i][0]] = rows[i];
            }
            root.__projRows[idx] = karte;
            root.__projAt[idx] = Date.now() / 1000;
            return;
        }

        var d = p.delta;
        if (!d)
            return;
        karte = root.__projRows[idx];
        if (!karte)
            return;                       // ohne Vollform ist eine Aenderung nichts wert

        var j, r, t;
        var weg = d.removed || [];
        for (j = 0; j < weg.length; j++) {
            t = (typeof weg[j] === "string") ? weg[j] : (weg[j] ? weg[j][0] : null);
            if (t !== null)
                delete karte[t];
        }
        var zu = d.added || [];
        for (j = 0; j < zu.length; j++) {
            if (zu[j])
                karte[zu[j][0]] = zu[j];
        }
        // Bekannte Form: [txid, rate] -- die Kachel bleibt liegen, nur ihre
        // Gebuehrenfarbe aendert sich.
        var ge = d.changed || [];
        for (j = 0; j < ge.length; j++) {
            r = ge[j];
            if (!r || r.length < 2)
                continue;
            var alt = karte[r[0]];
            if (alt) {
                var neu = alt.slice();
                neu[4] = r[1];
                karte[r[0]] = neu;
            }
        }
        root.__projAt[idx] = Date.now() / 1000;
    }

    // Die Kacheldaten eines geplanten Blocks in der Form, die `BlockTiles`
    // erwartet -- dieselbe wie beim Daemon unter `/lookup/projectedtiles/<n>`.
    function __projectedTiles(idx) {
        var karte = root.__projRows[idx];
        if (!karte)
            return null;
        var zeilen = [];
        for (var k in karte)
            zeilen.push(karte[k]);
        // Absteigend nach Gebuehrenrate, wie im Daemon
        zeilen.sort(function (a, b) {
            return (b[4] || 0) - (a[4] || 0);
        });

        var schritt = Math.max(1, Math.ceil(zeilen.length / root.maxTiles));
        var tiles = [], kinds = [], txs = [];
        for (var i = 0; i < zeilen.length; i += schritt) {
            var r = zeilen[i];
            tiles.push(root.__tile(r[3], r[4]));
            kinds.push(root.__kind(r.length > 5 ? r[5] : 0, false));
            txs.push([r[0], root.__round(r[2], 2), Math.round(root.__num(r[1])),
                      Math.round(root.__num(r[3])), root.__round(r[4], 3)]);
        }
        return {
            "index": idx,
            "full": true,
            "count": zeilen.length,
            "tileStep": schritt,
            "tiles": tiles.join(""),
            "types": kinds.join(""),
            "txs": txs,
            "changedAt": root.__projAt[idx] || 0,
            "ts": Date.now() / 1000
        };
    }

    // -- REST --------------------------------------------------------------
    function __get(path, done, fail) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            if (x.status === 200 && x.responseText)
                done(x.responseText);
            else if (fail)
                fail(x.status);
        };
        try {
            x.open("GET", root.api + path);
            x.send();
        } catch (e) {
            if (fail)
                fail(0);
        }
    }

    // Kacheldaten des zuletzt gefundenen Blocks. Aus jeder Transaktion werden
    // nur zwei Ziffern behalten -- ein voller Block sind damit rund 8 kB
    // statt 700 kB im Speicher.
    function __fetchSummary() {
        var bid = root.__tip.id;
        if (!bid || bid === root.__summaryFor || root.__summaryBusy)
            return;
        root.__summaryBusy = true;
        var tip = root.__tip;
        root.__get("/v1/block/" + bid + "/summary", function (txt) {
            root.__summaryBusy = false;
            var liste;
            try {
                liste = JSON.parse(txt);
            } catch (e) {
                return;
            }
            if (!liste || !liste.length)
                return;
            root.__summaryFor = bid;
            root.block = root.__buildBlock(liste, tip);
        }, function () {
            root.__summaryBusy = false;
        });
    }

    // Aus der Transaktionsliste eines Blocks die Kacheldaten. Dieselbe
    // Aufbereitung wie `summarize_block()` im Daemon.
    function __buildBlock(txs, base) {
        var schritt = Math.max(1, Math.ceil(txs.length / root.maxTiles));
        var summe = 0, gebuehr = 0, vsize = 0;
        for (var i = 0; i < txs.length; i++) {
            summe += root.__num(txs[i].value);
            gebuehr += root.__num(txs[i].fee);
            vsize += root.__num(txs[i].vsize);
        }
        var tiles = [], kinds = [], details = [];
        for (i = 0; i < txs.length; i += schritt) {
            var t = txs[i];
            tiles.push(root.__tile(t.value, t.rate));
            // Die erste Transaktion eines Blocks ist die Blockbelohnung. Am
            // Bitfeld ist sie nicht zu erkennen -- an ihrer Lage schon.
            kinds.push(root.__kind(t.flags, i === 0));
            details.push([t.txid || "", root.__round(t.vsize, 2),
                          Math.round(root.__num(t.fee)),
                          Math.round(root.__num(t.value)),
                          root.__round(t.rate, 3)]);
        }
        var d = {};
        for (var k in base)
            d[k] = base[k];
        d.totalValue = summe;
        d.sumFees = gebuehr;
        d.avgFeeRate = vsize ? root.__round(gebuehr / vsize, 3) : 0;
        d.tileStep = schritt;
        d.tiles = tiles.join("");
        d.types = kinds.join("");
        d.txs = details;
        d.ts = Date.now() / 1000;
        return d;
    }

    // Langsame Kennzahlen -- alle fuenf Minuten reicht, sie aendern sich
    // hoechstens alle zehn Minuten.
    function __slow() {
        root.__get("/v1/difficulty-adjustment", function (txt) {
            try {
                var d = JSON.parse(txt);
                root.__difficulty = {
                    "progress": d.progressPercent,
                    "change": d.difficultyChange,
                    "remainingBlocks": d.remainingBlocks,
                    "remainingTime": d.remainingTime,
                    "nextHeight": d.nextRetargetHeight,
                    "previousChange": d.previousRetarget,
                    "timeAvg": d.timeAvg,
                    "retargetDate": d.estimatedRetargetDate,
                    "expectedBlocks": d.expectedBlocks
                };
                root.__dirty = true;
            } catch (e) {}
        });
        // /1m sind 31 Punkte bei 2,2 kB -- genug fuer eine Kurve, /3d hat nur drei.
        root.__get("/v1/mining/hashrate/1m", function (txt) {
            try {
                var h = JSON.parse(txt);
                var reihe = (h.hashrates || []).map(function (p) {
                    return p.avgHashrate;
                });
                root.__hashrate = {
                    "current": h.currentHashrate,
                    "difficulty": h.currentDifficulty,
                    "series": reihe.slice(-40)
                };
                root.__dirty = true;
            } catch (e) {}
        });
    }

    // -- Einzelabfragen fuer den Explorer ----------------------------------
    //
    // Dieselben Namen wie beim Daemon (`LOOKUP_ROUTES`), damit `ExplorerView`
    // nichts von der Quelle wissen muss. Zwei Faelle werden nicht
    // weitergereicht, sondern hier aufbereitet: die Kacheln eines Blocks und
    // die eines geplanten Blocks.
    readonly property var __routes: ({
        "tx": "/tx/%1",
        "outspends": "/tx/%1/outspends",
        "block": "/block/%1",
        "blocktxids": "/block/%1/txids",
        "blockheight": "/block-height/%1",
        "address": "/address/%1",
        "addresstxs": "/address/%1/txs",
        "blocks": "/v1/blocks",
        "blockinfo": "/v1/block/%1",
        "mempoolblocks": "/v1/fees/mempool-blocks",
        "replacements": "/v1/replacements"
    })

    // ------------------------------------------------------- Kursverlauf
    // Ohne Dienst gibt es niemanden, der ausduennt -- das muss hier passieren.
    // Die Vollform sind 1,5 MB und 33.299 Punkte; sie wird **einmal** geholt
    // und im Speicher gehalten, danach kostet jeder Zeitraum nur noch Rechnen.
    property var __preise: null
    property real __preiseTs: 0
    // Dieselben Zeitraeume und dieselbe Obergrenze wie im Dienst
    readonly property var __spans: ({ "24h": 86400, "7d": 604800, "30d": 2592000,
                                      "90d": 7776000, "1y": 31536000, "max": 0 })
    readonly property int __maxPunkte: 360

    function prices(span, cur, done) {
        var alt = Date.now() / 1000 - root.__preiseTs > 3600;
        if (root.__preise && !alt) {
            done(root.__preisReihe(span, cur), null);
            return;
        }
        root.__get("/v1/historical-price?currency=EUR", function (txt) {
            var d;
            try {
                d = JSON.parse(txt);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
                return;
            }
            var roh = d.prices || [], punkte = [];
            for (var i = 0; i < roh.length; i++) {
                var x = roh[i];
                // **-1 heisst "kein Wert"**, nicht "minus ein Euro". 295 der
                // 33.299 Punkte tragen ihn. Ungefiltert zieht ein einziger die
                // ganze Kurve nach unten.
                var e = (x.EUR > 0) ? x.EUR : 0;
                var u = (x.USD > 0) ? x.USD : 0;
                if (x.time && (e || u))
                    punkte.push([x.time, e, u]);
            }
            punkte.sort(function (a, b) {
                return a[0] - b[0];
            });
            root.__preise = { "points": punkte, "rates": d.exchangeRates || ({}) };
            root.__preiseTs = Date.now() / 1000;
            done(root.__preisReihe(span, cur), null);
        }, function () {
            // Ein alter Verlauf ist besser als gar keiner
            if (root.__preise)
                done(root.__preisReihe(span, cur), null);
            else
                done(null, "nicht erreichbar");
        });
    }

    function __preisReihe(span, cur) {
        var alle = root.__preise.points, w = String(cur || "eur").toLowerCase();
        var dauer = root.__spans[span] || 0;
        var punkte = alle;
        if (dauer) {
            var grenze = Date.now() / 1000 - dauer;
            punkte = [];
            for (var i = 0; i < alle.length; i++) {
                if (alle[i][0] >= grenze)
                    punkte.push(alle[i]);
            }
        }
        if (!punkte.length)
            return { "span": span, "cur": w, "points": [], "converted": false };

        // **Erst die Waehrung, dann ausduennen.** Andersherum faellt ein ganzes
        // Fach aus, wenn ausgerechnet der gewaehlte Punkt in dieser Waehrung
        // keinen Wert hat -- und das sind bei EUR fast dreihundert.
        //
        // Nur EUR und USD stehen wirklich im Datensatz. Die uebrigen fuenf
        // entstehen aus dem USD-Wert mit dem **heutigen** Wechselkurs -- ueber
        // Jahre ist das eine Umrechnung, keine Wahrheit. Die Antwort sagt es.
        var umgerechnet = (w !== "eur" && w !== "usd");
        var reihe = [], j, kurs = 1;
        if (umgerechnet) {
            kurs = root.__preise.rates["USD" + w.toUpperCase()];
            if (!kurs)
                return { "span": span, "cur": w, "points": [], "converted": true };
        }
        var sp = (w === "eur") ? 1 : 2;
        for (j = 0; j < punkte.length; j++) {
            if (punkte[j][sp] > 0) {
                reihe.push([punkte[j][0], umgerechnet
                            ? Math.round(punkte[j][2] * kurs * 100) / 100
                            : punkte[j][sp]]);
            }
        }
        if (!reihe.length)
            return { "span": span, "cur": w, "points": [], "converted": umgerechnet };

        // Faecher gleicher Breite, aus jedem ein Punkt -- **nicht** jeder n-te.
        // Die Abstaende sind ungleich (stuendlich, taeglich, woechentlich), da
        // verzerrt jede feste Schrittweite die Zeitachse.
        if (reihe.length > root.__maxPunkte) {
            var t0 = reihe[0][0], t1 = reihe[reihe.length - 1][0];
            var breite = Math.max(1, (t1 - t0) / root.__maxPunkte);
            var gewaehlt = [], letztes = -1;
            for (var k = 0; k < reihe.length; k++) {
                var fach = Math.floor((reihe[k][0] - t0) / breite);
                if (fach !== letztes) {
                    gewaehlt.push(reihe[k]);
                    letztes = fach;
                }
            }
            if (gewaehlt[gewaehlt.length - 1][0] !== t1)
                gewaehlt.push(reihe[reihe.length - 1]);
            reihe = gewaehlt;
        }
        return { "span": span, "cur": w, "points": reihe, "converted": umgerechnet };
    }

    function lookup(kind, arg, done) {
        if (kind === "projectedtiles") {
            // Jede Abfrage verlaengert das Mithoeren; hoert die Ansicht auf zu
            // fragen, wird von selbst wieder abbestellt.
            var rang = parseInt(String(arg).split("-")[0], 10) || 0;
            root.__want = rang;
            root.__trackUntil = Date.now() / 1000 + root.projectedLinger;
            var fertig = root.__projectedTiles(rang);
            if (fertig)
                done(fertig, null);
            else
                done(null, "noch keine Daten");
            return;
        }
        if (kind === "blocktiles") {
            root.__get("/v1/block/" + arg + "/summary", function (txt) {
                try {
                    var liste = JSON.parse(txt);
                    done(root.__buildBlock(liste, { "id": arg }), null);
                } catch (e) {
                    done(null, "Antwort nicht lesbar");
                }
            }, function () {
                done(null, "nicht erreichbar");
            });
            return;
        }

        var pfad = root.__routes[kind];
        if (!pfad) {
            done(null, "unbekannte Abfrage");
            return;
        }
        root.__get(pfad.replace("%1", encodeURIComponent(arg)), function (txt) {
            try {
                // /block-height liefert nackten Text, kein JSON
                done(kind === "blockheight" ? txt.trim() : JSON.parse(txt), null);
            } catch (e) {
                done(null, "Antwort nicht lesbar");
            }
        }, function (status) {
            done(null, status === 404 ? "nicht gefunden" : "nicht erreichbar");
        });
    }

    // -- Ausgabe -----------------------------------------------------------
    function __push() {
        if (!root.__dirty)
            return;
        root.__dirty = false;
        root.snap = {
            "ts": Date.now() / 1000,
            "source": root.__source,
            "error": root.__error,
            "mempool": root.__mempool,
            "fees": root.__fees,
            "vbps": root.__vbps,
            "nextBlock": root.__nextBlock,
            "projected": root.__projected,
            "tip": root.__tip,
            "price": root.__price,
            "blockEvent": root.__blockEvent,
            "seq": root.__seq,
            "recent": root.__recent,
            "difficulty": root.__difficulty,
            "hashrate": root.__hashrate,
            // Miner und Wallets kann der Direktbezug nicht -- leer, nicht
            // fehlend, damit die Ansichten "nicht eingerichtet" zeigen und
            // nicht auf undefined laufen.
            "miners": [],
            "minerHistory": {},
            "minerTotal": {},
            "wallets": [],
            "walletBusy": false
        };
    }

    // -- Verbindung --------------------------------------------------------
    WebSocket {
        id: sock

        url: root.wsUrl
        active: root.active

        onStatusChanged: {
            if (sock.status === WebSocket.Open) {
                root.__source = "direct";
                root.__error = "";
                root.__dirty = true;
                root.__send({ "action": "init" });
                root.__send({ "action": "want",
                              "data": ["blocks", "stats", "mempool-blocks"] });
                root.__tracked = -1;
                root.__slow();
            } else if (sock.status === WebSocket.Error) {
                root.__source = "offline";
                root.__error = sock.errorString || "Verbindung gestoert";
                root.__dirty = true;
            } else if (sock.status === WebSocket.Closed) {
                root.__source = "offline";
                root.__dirty = true;
            }
        }

        onTextMessageReceived: function (message) {
            root.__handle(message);
        }
    }

    // Wieder anklopfen, wenn die Verbindung weg ist. `active` kurz aus und
    // wieder an ist der einzige Weg, den WebSocket neu zu verbinden.
    Timer {
        interval: 5000
        repeat: true
        running: root.active

        onTriggered: {
            if (sock.status === WebSocket.Error || sock.status === WebSocket.Closed) {
                sock.active = false;
                sock.active = true;
            }
        }
    }

    Timer {
        interval: root.pushMs
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.__push()
    }

    // An- und Abmelden des geplanten Blocks. Getrennt vom Abfragen, damit es
    // nur einmal je Aenderung geschieht -- und nicht bei jedem Bildaufbau.
    Timer {
        interval: 1000
        repeat: true
        running: root.active

        onTriggered: {
            if (root.__want >= 0 && Date.now() / 1000 > root.__trackUntil)
                root.__want = -1;
            if (root.__want === root.__tracked || sock.status !== WebSocket.Open)
                return;
            root.__send({ "track-mempool-block": root.__want });
            root.__tracked = root.__want;
            if (root.__want < 0)
                root.__projRows = ({});
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.active
        onTriggered: root.__slow()
    }
}
