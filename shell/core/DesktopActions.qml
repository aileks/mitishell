pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var screenshotModes: []
    property var outputNames: []
    property bool ocrAvailable: false
    property bool qrAvailable: false
    property var recordingModes: []
    property bool recordingActive: false
    property var powerProfiles: []
    property bool firmwareAvailable: false
    property string error: ""
    property string successMessage: ""

    readonly property bool actionRunning: actionProcess.running

    function refresh() {
        if (!snapshotProcess.running) snapshotProcess.running = true;
    }

    function run(args, success) {
        if (actionProcess.running || !Array.isArray(args) || args.length === 0) {
            return false;
        }
        error = "";
        successMessage = String(success || "");
        actionProcess.command = [Config.binary, "_desktop-action"].concat(args);
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
                    || "Actions could not be refreshed.";
                return;
            }
            try {
                const snapshot = JSON.parse(snapshotOutput.text);
                root.screenshotModes = snapshot.screenshotModes || [];
                root.outputNames = snapshot.outputNames || [];
                root.ocrAvailable = snapshot.ocrAvailable === true;
                root.qrAvailable = snapshot.qrAvailable === true;
                root.recordingModes = snapshot.recordingModes || [];
                root.recordingActive = snapshot.recordingActive === true;
                root.powerProfiles = snapshot.powerProfiles || [];
                root.firmwareAvailable = snapshot.firmwareAvailable === true;
                root.error = "";
            } catch (parseError) {
                root.error = "Actions could not be read.";
            }
        }
    }

    property Process actionProcess: Process {
        stderr: StdioCollector { id: actionErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.error = actionErrors.text.trim() || "Action failed.";
                Osd.showGeneric(Icons.warning, "Action failed", "", "2200");
            } else if (root.successMessage !== "") {
                Osd.showGeneric(Icons.check, root.successMessage, "", "1400");
            }
            root.successMessage = "";
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
