pragma Singleton

import QtQuick
import Quickshell.Io

// Temporary bridge to wlogout until the native power menu lands.
QtObject {
    id: root

    property bool powerAvailable: false
    property bool loaded: false
    property string error: ""

    function openPowerMenu() {
        if (!powerAvailable) {
            return false;
        }
        SurfaceCoordinator.close();
        if (!powerProcess.running) {
            error = "";
            powerProcess.running = true;
        }
        return true;
    }

    property Process detectorProcess: Process {
        id: detector

        command: [Config.binary, "_capabilities"]
        stdout: StdioCollector {
            id: detectorOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: detectorErrors
            waitForEnd: true
        }

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = detectorErrors.text.trim() || "capability detection failed";
                root.loaded = true;
                return;
            }

            try {
                const capabilities = JSON.parse(detectorOutput.text);
                root.powerAvailable = capabilities.power === true;
                root.error = "";
            } catch (parseError) {
                root.error = "could not parse capabilities: " + parseError;
            }
            root.loaded = true;
        }
    }

    property Process powerActionProcess: Process {
        id: powerProcess

        command: [
            "wlogout",
            "-b", "3",
            "-c", "20",
            "-r", "20",
            "-L", "900",
            "-R", "900",
            "-T", "550",
            "-B", "550"
        ]
        stderr: StdioCollector {
            id: powerErrors
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.error = powerErrors.text.trim() || "wlogout could not be opened";
            }
        }
    }

    Component.onCompleted: detector.running = true
}
