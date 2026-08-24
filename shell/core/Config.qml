pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/ConfigModel.js" as ConfigModel

QtObject {
    id: root

    readonly property var defaults: ({
        "version": 1,
        "bar": {
            "outputs": ["*"],
            "height": 36,
            "marginTop": 6,
            "marginHorizontal": 8,
            "showWindowTitle": true,
            "showMedia": true,
            "systemMetrics": "separate",
            "islands": ["system", "audio", "keyboardLayout", "updates", "clock", "tray", "control", "notifications", "reminders", "weather", "power"]
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
    readonly property string binary: Quickshell.env("MITISHELL_BIN") || "mitishell"
    readonly property string configRoot: Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: configRoot + "/mitishell/config.json"

    function outputEnabled(connector) {
        return ConfigModel.outputEnabled(bar.outputs, connector);
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

        onExited: function(exitCode, exitStatus) {
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
