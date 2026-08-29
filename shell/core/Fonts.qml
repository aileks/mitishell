pragma Singleton

import QtQuick
import Quickshell.Io

// Enumerates installed font families through the CLI's hidden `_fonts`
// verb and owns the Settings font picker state. `families` holds every
// family for the standard picker; `nerdFamilies` holds the Nerd Font
// subset the mono picker offers because icons are Nerd Font glyphs.
// refresh() runs when the picker opens instead of at shell startup.
QtObject {
    id: root

    property var families: []
    property var nerdFamilies: []
    property string error: ""
    // Active picker slot: "" when closed, otherwise "standard" or "mono".
    property string pickerSlot: ""

    function openPicker(slot) {
        pickerSlot = slot;
        refresh();
    }

    function closePicker() {
        pickerSlot = "";
    }

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
                    const catalog = JSON.parse(output.text);
                    root.families = catalog.families;
                    root.nerdFamilies = catalog.nerdFamilies;
                    root.error = "";
                } catch (parseError) {
                    root.families = [];
                    root.nerdFamilies = [];
                    root.error = "Could not read installed fonts";
                }
            } else {
                root.families = [];
                root.nerdFamilies = [];
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
