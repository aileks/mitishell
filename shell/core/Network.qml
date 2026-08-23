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

        onExited: function(exitCode) {
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

        onExited: function(exitCode) {
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

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = forgetErrors.text.trim() || "could not forget network";
            }
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
