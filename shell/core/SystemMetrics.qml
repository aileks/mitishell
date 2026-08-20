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
    property string launchError: ""

    function refresh() {
        cpuFile.reload();
        memoryFile.reload();
        loadFile.reload();
        uptimeFile.reload();
    }

    function updateCpu(text) {
        const current = SystemModel.parseCpu(text);
        cpuPercent = SystemModel.cpuUsage(previousCpu, current);
        previousCpu = current;
        loaded = current !== null;
    }

    function openMissionCenter() {
        if (!missionCenter.running) {
            launchError = "";
            missionCenter.running = true;
        }
    }

    property Process missionCenterProcess: Process {
        id: missionCenter
        command: ["missioncenter"]
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.launchError = "Mission Center could not be opened";
            }
        }
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

    property FileView temperatureFile: FileView {
        id: temperatureFile
        path: "/sys/class/thermal/thermal_zone0/temp"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.temperatureC = SystemModel.temperature(text())
        onLoadFailed: root.temperatureC = null
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
        onTriggered: temperatureFile.reload()
    }
}
