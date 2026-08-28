pragma Singleton

import QtQuick
import Quickshell
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

    function supportsConnector(connector) {
        return displays.some(function(display) {
            return display.connector === connector;
        });
    }

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

    // A single-connector write moves only that display and keeps the shared
    // level untouched; it rides its own debounced single-flight pipeline so a
    // slider drag cannot stack ddcutil processes.
    function setConnectorBrightness(connector, value) {
        value = DisplayModel.clampBrightness(value);
        displays = displays.map(function(display) {
            return display.connector === connector
                ? Object.assign({}, display, { brightness: value })
                : display;
        });
        pendingConnector = connector;
        pendingConnectorValue = value;
        connectorWriteTimer.restart();
    }

    function flushWrite() {
        if (writeProcess.running || pendingValue === appliedValue) {
            return;
        }
        appliedValue = pendingValue;
        writeProcess.command = [Config.binary, "_display-set", "all", String(appliedValue)];
        writeProcess.running = true;
    }

    function flushConnectorWrite() {
        if (connectorWriteProcess.running
            || pendingConnectorValue < 0
            || (pendingConnector === appliedConnector
                && pendingConnectorValue === appliedConnectorValue)) {
            return;
        }
        appliedConnector = pendingConnector;
        appliedConnectorValue = pendingConnectorValue;
        connectorWriteProcess.command = [
            Config.binary,
            "_display-set",
            appliedConnector,
            String(appliedConnectorValue),
        ];
        connectorWriteProcess.running = true;
    }

    // pendingValue is the newest requested brightness; appliedValue is what
    // the last write sent. They only match when the hardware is up to date.
    property int pendingValue: -1
    property int appliedValue: -1
    property string pendingConnector: ""
    property int pendingConnectorValue: -1
    property string appliedConnector: ""
    property int appliedConnectorValue: -1

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

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
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

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
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

    property Process connectorWriteProcess: Process {
        id: connectorWriteProcess

        stdout: StdioCollector {
            id: connectorWriteOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: connectorWriteErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            try {
                const result = JSON.parse(connectorWriteOutput.text);
                if (result.state === "ready") {
                    root.displays = result.displays || root.displays;
                    root.error = "";
                } else {
                    root.error = result.error || connectorWriteErrors.text.trim();
                    root.pendingConnectorValue = -1;
                }
            } catch (parseError) {
                root.error = connectorWriteErrors.text.trim() || "could not apply brightness";
                root.pendingConnectorValue = -1;
            }
            if (root.pendingConnector !== root.appliedConnector
                || root.pendingConnectorValue !== root.appliedConnectorValue) {
                root.connectorWriteTimer.restart();
            }
        }
    }

    property Timer connectorWriteTimer: Timer {
        interval: 200
        onTriggered: root.flushConnectorWrite()
    }

    property Timer churnTimer: Timer {
        interval: 1000
        onTriggered: root.refresh()
    }

    // Hotplug changes which connectors exist; re-discover once the churn
    // settles instead of keeping stale entries or missing new monitors.
    property Connections screenConnections: Connections {
        target: Quickshell
        function onScreensChanged() { root.churnTimer.restart(); }
    }

    Component.onCompleted: refresh()
}
