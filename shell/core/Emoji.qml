pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/EmojiModel.js" as EmojiModel

QtObject {
    id: root

    property var catalog: []
    property var recents: []
    property string catalogError: ""
    property string persistenceError: ""
    property bool recentsLoaded: false
    property bool recentsDirty: false
    property bool savePending: false
    property bool clearPending: false
    property string pendingSavePayload: ""

    readonly property var categories: EmojiModel.categories

    function entries(query, category) {
        return EmojiModel.filterCatalog(
            catalog,
            query,
            category,
            recents,
            EmojiModel.resultLimit,
        );
    }

    function initialCategory() {
        return EmojiModel.initialCategory(recents);
    }

    function addRecent(value) {
        recents = EmojiModel.addRecent(recents, value);
        recentsDirty = true;
        queueSave();
    }

    function queueSave() {
        pendingSavePayload = JSON.stringify({
            version: 1,
            entries: recents,
        });
        savePending = true;
        pumpPersistence();
    }

    function clearRecents() {
        recents = [];
        recentsDirty = true;
        savePending = false;
        clearPending = true;
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

    property FileView catalogFile: FileView {
        path: Quickshell.shellDir + "/assets/emoji/catalog.json"

        onLoaded: {
            root.catalog = EmojiModel.parseCatalog(text());
            root.catalogError = root.catalog.length > 0
                ? "" : "The emoji catalog is empty.";
        }
        onLoadFailed: root.catalogError = "The emoji catalog could not be loaded."
    }

    property Process loadProcess: Process {
        command: [Config.binary, "_emoji-recents-load"]
        stdout: StdioCollector {
            id: loadOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: loadErrors
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.persistenceError = loadErrors.text.trim()
                    || "Emoji recents could not be loaded.";
                root.recentsLoaded = true;
                return;
            }
            try {
                const loaded = JSON.parse(loadOutput.text).entries || [];
                root.recents = root.recentsDirty
                    ? loaded.reduce(function(current, value) {
                        return EmojiModel.addRecent(current, value);
                    }, root.recents)
                    : loaded.slice(0, EmojiModel.recentLimit);
                root.persistenceError = "";
            } catch (parseError) {
                root.persistenceError = "Emoji recents could not be read.";
            }
            root.recentsLoaded = true;
        }
    }

    property Process saveProcess: Process {
        command: [Config.binary, "_emoji-recents-save"]
        stdinEnabled: true
        stderr: StdioCollector {
            id: saveErrors
            waitForEnd: true
        }

        onStarted: write(root.pendingSavePayload)
        onExited: function(exitCode, exitStatus) {
            root.persistenceError = exitCode === 0
                ? ""
                : (saveErrors.text.trim() || "Emoji recents could not be saved.");
            root.pumpPersistence();
        }
    }

    property Process clearProcess: Process {
        command: [Config.binary, "_emoji-recents-clear"]
        stderr: StdioCollector {
            id: clearErrors
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            root.clearPending = false;
            root.persistenceError = exitCode === 0
                ? ""
                : (clearErrors.text.trim() || "Emoji recents could not be cleared.");
            root.pumpPersistence();
        }
    }

    Component.onCompleted: loadProcess.running = true
}
