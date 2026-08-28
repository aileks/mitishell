pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    property bool enabled: false
    property int temperatureKelvin: 0
    property string error: ""
    readonly property bool busy: actionProcess.running
    readonly property string description: available && enabled
        ? "On · " + temperatureKelvin + " K"
        : ""

    function applySnapshot(snapshot) {
        available = snapshot.available === true;
        enabled = snapshot.enabled === true;
        temperatureKelvin = Number(snapshot.temperatureKelvin || 0);
        error = String(snapshot.error || "");
    }

    function refresh() {
        if (!snapshotProcess.running && !actionProcess.running) {
            snapshotProcess.running = true;
        }
    }

    function toggle() {
        if (!available || actionProcess.running) return;
        error = "";
        actionProcess.running = true;
    }

    property Process snapshotProcess: Process {
        command: [Config.binary, "_night-light-snapshot"]
        stdout: StdioCollector {
            id: snapshotOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: snapshotErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            try {
                root.applySnapshot(JSON.parse(snapshotOutput.text));
            } catch (parseError) {
                root.available = false;
                root.error = snapshotErrors.text.trim()
                    || "Night-light state could not be read.";
            }
        }
    }

    property Process actionProcess: Process {
        command: [Config.binary, "_night-light-action", "toggle"]
        stdout: StdioCollector {
            id: actionOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: actionErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            try {
                root.applySnapshot(JSON.parse(actionOutput.text));
            } catch (parseError) {
                root.available = false;
                root.error = actionErrors.text.trim() || "Night-light action failed.";
            }
            if (exitCode === 0 && root.available) {
                Osd.showNightLight(root.enabled, root.temperatureKelvin);
            }
            root.refresh();
        }
    }

    property Timer pollTimer: Timer {
        interval: SurfaceCoordinator.activeKey === "settings" ? 2000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
