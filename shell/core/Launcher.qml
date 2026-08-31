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
    property bool uwsmActive: false
    property string pendingQuery: ""
    property string pendingMenuId: ""
    // Desktop commands wait for the surface to finish closing so region
    // pickers and recorders never appear under the launcher.
    property var pendingDesktopCommand: null

    function refreshApplications() {
        applications = LauncherModel.applicationEntries(DesktopEntries.applications.values);
    }

    function nativeActions() {
        const actions = [
            LauncherModel.action("settings.overview", "Settings", "Overview", Icons.settings,
                { type: "settings", target: "overview" }),
            LauncherModel.action("settings.audio", "Audio Settings", "Settings", Icons.volumeHigh,
                { type: "settings", target: "audio" }),
            LauncherModel.action("settings.display", "Display Settings", "Settings", Icons.computer,
                { type: "settings", target: "display" }),
        ];
        if (Network.state === "ready") {
            actions.push(LauncherModel.action("settings.network", "Network Settings", "Settings",
                Icons.wifi, { type: "settings", target: "network" }));
        }
        if (Bluetooth.state === "ready" && Bluetooth.adapter !== null) {
            actions.push(LauncherModel.action("settings.bluetooth", "Bluetooth Settings", "Settings",
                Icons.bluetooth, { type: "settings", target: "bluetooth" }));
        }
        actions.push(
            LauncherModel.action("settings.system", "System Settings", "Settings", Icons.settings,
                { type: "settings", target: "system" }),
            LauncherModel.action("emoji", "Emoji Picker", "Mitishell", Icons.emoji,
                { type: "surface", target: "emoji" }),
            LauncherModel.action("power", "Power Menu", "Mitishell", Icons.power,
                { type: "surface", target: "power" }),
            LauncherModel.action("dnd", "Do Not Disturb", Notifications.doNotDisturb ? "On" : "Off",
                Notifications.doNotDisturb ? Icons.bellOff : Icons.bell,
                { type: "dnd" }),
        );
        if (Clipboard.available) {
            actions.push(LauncherModel.action("clipboard-history", "Clipboard History", "Mitishell",
                Icons.clipboard, { type: "clipboard-history" }));
        }
        if (Reminders.available) {
            actions.push(LauncherModel.action("reminders", "Reminders", "Mitishell",
                Icons.alarmClock, { type: "surface", target: "reminders" }));
        }
        if (NightLight.available) {
            actions.push(LauncherModel.action("night-light", "Night Light",
                NightLight.enabled ? "On" : "Off", Icons.moon,
                { type: "night-light" }));
        }
        const desktopActions = LauncherModel.desktopActionEntries(desktopActionsSnapshot(), {
            camera: Icons.camera,
            textScan: Icons.textScan,
            qrCode: Icons.qrCode,
            record: Icons.record,
            powerProfile: Icons.powerProfile,
            check: Icons.check,
            update: Icons.update,
        });
        if (desktopActions.length > 0) {
            actions.push(LauncherModel.menu("desktop-actions", "Actions", "Mitishell", Icons.consoleIcon));
            desktopActions.forEach(function(entry) { actions.push(entry); });
        }
        return actions;
    }

    function desktopActionsSnapshot() {
        return {
            screenshotModes: DesktopActions.screenshotModes,
            outputNames: DesktopActions.outputNames,
            ocrAvailable: DesktopActions.ocrAvailable,
            qrAvailable: DesktopActions.qrAvailable,
            recordingModes: DesktopActions.recordingModes,
            recordingActive: DesktopActions.recordingActive,
            powerProfiles: DesktopActions.powerProfiles,
            firmwareAvailable: DesktopActions.firmwareAvailable,
        };
    }

    function recordLaunch(desktopId) {
        recents = LauncherModel.addRecent(recents, desktopId);
        recentsDirty = true;
        pendingSavePayload = JSON.stringify({ version: 1, entries: recents });
        savePending = true;
        pumpSave();
    }

    function openWithQuery(query, screen) {
        pendingQuery = query;
        pendingMenuId = "";
        pendingDesktopCommand = null;
        SurfaceCoordinator.close();
        SurfaceCoordinator.open("launcher", screen);
    }

    function openWithMenu(menu, screen) {
        const menus = {
            "actions": "action:desktop-actions",
            "screenshot-output": "action:desktop-actions.screenshot-output",
            "record-region": "action:desktop-actions.record-region",
            "record-output": "action:desktop-actions.record-output",
        };
        pendingQuery = "";
        pendingMenuId = menus[String(menu || "")] || menus.actions;
        pendingDesktopCommand = null;
        SurfaceCoordinator.close();
        SurfaceCoordinator.open("launcher", screen);
    }

    function runCommand(text) {
        const argv = LauncherModel.runCommand(text, uwsmActive);
        if (argv.length > 0) {
            Quickshell.execDetached(argv);
        }
    }

    function activate(entry, screen) {
        if (entry.source === "calculator") {
            Quickshell.clipboardText = entry.label;
            SurfaceCoordinator.close();
            return;
        }
        if (entry.source === "calculator-error") return;
        if (entry.source === "runner") {
            runCommand(entry.text);
            SurfaceCoordinator.close();
            return;
        }
        if (entry.source === "clipboard") {
            Clipboard.copy(entry.clipboardEntry);
            SurfaceCoordinator.close();
            return;
        }
        if (entry.source === "clipboard-clear") {
            Clipboard.clear();
            SurfaceCoordinator.close();
            return;
        }
        if (entry.source === "application") {
            recordLaunch(entry.desktopId);
            // Terminal-launch and custom-working-directory entries keep
            // QuickShell's launcher; the uwsm argv path can't serve them.
            const desktop = entry.desktopEntry;
            const uwsmApplies = uwsmActive
                && !desktop.runInTerminal
                && String(desktop.workingDirectory || "").trim() === "";
            const argv = LauncherModel.launchCommand(desktop.command, uwsmApplies);
            if (argv.length > 0) {
                Quickshell.execDetached(argv);
            } else {
                desktop.execute();
            }
            SurfaceCoordinator.close();
            return;
        }

        const nativeAction = entry.action || {};
        if (nativeAction.type === "settings") {
            Control.selectPage(nativeAction.target);
            SurfaceCoordinator.open("settings", screen);
        } else if (nativeAction.type === "surface") {
            if (nativeAction.target === "reminders") Reminders.refresh();
            SurfaceCoordinator.open(nativeAction.target, screen);
        } else if (nativeAction.type === "dnd") {
            Notifications.toggleDoNotDisturb();
            SurfaceCoordinator.close();
        } else if (nativeAction.type === "night-light") {
            NightLight.toggle();
            SurfaceCoordinator.close();
        } else if (nativeAction.type === "clipboard-history") {
            openWithQuery(":", screen);
        } else if (nativeAction.type === "desktop-command") {
            if (DesktopActions.actionRunning) return;
            pendingDesktopCommand = nativeAction;
            SurfaceCoordinator.close();
        }
    }

    function surfaceFullyClosed() {
        if (pendingDesktopCommand === null) return;
        const command = pendingDesktopCommand;
        pendingDesktopCommand = null;
        if (!DesktopActions.run(command.command, command.successMessage)) {
            Osd.showGeneric(Icons.warning, "Previous action still running", "", "2200");
        }
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
                    ? LauncherModel.mergeRecents(root.recents, loaded)
                    : loaded.slice(0, LauncherModel.recentLimit);
                if (root.recentsDirty) {
                    root.pendingSavePayload = JSON.stringify({ version: 1, entries: root.recents });
                    root.savePending = true;
                    root.pumpSave();
                }
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

    property Process uwsmProbe: Process {
        command: ["systemctl", "--user", "list-units", "--no-legend", "--state=active",
            "wayland-wm@*.service"]
        stdout: StdioCollector { id: uwsmOutput; waitForEnd: true }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            root.uwsmActive = uwsmOutput.text.trim() !== "";
        }
    }

    Component.onCompleted: {
        refreshApplications();
        loadProcess.running = true;
        uwsmProbe.running = true;
    }
}
