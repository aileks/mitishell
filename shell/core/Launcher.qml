pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/LauncherModel.js" as LauncherModel

QtObject {
    id: root

    property var applications: []
    property var recents: []
    property string persistenceError: ""
    property bool recentsLoaded: false
    property bool recentsDirty: false
    property bool savePending: false
    property string pendingSavePayload: ""

    function refreshApplications() {
        applications = LauncherModel.applicationEntries(DesktopEntries.applications.values);
    }

    function nativeActions() {
        const actions = [
            action("settings.overview", "Settings", "Overview", Icons.settings,
                { type: "settings", target: "overview" }),
            action("settings.audio", "Audio Settings", "Settings", Icons.volumeHigh,
                { type: "settings", target: "audio" }),
            action("settings.display", "Display Settings", "Settings", Icons.computer,
                { type: "settings", target: "display" }),
            action("settings.network", "Network Settings", "Settings", Icons.wifi,
                { type: "settings", target: "network" }),
            action("settings.bluetooth", "Bluetooth Settings", "Settings", Icons.bluetooth,
                { type: "settings", target: "bluetooth" }),
            action("settings.system", "System Settings", "Settings", Icons.settings,
                { type: "settings", target: "system" }),
            action("emoji", "Emoji Picker", "Mitishell", Icons.emoji,
                { type: "surface", target: "emoji" }),
            action("power", "Power Menu", "Mitishell", Icons.power,
                { type: "surface", target: "power" }),
            action("dnd", "Do Not Disturb", Notifications.doNotDisturb ? "On" : "Off",
                Notifications.doNotDisturb ? Icons.bellOff : Icons.bell,
                { type: "dnd" }),
        ];
        if (Reminders.available) {
            actions.push(action("reminders", "Reminders", "Mitishell", Icons.alarmClock,
                { type: "surface", target: "reminders" }));
        }
        if (NightLight.available) {
            actions.push(action("night-light", "Night Light",
                NightLight.enabled ? "On" : "Off", Icons.moon,
                { type: "night-light" }));
        }
        return actions;
    }

    function action(id, label, detail, icon, actionValue) {
        return {
            id: "action:" + id,
            source: "action",
            label,
            detail,
            icon,
            keywords: ["mitishell", detail],
            action: actionValue,
        };
    }

    function recordLaunch(desktopId) {
        recents = LauncherModel.addRecent(recents, desktopId);
        recentsDirty = true;
        pendingSavePayload = JSON.stringify({ version: 1, entries: recents });
        savePending = true;
        pumpSave();
    }

    function pumpSave() {
        if (!saveProcess.running && savePending) {
            savePending = false;
            saveProcess.running = true;
        }
    }

    property Connections desktopEntryChanges: Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refreshApplications(); }
    }

    property Process loadProcess: Process {
        command: [Config.binary, "_launcher-recents-load"]
        stdout: StdioCollector { id: loadOutput; waitForEnd: true }
        stderr: StdioCollector { id: loadErrors; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.persistenceError = loadErrors.text.trim()
                    || "Recent applications could not be loaded.";
                root.recentsLoaded = true;
                return;
            }
            try {
                const loaded = JSON.parse(loadOutput.text).entries || [];
                root.recents = root.recentsDirty
                    ? loaded.reduce(function(current, value) {
                        return LauncherModel.addRecent(current, value);
                    }, root.recents)
                    : loaded.slice(0, LauncherModel.recentLimit);
                root.persistenceError = "";
            } catch (parseError) {
                root.persistenceError = "Recent applications could not be read.";
            }
            root.recentsLoaded = true;
        }
    }

    property Process saveProcess: Process {
        command: [Config.binary, "_launcher-recents-save"]
        stdinEnabled: true
        stderr: StdioCollector { id: saveErrors; waitForEnd: true }

        onStarted: write(root.pendingSavePayload)
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.persistenceError = exitCode === 0
                ? ""
                : (saveErrors.text.trim() || "Recent applications could not be saved.");
            root.pumpSave();
        }
    }

    Component.onCompleted: {
        refreshApplications();
        loadProcess.running = true;
    }
}
