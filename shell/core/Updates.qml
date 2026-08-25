pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string state: "loading"
    property var result: null
    property string error: ""
    readonly property bool visible: result !== null && result.supported
    readonly property int count: result === null ? 0 : result.system.count + result.aur.count

    function refresh() {
        if (!snapshotProcess.running) {
            state = "loading";
            snapshotProcess.running = true;
        }
    }

    function launchUpdate() {
        if (result !== null && result.updateCommand && result.updateCommand.length > 0) {
            Quickshell.execDetached(result.updateCommand);
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

    property Timer refreshTimer: Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
