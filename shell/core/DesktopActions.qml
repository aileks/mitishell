pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var screenshotCommand: []
    property var ocrCommand: []
    property var qrCommand: []
    property var recordingCommand: []
    property bool recordingActive: false
    property var powerCommand: []
    property var powerProfiles: []
    property var firmwareCommand: []
    property string error: ""
    property string successMessage: ""

    readonly property bool actionRunning: actionProcess.running

    function refresh() {
        if (!snapshotProcess.running) snapshotProcess.running = true;
    }

    function run(command, success) {
        if (actionProcess.running || !Array.isArray(command) || command.length === 0) {
            return false;
        }
        error = "";
        successMessage = String(success || "");
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    property Process snapshotProcess: Process {
        command: [Config.binary, "_desktop-actions-snapshot"]
        stdout: StdioCollector { id: snapshotOutput; waitForEnd: true }
        stderr: StdioCollector { id: snapshotErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = snapshotErrors.text.trim()
                    || "Desktop actions could not be refreshed.";
                return;
            }
            try {
                const snapshot = JSON.parse(snapshotOutput.text);
                root.screenshotCommand = snapshot.screenshotCommand || [];
                root.ocrCommand = snapshot.ocrCommand || [];
                root.qrCommand = snapshot.qrCommand || [];
                root.recordingCommand = snapshot.recordingCommand || [];
                root.recordingActive = snapshot.recordingActive === true;
                root.powerCommand = snapshot.powerCommand || [];
                root.powerProfiles = snapshot.powerProfiles || [];
                root.firmwareCommand = snapshot.firmwareCommand || [];
                root.error = "";
            } catch (parseError) {
                root.error = "Desktop actions could not be read.";
            }
        }
    }

    property Process actionProcess: Process {
        stderr: StdioCollector { id: actionErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = actionErrors.text.trim() || "Desktop action failed.";
                Osd.showGeneric(Icons.warning, "Desktop action failed", "", "2200");
            } else if (root.successMessage !== "") {
                Osd.showGeneric(Icons.check, root.successMessage, "", "1400");
            }
            root.successMessage = "";
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
