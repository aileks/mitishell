pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/ClipboardModel.js" as ClipboardModel

QtObject {
    id: root

    // Copies are recorded by the _clipboard-record verb through
    // wl-paste --watch; this singleton mirrors the state file, handles
    // removal and clearing, and performs re-copies.
    property var entries: []
    property string persistenceError: ""
    property bool historyLoaded: false
    property bool savePending: false
    property bool clearPending: false
    property string pendingSavePayload: ""
    property bool watcherAvailable: false

    readonly property bool available: Config.clipboard.enabled && watcherAvailable

    function entryLimit() {
        return ClipboardModel.entryLimit(Config.clipboard.maxEntries);
    }

    function preview(text) {
        return ClipboardModel.preview(text);
    }

    function removeEntry(text) {
        entries = ClipboardModel.removeEntry(entries, text);
        queueSave();
    }

    function copy(text) {
        // The watch loop records the copy, which also moves it to the top.
        Quickshell.clipboardText = text;
    }

    function clear() {
        entries = [];
        savePending = false;
        clearPending = true;
        pumpPersistence();
    }

    function queueSave() {
        pendingSavePayload = JSON.stringify({
            version: 1,
            entries: entries,
        });
        savePending = true;
        pumpPersistence();
    }

    function pumpPersistence() {
        if (saveProcess.running || clearProcess.running) return;
        if (clearPending) {
            clearProcess.running = true;
        } else if (savePending) {
            savePending = false;
            saveProcess.running = true;
        }
    }

    function stateFilePath() {
        const stateRoot = Quickshell.env("XDG_STATE_HOME")
            || (Quickshell.env("HOME") + "/.local/state");
        return stateRoot + "/mitishell/clipboard-history.json";
    }

    property Connections configChanges: Connections {
        target: Config
        function onClipboardChanged() {
            if (!root.available) {
                // Disabled history keeps nothing, in memory or on disk.
                root.clear();
                root.watcher.running = false;
            } else if (root.watcherAvailable) {
                root.watcher.running = true;
            }
        }
    }

    // The watch loop owns recording; without wl-clipboard the shell cannot
    // observe copies, so the whole feature hides (extra tools rule).
    property Process watcherProbe: Process {
        command: ["sh", "-c", "command -v wl-paste"]
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.watcherAvailable = exitCode === 0;
            if (root.watcherAvailable && Config.clipboard.enabled) {
                root.watcher.running = true;
            }
        }
    }

    property Process watcher: Process {
        command: ["wl-paste", "--watch", "sh", "-c",
            "wl-paste -t text -n | '" + Config.binary + "' _clipboard-record"]
    }

    property FileView historyFile: FileView {
        path: root.stateFilePath()
        watchChanges: true
        onFileChanged: {
            if (root.available && !root.savePending && !root.clearPending) {
                root.loadProcess.running = true;
            }
        }
    }

    property Process loadProcess: Process {
        command: [Config.binary, "_clipboard-history-load"]
        stdout: StdioCollector {
            id: loadOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: loadErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (!root.available) {
                root.historyLoaded = true;
                return;
            }
            if (exitCode !== 0) {
                root.persistenceError = loadErrors.text.trim()
                    || "Clipboard history could not be loaded.";
                root.historyLoaded = true;
                return;
            }
            try {
                const loaded = JSON.parse(loadOutput.text).entries || [];
                root.entries = loaded.slice(0, root.entryLimit());
                root.persistenceError = "";
            } catch (parseError) {
                root.persistenceError = "Clipboard history could not be read.";
            }
            root.historyLoaded = true;
        }
    }

    property Process saveProcess: Process {
        command: [Config.binary, "_clipboard-history-save"]
        stdinEnabled: true
        stderr: StdioCollector {
            id: saveErrors
            waitForEnd: true
        }

        onStarted: write(root.pendingSavePayload)
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.persistenceError = exitCode === 0
                ? ""
                : (saveErrors.text.trim() || "Clipboard history could not be saved.");
            root.pumpPersistence();
        }
    }

    property Process clearProcess: Process {
        command: [Config.binary, "_clipboard-history-clear"]
        stderr: StdioCollector {
            id: clearErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.clearPending = false;
            root.persistenceError = exitCode === 0
                ? ""
                : (clearErrors.text.trim() || "Clipboard history could not be cleared.");
            root.pumpPersistence();
        }
    }

    Component.onCompleted: {
        loadProcess.running = true;
        watcherProbe.running = true;
    }
}
