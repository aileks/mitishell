pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../lib/KeybindingModel.js" as KeybindingModel

QtObject {
    id: root

    property var bindings: []
    property bool loaded: false
    property bool stale: false
    property bool refreshPending: false
    property string error: ""
    readonly property bool busy: loadProcess.running

    function refresh() {
        if (loadProcess.running) {
            refreshPending = true;
        } else {
            loadProcess.running = true;
        }
    }

    function finishRefresh() {
        if (refreshPending) {
            refreshPending = false;
            loadProcess.running = true;
        }
    }

    property Process loadProcess: Process {
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { id: bindOutput; waitForEnd: true }
        stderr: StdioCollector { id: bindErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            const parsed = exitCode === 0
                ? KeybindingModel.parseBindings(bindOutput.text)
                : { ok: false, entries: [], error: bindErrors.text.trim() };
            if (parsed.ok) {
                root.bindings = parsed.entries;
                root.loaded = true;
                root.stale = false;
                root.error = "";
            } else {
                root.error = parsed.error || "Hyprland keybinds could not be loaded.";
                root.stale = root.loaded;
            }
            root.finishRefresh();
        }
    }

    property Connections hyprlandEvents: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.refresh();
        }
    }
}
