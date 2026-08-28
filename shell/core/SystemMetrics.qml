pragma Singleton

import QtQuick
import Quickshell.Io
import "../lib/SystemModel.js" as SystemModel

QtObject {
    id: root

    property var previousCpu: null
    property int cpuPercent: 0
    property real memoryTotalBytes: 0
    property real memoryUsedBytes: 0
    property int memoryPercent: 0
    property var loadAverage: [0, 0, 0]
    property int uptimeSeconds: 0
    property var temperatureC: null
    property bool loaded: false

    function refresh() {
        cpuFile.reload();
        memoryFile.reload();
        loadFile.reload();
        uptimeFile.reload();
    }

    function refreshTemperature() {
        if (!temperatureProcess.running) {
            temperatureProcess.running = true;
        }
    }

    function updateCpu(text) {
        const current = SystemModel.parseCpu(text);
        cpuPercent = SystemModel.cpuUsage(previousCpu, current);
        previousCpu = current;
        loaded = current !== null;
    }

    property FileView cpuFile: FileView {
        id: cpuFile
        path: "/proc/stat"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.updateCpu(text())
    }

    property FileView memoryFile: FileView {
        id: memoryFile
        path: "/proc/meminfo"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            const snapshot = SystemModel.memory(text());
            root.memoryTotalBytes = snapshot.totalBytes;
            root.memoryUsedBytes = snapshot.usedBytes;
            root.memoryPercent = snapshot.percent;
        }
    }

    property FileView loadFile: FileView {
        id: loadFile
        path: "/proc/loadavg"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadAverage = SystemModel.load(text())
    }

    property FileView uptimeFile: FileView {
        id: uptimeFile
        path: "/proc/uptime"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.uptimeSeconds = SystemModel.uptime(text())
    }

    property Process temperatureProcess: Process {
        id: temperatureProcess
        command: [Config.binary, "_system-temperature-snapshot"]
        stdout: StdioCollector {
            id: temperatureOutput
            waitForEnd: true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            try {
                const snapshot = JSON.parse(temperatureOutput.text);
                root.temperatureC = snapshot.available === true
                    ? Number(snapshot.celsius) : null;
            } catch (parseError) {
                root.temperatureC = null;
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    property Timer temperatureTimer: Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshTemperature()
    }
}
