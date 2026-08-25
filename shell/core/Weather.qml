pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/WeatherModel.js" as WeatherModel

QtObject {
    id: root

    property string state: "disabled"
    property var snapshot: null
    property int ageMinutes: 0
    property string error: ""

    readonly property string units: WeatherModel.unitsForLocale(
        Config.weather.units,
        Qt.locale().name,
        Qt.locale().measurementSystem === Locale.ImperialUSSystem
            ? "imperial-us" : "metric",
        Quickshell.env("LANG"),
    )
    readonly property bool visible: Config.weather.enabled
    readonly property string refreshKey: [
        Config.weather.enabled ? "enabled" : "disabled",
        units,
        Config.weather.location,
    ].join("\n")

    function refresh() {
        if (!Config.weather.enabled) {
            state = "disabled";
            snapshot = null;
            ageMinutes = 0;
            error = "";
            return;
        }
        if (!weatherProcess.running) {
            state = "locating";
            error = "";
            weatherProcess.command = [
                Config.binary,
                "_weather-snapshot",
                units,
            ];
            weatherProcess.requestKey = refreshKey;
            weatherProcess.running = true;
        }
    }

    property Process snapshotProcess: Process {
        id: weatherProcess

        property string requestKey: ""

        stdout: StdioCollector {
            id: weatherOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: weatherErrors
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            // qmllint enable signal-handler-parameters
            if (requestKey !== root.refreshKey) {
                Qt.callLater(root.refresh);
                return;
            }
            try {
                const result = JSON.parse(weatherOutput.text);
                root.state = result.state;
                root.snapshot = result.state === "ready" || result.state === "stale"
                    ? result.snapshot : null;
                root.ageMinutes = result.ageMinutes || 0;
                root.error = result.error || weatherErrors.text.trim();
            } catch (parseError) {
                root.state = "unavailable";
                root.snapshot = null;
                root.error = exitCode === 0
                    ? "Could not parse weather data"
                    : weatherErrors.text.trim();
            }
        }
    }

    onRefreshKeyChanged: {
        snapshot = null;
        refresh();
    }

    property Timer refreshTimer: Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: Config.weather.enabled
        onTriggered: root.refresh()
    }

    // A failed fetch usually means the network is down; retry gently
    // until it comes back instead of waiting half an hour.
    property Timer retryTimer: Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: Config.weather.enabled && root.state === "unavailable"
        onTriggered: root.refresh()
    }

    // Suspend freezes Qt timers but not the wall clock: a forward leap
    // means the session slept through ticks, so refresh on wake.
    property Timer resumeProbe: Timer {
        interval: 5000
        repeat: true
        running: Config.weather.enabled

        property real lastNow: 0

        onTriggered: {
            const now = Date.now();
            if (lastNow > 0 && now - lastNow > 30000) {
                root.refresh();
            }
            lastNow = now;
        }
    }

    Component.onCompleted: refresh()
}
