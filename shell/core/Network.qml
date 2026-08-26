pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // NetworkManager status through the Go companion. The page drives
    // refresh polling; the service holds the latest snapshot and runs
    // join and forget actions.

    property string state: "loading"
    property var snapshot: null
    property string error: ""
    property bool joining: false
    property bool wifiBusy: false

    readonly property var wifi: snapshot !== null ? snapshot.wifi : null
    readonly property var ethernet: snapshot !== null ? snapshot.ethernet : null

    function refresh() {
        if (!snapshotProcess.running) {
            snapshotProcess.running = true;
        }
    }

    function connectToNetwork(ssid, password, hidden) {
        joining = true;
        error = "";
        const command = [Config.binary, "_network-connect"];
        if (hidden) {
            command.push("--hidden");
        }
        command.push(ssid, password);
        joinProcess.command = command;
        joinProcess.running = true;
    }

    function forget(ssid) {
        error = "";
        forgetProcess.command = [Config.binary, "_network-forget", ssid];
        forgetProcess.running = true;
    }

    function setWifiEnabled(enabled) {
        wifiBusy = true;
        error = "";
        wifiPowerProcess.command = [
            Config.binary,
            "_network-wifi",
            enabled ? "on" : "off",
        ];
        wifiPowerProcess.running = true;
    }

    property Process snapshotProcess: Process {
        id: snapshotProcess

        command: [Config.binary, "_network-snapshot"]
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
                // Keep the previous snapshot object while the data is
                // unchanged so the page's bindings, and with them the
                // station list delegates, survive each poll without
                // rebuilding mid-interaction.
                if (root.snapshot === null
                        || JSON.stringify(parsed) !== JSON.stringify(root.snapshot)) {
                    root.snapshot = parsed;
                }
                root.state = "ready";
                root.error = "";
            } catch (parseError) {
                root.state = "unavailable";
                root.error = exitCode === 0
                    ? "could not parse network data" : snapshotErrors.text.trim();
            }
        }
    }

    property Process joinProcess: Process {
        id: joinProcess

        stderr: StdioCollector {
            id: joinErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            root.joining = false;
            if (exitCode !== 0) {
                root.error = joinErrors.text.trim() || "could not join network";
            }
            root.refresh();
        }
    }

    property Process forgetProcess: Process {
        id: forgetProcess

        stderr: StdioCollector {
            id: forgetErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = forgetErrors.text.trim() || "could not forget network";
            }
            root.refresh();
        }
    }

    property Process wifiPowerProcess: Process {
        id: wifiPowerProcess

        stderr: StdioCollector {
            id: wifiPowerErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            root.wifiBusy = false;
            if (exitCode !== 0) {
                root.error = wifiPowerErrors.text.trim() || "could not change Wi-Fi state";
            }
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
