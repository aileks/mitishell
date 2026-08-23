pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Session power over the Go companion: logind capability queries and
    // action execution. Lock and logout are always offered; suspend and
    // hibernate depend on the system.

    property bool suspendAvailable: false
    property bool hibernateAvailable: false
    property string error: ""

    function refresh() {
        if (!capabilityProcess.running) {
            capabilityProcess.running = true;
        }
    }

    function run(action) {
        error = "";
        runProcess.command = [Config.binary, "_power-action", action];
        runProcess.running = true;
    }

    property Process capabilityProcess: Process {
        id: capabilityProcess

        command: [Config.binary, "_power-capabilities"]
        stdout: StdioCollector {
            id: capabilityOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: capabilityErrors
            waitForEnd: true
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = capabilityErrors.text.trim() || "power capabilities unavailable";
                return;
            }
            try {
                const capabilities = JSON.parse(capabilityOutput.text);
                root.suspendAvailable = capabilities.suspend === true;
                root.hibernateAvailable = capabilities.hibernate === true;
                root.error = "";
            } catch (parseError) {
                root.error = "could not parse power capabilities";
            }
        }
    }

    property Process runProcess: Process {
        id: runProcess

        stderr: StdioCollector {
            id: runErrors
            waitForEnd: true
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = runErrors.text.trim() || "power action failed";
            }
        }
    }

    Component.onCompleted: refresh()
}
