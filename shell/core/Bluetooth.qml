pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // BlueZ through the Go companion: snapshot polling, device actions, and
    // the resident pairing agent whose requests land here through the
    // bluetooth IPC target.

    property string state: "loading"
    property var snapshot: null
    property string error: ""
    property var pairRequest: null

    readonly property var adapter: snapshot !== null ? snapshot.adapter : null
    readonly property var devices: snapshot !== null ? snapshot.devices : []
    readonly property bool scanning: scanProcess.running

    property bool stoppingScan: false

    function refresh() {
        if (!snapshotProcess.running) {
            snapshotProcess.running = true;
        }
    }

    function action(verb, address) {
        error = "";
        actionProcess.command = [Config.binary, "_bluetooth-action", verb, address];
        actionProcess.running = true;
    }

    function setDiscovering(discovering) {
        if (discovering === scanProcess.running) {
            return;
        }
        error = "";
        stoppingScan = !discovering;
        scanProcess.running = discovering;
        if (discovering) {
            stoppingScan = false;
            refresh();
        }
    }

    function handlePairRequest(payload) {
        try {
            const request = JSON.parse(payload);
            pairRequest = request;
            pairDisplayTimer.restart();
        } catch (parseError) {
            // A malformed pairing push is dropped; the agent times out on
            // its own and BlueZ reports the failure.
        }
    }

    function respond(value) {
        if (pairRequest === null) {
            return;
        }
        respondProcess.command = [
            Config.binary,
            "_bluetooth-respond",
            pairRequest.id,
            value,
        ];
        respondProcess.running = true;
        pairRequest = null;
        refresh();
    }

    property Process snapshotProcess: Process {
        id: snapshotProcess

        command: [Config.binary, "_bluetooth-snapshot"]
        stdout: StdioCollector {
            id: snapshotOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: snapshotErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            try {
                const parsed = JSON.parse(snapshotOutput.text);
                if (parsed.error !== undefined && parsed.error !== "") {
                    root.state = "unavailable";
                    root.error = parsed.error;
                    return;
                }
                root.snapshot = parsed;
                root.state = "ready";
                root.error = "";
            } catch (parseError) {
                root.state = "unavailable";
                root.error = exitCode === 0
                    ? "could not parse bluetooth data" : snapshotErrors.text.trim();
            }
        }
    }

    property Process actionProcess: Process {
        id: actionProcess

        stderr: StdioCollector {
            id: actionErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = actionErrors.text.trim() || "bluetooth action failed";
            }
            root.refresh();
        }
    }

    property Process scanProcess: Process {
        id: scanProcess

        command: [Config.binary, "_bluetooth-scan"]
        stderr: StdioCollector {
            id: scanErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (!root.stoppingScan && exitCode !== 0) {
                root.error = scanErrors.text.trim() || "Bluetooth scan failed";
            }
            root.stoppingScan = false;
            root.refresh();
        }
    }

    property Process respondProcess: Process {
        id: respondProcess

        stderr: StdioCollector {
            id: respondErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = respondErrors.text.trim() || "pairing response failed";
            }
        }
    }

    // The pairing agent stays registered for the whole session so pairing
    // works whenever a device asks; it restarts quietly if it dies.
    property Process agentProcess: Process {
        id: agentProcess

        command: [Config.binary, "_bluetooth-agent"]
        running: true

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.agentRestart.restart();
            }
        }
    }

    property Timer agentRestart: Timer {
        interval: 3000
        onTriggered: agentProcess.running = true
    }

    property Timer pairDisplayTimer: Timer {
        interval: 12000
        onTriggered: root.pairRequest = null
    }

    Component.onCompleted: refresh()
}
