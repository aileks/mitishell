pragma Singleton

import QtQuick
import Quickshell.Io
import "../lib/UpdatesModel.js" as UpdatesModel

QtObject {
    id: root

    property string state: "loading"
    property var result: null
    property string error: ""
    property string launchError: ""
    readonly property bool updating: updateProcess.running
    readonly property bool visible: result !== null && result.supported && count > 0
    readonly property int count: result === null ? 0 : result.system.count + result.aur.count

    function refresh() {
        if (!snapshotProcess.running) {
            state = "loading";
            snapshotProcess.running = true;
        }
    }

    function launchUpdate() {
        if (!updateProcess.running && result !== null
                && result.updateCommand && result.updateCommand.length > 0) {
            launchError = "";
            state = "updating";
            updateProcess.running = true;
            SurfaceCoordinator.close();
        }
    }

    property Process snapshot: Process {
        id: snapshotProcess
        command: [Config.binary, "_updates-snapshot"]
        stdout: StdioCollector { id: snapshotOutput; waitForEnd: true }
        stderr: StdioCollector { id: snapshotErrors; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            try {
                root.result = JSON.parse(snapshotOutput.text);
                root.error = root.result.system.error || "";
                root.state = root.error === "" ? "ready" : "error";
            } catch (parseError) {
                root.state = "error";
                root.error = snapshotErrors.text.trim() || "Could not read available updates";
            }
        }
    }

    property Process updateProcess: Process {
        command: root.result !== null && root.result.updateCommand
            ? root.result.updateCommand : []

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.launchError = "The terminal update did not finish successfully";
            }
            root.refresh();
        }
    }

    // Checks run when the shell starts and daily at 09:00 local. A failed
    // check retries gently instead of waiting for the next scheduled one.
    property Timer refreshTimer: Timer {
        repeat: false
        running: true
        interval: UpdatesModel.nextDailyDelayMs(9, new Date())
        onTriggered: {
            root.refresh();
            interval = UpdatesModel.nextDailyDelayMs(9, new Date());
            restart();
        }
    }

    // A failed check usually means the shell started before the package
    // tools or network were ready; retry gently instead of waiting for the
    // next scheduled check.
    property Timer retryTimer: Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.state === "error"
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
