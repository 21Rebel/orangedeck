// Haelt den Feed-Prozess am Leben, solange das Plugin aktiv ist.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string feedCommand: Quickshell.env("HOME") + "/.local/bin/btcfeed"
    property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.local/state")) + "/btcfeed/state.json"

    Process {
        id: feedProc

        command: [root.feedCommand]
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("btcfeed:", text.trim());
            }
        }
    }

    FileView {
        id: probe

        path: root.statePath
        blockLoading: false
        printErrors: false
    }

    // Alle 10 s pruefen, ob der Zustand frisch ist. Die Dateisperre in btcfeed
    // verhindert, dass mehrere Instanzen nebeneinander laufen.
    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            probe.reload();
            var stale = true;
            try {
                var d = JSON.parse(probe.text() || "{}");
                stale = (Date.now() / 1000 - (d.ts || 0)) > 20;
            } catch (e) {}
            if (stale && !feedProc.running)
                feedProc.running = true;
        }
    }

    IpcHandler {
        target: "bitcoinFeed"

        function restart(): string {
            feedProc.running = false;
            feedProc.running = true;
            return "btcfeed neu gestartet";
        }

        function status(): string {
            probe.reload();
            return probe.text() || "kein Zustand";
        }
    }
}
