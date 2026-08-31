pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/ClipboardModel.js" as ClipboardModel

QtObject {
    id: root

    // Copies are recorded by the _clipboard-record verb through
    // wl-paste --watch; this singleton mirrors the typed state file, handles
    // removal and clearing, and performs re-copies.
    property var entries: []
    property string persistenceError: ""
    property bool historyLoaded: false
    property bool savePending: false
    property bool clearPending: false
    property string pendingSavePayload: ""
    property bool watcherAvailable: false

    readonly property bool available: Config.clipboard.enabled && watcherAvailable



    function preview(entry) {
        return ClipboardModel.preview(entry);
    }

    function detail(entry) {
        return ClipboardModel.detail(entry);
    }

    function keywords(entry) {
        return ClipboardModel.keywords(entry);
    }

    function removeEntry(id) {
        entries = ClipboardModel.removeEntry(entries, id);
        queueSave();
    }

    function copy(entry) {
        if (!entry) return;
        // The watch loop records the copy, which also moves it to the top.
        if (entry.kind === "image") {
            if (!copyProcess.running) {
                copyProcess.command = [Config.binary, "_clipboard-copy-image", entry.id];
                copyProcess.running = true;
            }
        } else {
            Quickshell.clipboardText = String(entry.text || "");
        }
    }

    function clear() {
        entries = [];
        savePending = false;
        clearPending = true;
        pumpPersistence();
    }

    function queueSave() {
        pendingSavePayload = JSON.stringify({
            version: 2,
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
            // Only an explicit disable wipes history; startup resolves and
            // unrelated settings edits must never touch the stored file.
            if (!Config.clipboard.enabled) {
                root.clear();
                root.watcher.running = false;
                return;
            }
            if (root.watcherAvailable) {
                root.watcher.running = true;
            }
            if (root.entries.length > Config.clipboard.maxEntries) {
                root.entries = root.entries.slice(0, Config.clipboard.maxEntries);
                root.queueSave();
            }
        }
    }

    // The watch loop owns recording; without wl-clipboard the shell cannot
    // observe copies, so the whole feature hides (extra tools rule).
    property Process watcherProbe: Process {
        command: ["sh", "-c", "command -v wl-paste && command -v wl-copy"]
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
        command: ["wl-paste", "--watch", Config.binary, "_clipboard-record"]
    }

    property Process copyProcess: Process {
        stderr: StdioCollector { id: copyErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.persistenceError = exitCode === 0
                ? ""
                : (copyErrors.text.trim() || "Clipboard image could not be copied.");
        }
    }

    property FileView historyFile: FileView {
        path: root.stateFilePath()
        watchChanges: true
        onFileChanged: {
            if (Config.clipboard.enabled && !root.savePending && !root.clearPending) {
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
            if (!Config.clipboard.enabled) {
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
                root.entries = loaded.slice(0, Config.clipboard.maxEntries);
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
