pragma Singleton

import QtQuick
import Quickshell.Io
import "../lib/DisplayModel.js" as DisplayModel

QtObject {
    id: root

    // One logical brightness drives every DDC display. Writes are optimistic
    // (the value moves immediately for the OSD) and coalesced: rapid steps
    // collapse into one `_display-set` per settle window, and a new write
    // only starts once the previous one exits.

    property string state: "discovering"
    property var displays: []
    property int brightness: 100
    property string error: ""

    readonly property bool available: state === "ready" && displays.length > 0

    function refresh() {
        if (!discoverProcess.running) {
            discoverProcess.running = true;
        }
    }

    function setBrightness(value) {
        brightness = DisplayModel.clampBrightness(value);
        pendingValue = brightness;
        writeTimer.restart();
    }

    function stepBrightness(delta) {
        setBrightness(DisplayModel.stepBrightness(brightness, delta));
    }

    function flushWrite() {
        if (writeProcess.running || pendingValue === appliedValue) {
            return;
        }
        appliedValue = pendingValue;
        writeProcess.command = [Config.binary, "_display-set", "all", String(appliedValue)];
        writeProcess.running = true;
    }

    // pendingValue is the newest requested brightness; appliedValue is what
    // the last write sent. They only match when the hardware is up to date.
    property int pendingValue: -1
    property int appliedValue: -1

    property Process discoverProcess: Process {
        id: discoverProcess

        command: [Config.binary, "_display-discover"]
        stdout: StdioCollector {
            id: discoverOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: discoverErrors
            waitForEnd: true
        }

        onExited: function(exitCode) {
            try {
                const result = JSON.parse(discoverOutput.text);
                root.state = result.state === "ready" ? "ready" : "unavailable";
                root.displays = result.displays || [];
                root.error = result.error || discoverErrors.text.trim();
                if (root.displays.length > 0) {
                    // The darkest display anchors the shared value, so a
                    // raise lifts every panel from a visible baseline.
                    root.brightness = DisplayModel.clampBrightness(
                        Math.min.apply(null, root.displays.map(function(display) {
                            return display.brightness;
                        })));
                    root.pendingValue = -1;
                    root.appliedValue = -1;
                }
            } catch (parseError) {
                root.state = "unavailable";
                root.displays = [];
                root.error = exitCode === 0
                    ? "could not parse display data"
                    : discoverErrors.text.trim();
            }
        }
    }

    property Process writeProcess: Process {
        id: writeProcess

        stdout: StdioCollector {
            id: writeOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: writeErrors
            waitForEnd: true
        }

        onExited: function(exitCode) {
            try {
                const result = JSON.parse(writeOutput.text);
                if (result.state === "ready") {
                    root.displays = result.displays || root.displays;
                    root.error = "";
                } else {
                    // A failed write leaves the optimistic value unreliable;
                    // stop writing until the next explicit change.
                    root.error = result.error || writeErrors.text.trim();
                    root.pendingValue = root.appliedValue;
                }
            } catch (parseError) {
                root.error = writeErrors.text.trim() || "could not apply brightness";
                root.pendingValue = root.appliedValue;
            }
            if (root.pendingValue !== root.appliedValue) {
                root.writeTimer.restart();
            }
        }
    }

    property Timer writeTimer: Timer {
        interval: 200
        onTriggered: root.flushWrite()
    }

    Component.onCompleted: refresh()
}
