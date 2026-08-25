pragma Singleton

import QtQuick
import Quickshell.Io

// Writes config fields through the CLI's `config set` so validation stays
// in Go and the existing file watcher reloads the shell live. Slider
// changes queue behind a debounce; every write reports its per-field
// error back for inline display.
QtObject {
    id: root

    property var fieldErrors: ({})

    // Serializes writes: the CLI re-reads the config file per write, so
    // concurrent writes would race each other's updates.
    property var writeQueue: []
    property string writeKey: ""
    property var writer: Process {
        id: writer

        stdout: StdioCollector {
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: writeErrors

            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode === 0) {
                root.clearError(root.writeKey);
            } else {
                root.setError(root.writeKey, writeErrors.text.trim());
            }
            // Defer so the process has fully reported stopped before the
            // next write starts.
            Qt.callLater(root.pump);
        }
    }

    property var debounce: Timer {
        interval: 350
        onTriggered: root.flush()
    }

    function setField(key, value) {
        enqueue(key, value);
        pump();
    }

    function queueField(key, value) {
        enqueue(key, value);
        debounce.restart();
    }

    // A queued write replaces an earlier pending write for the same field.
    function enqueue(key, value) {
        for (let index = 0; index < writeQueue.length; index++) {
            if (writeQueue[index].key === key) {
                writeQueue[index].value = value;
                return;
            }
        }
        writeQueue.push({ key: key, value: value });
    }

    function flush() {
        if (!writer.running) {
            pump();
        }
    }

    function pump() {
        if (writeQueue.length === 0 || writer.running) {
            return;
        }
        const next = writeQueue.shift();
        writeKey = next.key;
        writer.command = [Config.binary, "config", "set", next.key, next.value];
        writer.running = true;
    }

    function setError(key, message) {
        const cleaned = message.replace(/^mitishell: /, "");
        const updated = {};
        Object.assign(updated, fieldErrors);
        updated[key] = cleaned === "" ? "could not save setting" : cleaned;
        fieldErrors = updated;
    }

    function clearError(key) {
        if (fieldErrors[key] === undefined) {
            return;
        }
        const updated = {};
        Object.assign(updated, fieldErrors);
        delete updated[key];
        fieldErrors = updated;
    }
}
