// Haelt den Feed-Prozess am Leben, solange das Plugin aktiv ist.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Den **Dienst** anstossen, nicht einen eigenen Prozess starten: sonst gibt
    // es zwei Verwalter fuer einen Daemon. Der Rueckfall auf das Programm
    // greift, wenn die Unit nicht eingerichtet ist (tools/install-links.sh).
    property var feedCommand: ["sh", "-c",
        "systemctl --user start orangedeck.service 2>/dev/null || exec \"$HOME/.local/bin/orangedeck\""]
    property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.local/state")) + "/orangedeck/state.json"

    Process {
        id: feedProc

        command: root.feedCommand
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("orangedeck:", text.trim());
            }
        }
    }

    FileView {
        id: probe

        path: root.statePath
        blockLoading: false
        printErrors: false
    }

    // Alle 10 s pruefen, ob der Zustand frisch ist. Die Dateisperre in orangedeck
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
        target: "orangedeck"

        function restart(): string {
            feedProc.running = false;
            feedProc.running = true;
            return "orangedeck neu gestartet";
        }

        function status(): string {
            probe.reload();
            return probe.text() || "kein Zustand";
        }
    }
}
