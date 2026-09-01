// Liest den von ~/.local/bin/btcfeed geschriebenen Zustand und meldet
// neue Transaktionen sowie gefundene Bloecke als Signale weiter.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false

    property bool active: true
    // Gleiche Wahl wie btcfeed: tmpfs, sonst ~/.local/state
    readonly property string stateDir: (Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.local/state")) + "/btcfeed"
    property string statePath: stateDir + "/state.json"
    property int pollMs: 400
    property bool autostart: true
    property string feedCommand: Quickshell.env("HOME") + "/.local/bin/btcfeed"

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

    signal transactionsArrived(var txs)
    signal blockMined(var tip)

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

    FileView {
        id: blockFile

        path: root.active ? root.stateDir + "/block.json" : ""
        blockLoading: false
        printErrors: false

        onLoaded: {
            try {
                var b = JSON.parse(text());
                if (b && b.height)
                    root.block = b;
            } catch (e) {}
        }
    }

    // Der Daemon holt die Blockdaten nach dem Blockfund im Hintergrund nach,
    // deshalb wird hier nachgefasst, bis die Hoehe passt.
    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!root.block.height || root.block.height !== root.tipHeight)
                blockFile.reload();
        }
    }

    FileView {
        id: stateFile

        path: root.active ? root.statePath : ""
        blockLoading: false
        watchChanges: true
        printErrors: false

        onLoaded: root.__parse(text())
        onLoadFailed: root.online = false
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: root.active
        onTriggered: stateFile.reload()
    }

    // Startet den Feed, falls niemand ihn schreibt. Die Sperre in btcfeed
    // sorgt dafuer, dass hoechstens eine Instanz laeuft.
    Process {
        id: feedProc
        command: [root.feedCommand]
        running: false
    }

    Timer {
        id: watchdog
        interval: 6000
        repeat: true
        running: root.active && root.autostart
        triggeredOnStart: true
        onTriggered: {
            var stale = (Date.now() / 1000 - root.stateTs) > 15;
            if (stale && !feedProc.running)
                feedProc.running = true;
        }
    }
}
