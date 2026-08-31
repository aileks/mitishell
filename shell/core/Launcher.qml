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
        ];
        if (Network.state === "ready") {
            actions.push(action("settings.network", "Network Settings", "Settings", Icons.wifi,
                { type: "settings", target: "network" }));
        }
        if (Bluetooth.state === "ready" && Bluetooth.adapter !== null) {
            actions.push(action("settings.bluetooth", "Bluetooth Settings", "Settings",
                Icons.bluetooth, { type: "settings", target: "bluetooth" }));
        }
        actions.push(
            action("settings.system", "System Settings", "Settings", Icons.settings,
                { type: "settings", target: "system" }),
            action("emoji", "Emoji Picker", "Mitishell", Icons.emoji,
                { type: "surface", target: "emoji" }),
            action("power", "Power Menu", "Mitishell", Icons.power,
                { type: "surface", target: "power" }),
            action("dnd", "Do Not Disturb", Notifications.doNotDisturb ? "On" : "Off",
                Notifications.doNotDisturb ? Icons.bellOff : Icons.bell,
                { type: "dnd" }),
        );
        if (Clipboard.available) {
            actions.push(action("clipboard-history", "Clipboard History", "Mitishell",
                Icons.clipboard, { type: "clipboard-history" }));
        }
        if (Reminders.available) {
            actions.push(action("reminders", "Reminders", "Mitishell", Icons.alarmClock,
                { type: "surface", target: "reminders" }));
        }
        if (NightLight.available) {
            actions.push(action("night-light", "Night Light",
                NightLight.enabled ? "On" : "Off", Icons.moon,
                { type: "night-light" }));
        }
        const desktopActions = desktopActionEntries();
        if (desktopActions.length > 0) {
            actions.push(menu("desktop-actions", "Actions", "Mitishell", Icons.consoleIcon));
            desktopActions.forEach(function(entry) { actions.push(entry); });
        }
        return actions;
    }

    function desktopActionEntries() {
        const entries = [];
        const parent = "action:desktop-actions";
        if (DesktopActions.screenshotCommand.length > 0) {
            ["Region", "Window", "Output", "Desktop"].forEach(function(mode) {
                entries.push(action(
                    "desktop-actions.screenshot-" + mode.toLowerCase(),
                    "Screenshot " + mode,
                    "Actions",
                    Icons.camera,
                    desktopCommand(DesktopActions.screenshotCommand.concat(mode.toLowerCase())),
                    parent,
                ));
            });
        }
        if (DesktopActions.ocrCommand.length > 0) {
            entries.push(action("desktop-actions.extract-text", "Extract Text",
                "Actions", Icons.textScan,
                desktopCommand(DesktopActions.ocrCommand), parent));
        }
        if (DesktopActions.qrCommand.length > 0) {
            entries.push(action("desktop-actions.scan-qr", "Scan QR Code",
                "Actions", Icons.qrCode,
                desktopCommand(DesktopActions.qrCommand), parent));
        }
        if (DesktopActions.recordingCommand.length > 0) {
            if (DesktopActions.recordingActive) {
                entries.push(action("desktop-actions.stop-recording", "Stop Recording",
                    "Actions", Icons.record,
                    desktopCommand(DesktopActions.recordingCommand.concat("stop")), parent));
            } else {
                ["Region", "Output"].forEach(function(mode) {
                    const menuId = "desktop-actions.record-" + mode.toLowerCase();
                    const menuEntry = menu(menuId, "Record " + mode,
                        "Actions", Icons.record, parent);
                    entries.push(menuEntry);
                    [
                        ["No Audio", "none"],
                        ["Microphone", "mic"],
                        ["Desktop Audio", "desktop"],
                        ["Desktop + Microphone", "desktop+mic"],
                    ].forEach(function(audio) {
                        entries.push(action(
                            menuId + "." + audio[1],
                            audio[0],
                            "Record " + mode,
                            Icons.record,
                            desktopCommand(DesktopActions.recordingCommand.concat(
                                mode.toLowerCase(), audio[1])),
                            menuEntry.id,
                        ));
                    });
                });
            }
        }
        if (DesktopActions.powerProfiles.length > 0) {
            const powerMenu = menu("desktop-actions.power-profile", "Power Profile",
                "Actions", Icons.powerProfile, parent);
            entries.push(powerMenu);
            DesktopActions.powerProfiles.forEach(function(profile) {
                entries.push(action(
                    "desktop-actions.power-profile." + profile.name,
                    profileLabel(profile.name),
                    profile.active ? "Active" : "Power Profile",
                    profile.active ? Icons.check : Icons.powerProfile,
                    desktopCommand(
                        DesktopActions.powerCommand.concat("set", profile.name),
                        "Power profile set to " + profileLabel(profile.name),
                    ),
                    powerMenu.id,
                ));
            });
        }
        if (DesktopActions.firmwareCommand.length > 0) {
            entries.push(action("desktop-actions.firmware", "Firmware Updates",
                "Actions", Icons.update,
                desktopCommand(DesktopActions.firmwareCommand), parent));
        }
        return entries;
    }

    function profileLabel(value) {
        return String(value || "").split("-").map(function(word) {
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join(" ");
    }

    function desktopCommand(command, successMessage) {
        return {
            type: "desktop-command",
            command: Array.isArray(command) ? command.slice() : [],
            successMessage: String(successMessage || ""),
        };
    }

    function menu(id, label, detail, icon, parent) {
        return {
            id: "action:" + id,
            parent: String(parent || "root"),
            source: "menu",
            label,
            detail,
            icon,
            keywords: ["mitishell", detail],
        };
    }

    function action(id, label, detail, icon, actionValue, parent) {
        return {
            id: "action:" + id,
            parent: String(parent || "root"),
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

    function openWithQuery(query, screen) {
        pendingQuery = query;
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
            if (DesktopActions.run(nativeAction.command, nativeAction.successMessage)) {
                SurfaceCoordinator.close();
            }
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
