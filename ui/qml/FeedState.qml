// Liest den von btcfeed gelieferten Zustand und meldet neue Transaktionen
// sowie gefundene Bloecke als Signale weiter.
//
// Bewusst nur `import QtQuick`: diese Datei laeuft damit unveraendert in der
// DankMaterialShell, in der eigenstaendigen Qt-Anwendung und unter Android.
// Sie kannte frueher Quickshell (env, FileView, Process) -- alle drei sind
// ersetzt:
//
//   Quickshell.env  ->  entfaellt, der Ort steckt in `endpoint`
//   FileView        ->  XMLHttpRequest gegen die Loopback-Schnittstelle.
//                       Lesen von file:// scheidet aus: Qt sperrt das hinter
//                       QML_XHR_ALLOW_FILE_READ=1, ohne die Variable bleibt
//                       der Aufruf auf readyState 1 stehen (01.09.2026
//                       nachgemessen). Ueber HTTP gibt es diesen Sonderfall
//                       nicht -- auf keinem Desktop und auch nicht auf Android.
//   Process         ->  gehoert nicht hierher. Den Daemon starten in der
//                       Shell BitcoinFeedDaemon.qml und beim eigenen Fenster
//                       btcfeed-window; beide taten das ohnehin schon.
import QtQuick

Item {
    id: root

    visible: false

    property bool active: true
    // Standard ist die Loopback-Schnittstelle des lokalen Daemons. Fuer ein
    // Tablet zeigt das stattdessen auf den Rechner im eigenen Netz -- eine
    // bewusste Einstellung, kein Standardverhalten.
    property string endpoint: "http://127.0.0.1:21021"
    property int pollMs: 400

    // Ausgelesener Zustand
    property var snap: ({})
    property var block: ({})          // Kacheldaten des zuletzt gefundenen Blocks
    property int seq: 0
    property real stateTs: 0
    property real blockEventTs: 0
    property bool online: false
    property string source: ""
    property string lastError: ""

    readonly property int mempoolCount: (snap.mempool && snap.mempool.count) || 0
    readonly property int mempoolVsize: (snap.mempool && snap.mempool.vsize) || 0
    readonly property real feeFastest: (snap.fees && snap.fees.fastest) || 0
    readonly property real feeHour: (snap.fees && snap.fees.hour) || 0
    readonly property int vbps: snap.vbps || 0
    readonly property var tip: snap.tip || ({})
    readonly property var nextBlock: snap.nextBlock || ({})
    readonly property var price: snap.price || ({})
    readonly property int tipHeight: tip.height || 0
    // Langsame Kennzahlen und der eigene Miner -- der Daemon holt sie nebenher
    readonly property var difficulty: snap.difficulty || ({})
    readonly property var hashrate: snap.hashrate || ({})
    // Miner: eine Liste, weil man mehr als ein Geraet haben kann. Der Daemon
    // liefert alle Felder normalisiert, Hashrate immer in H/s.
    readonly property var miners: snap.miners || []
    readonly property var minerTotal: snap.minerTotal || ({})
    readonly property bool minerConfigured: miners.length > 0
    readonly property bool minerOnline: (minerTotal.online || 0) > 0

    signal transactionsArrived(var txs)
    signal blockMined(var tip)

    // -- Abholen ----------------------------------------------------------
    // Eine Abfrage nach der anderen: bei 400 ms Takt und einem haengenden
    // Netzweg wuerden sich sonst Anfragen stapeln.
    property bool __statePending: false
    property bool __blockPending: false

    function __get(path, pendingKey, onOk, onFail) {
        if (root[pendingKey])
            return;
        root[pendingKey] = true;
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            root[pendingKey] = false;
            if (x.status === 200 && x.responseText)
                onOk(x.responseText);
            else if (onFail)
                onFail();
        };
        try {
            x.open("GET", root.endpoint + path);
            x.send();
        } catch (e) {
            root[pendingKey] = false;
            if (onFail)
                onFail();
        }
    }

    function __parse(txt) {
        if (!txt)
            return;
        var d;
        try {
            d = JSON.parse(txt);
        } catch (e) {
            return;
        }
        if (!d || typeof d !== "object")
            return;

        root.snap = d;
        root.stateTs = d.ts || 0;
        root.source = d.source || "";
        root.lastError = d.error || "";
        root.online = (Date.now() / 1000 - root.stateTs) < 12 && root.source !== "offline";

        var fresh = [];
        var rec = d.recent || [];
        for (var i = 0; i < rec.length; i++) {
            if (rec[i].n > root.seq)
                fresh.push(rec[i]);
        }
        var newSeq = d.seq || root.seq;
        // Beim allerersten Laden nicht den ganzen Puffer auf einmal einregnen lassen
        if (root.seq === 0) {
            fresh = fresh.slice(-12);
        }
        root.seq = newSeq;
        if (fresh.length > 0)
            root.transactionsArrived(fresh);

        var be = d.blockEvent || 0;
        if (be > root.blockEventTs) {
            var first = root.blockEventTs === 0;
            root.blockEventTs = be;
            if (!first)
                root.blockMined(d.tip || {});
        }
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.__get("/state", "__statePending", root.__parse, function () {
            root.online = false;
        })
    }

    // Der Daemon holt die Blockdaten nach dem Blockfund im Hintergrund nach,
    // deshalb wird hier nachgefasst, bis die Hoehe passt.
    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (root.block.height && root.block.height === root.tipHeight)
                return;
            root.__get("/block", "__blockPending", function (txt) {
                try {
                    var b = JSON.parse(txt);
                    if (b && b.height)
                        root.block = b;
                } catch (e) {}
            });
        }
    }
}
