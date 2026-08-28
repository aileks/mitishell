pragma Singleton

import QtQuick
import Quickshell.Io

// Enumerates installed Nerd Font families through the CLI's hidden
// `_fonts` verb. Feeds the Settings font picker; refresh() runs when a
// picker becomes visible instead of at shell startup.
QtObject {
    id: root

    property var families: []
    property string error: ""

    property Process lister: Process {
        id: lister

        command: [Config.binary, "_fonts"]
        stdout: StdioCollector {
            id: output
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: errors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode === 0) {
                try {
                    root.families = JSON.parse(output.text);
                    root.error = "";
                } catch (parseError) {
                    root.families = [];
                    root.error = "Could not read installed fonts";
                }
            } else {
                root.families = [];
                root.error = errors.text.trim() || "Could not read installed fonts";
            }
        }
    }

    function refresh() {
        if (!lister.running) {
            lister.running = true;
        }
    }
}
