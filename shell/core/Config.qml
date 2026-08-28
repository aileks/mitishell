pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/ConfigModel.js" as ConfigModel

QtObject {
    id: root

    readonly property var defaults: ({
        "version": 2,
        "bar": {
            "outputs": ["*"],
            "height": 36,
            "marginTop": 6,
            "marginHorizontal": 8,
            "systemMetrics": "separate",
            "layout": {
                "left": ["workspaces", "windowTitle"],
                "center": ["media"],
                "right": ["system", "audio", "keyboardLayout", "updates", "clock", "tray", "bluetooth", "quickSettings", "notifications", "weather", "status", "power"],
                "hidden": ["network"]
            }
        },
        "weather": {
            "enabled": false,
            "units": "auto",
            "location": ""
        },
        "clock": {
            "format": "24h",
            "showDate": false,
            "timezones": []
        },
        "calendar": {
            "showWeekNumbers": false
        },
        "motion": {
            "enabled": true,
            "reduced": false
        },
        "font": {
            "family": ""
        }
    })
    property var value: defaults
    property bool loaded: false
    property string error: ""

    readonly property var bar: value.bar
    readonly property var weather: value.weather
    readonly property var clock: value.clock
    readonly property var calendar: value.calendar
    readonly property var motion: value.motion
    readonly property var font: value.font
    readonly property string binary: Quickshell.env("MITISHELL_BIN") || "mitishell"
    readonly property string configRoot: Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: configRoot + "/mitishell/config.json"

    readonly property var screenNames: {
        const screens = Quickshell.screens !== undefined ? Quickshell.screens : [];
        return screens.map(function(screen) { return screen.name; });
    }

    // Connectors that should host a bar right now; falls back to the first
    // live screen when every configured connector has vanished.
    readonly property var barTargetConnectors: ConfigModel.barTargets(
        bar.outputs,
        screenNames,
    )

    function outputEnabled(connector) {
        return barTargetConnectors.indexOf(connector) !== -1;
    }

    function refresh() {
        if (!resolver.running) {
            resolver.running = true;
        }
    }

    property Process resolverProcess: Process {
        id: resolver

        command: [root.binary, "_config-resolve"]
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
            try {
                const parsed = JSON.parse(output.text);
                if (exitCode === 0 || !root.loaded) {
                    root.value = parsed;
                }
                root.error = exitCode === 0 ? "" : errors.text.trim();
                root.loaded = true;
            } catch (parseError) {
                root.error = "could not parse normalized config: " + parseError;
            }
        }
    }

    property FileView configWatcher: FileView {
        path: root.configPath
        watchChanges: true
        onFileChanged: root.refresh()
    }

    Component.onCompleted: refresh()
}
