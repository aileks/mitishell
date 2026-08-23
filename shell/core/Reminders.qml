pragma Singleton

import QtQuick
import Quickshell.Io
import "../lib/ReminderModel.js" as ReminderModel

QtObject {
    id: root

    property bool available: false
    property string error: ""
    property string warning: ""
    property var active: []
    property string actionError: ""
    property string lastAction: ""
    property int actionSerial: 0

    readonly property int count: active.length
    readonly property bool busy: actionProcess.running

    function refresh() {
        if (!snapshotProcess.running) {
            snapshotProcess.running = true;
        }
    }

    function schedule(minutes, message) {
        const args = ReminderModel.reminderArgs(minutes, message);
        if (args.length === 0) {
            actionError = "Enter a positive whole number of minutes.";
            return false;
        }
        return runAction("schedule", [Config.binary, "reminder"].concat(args));
    }

    function cancel(id) {
        if (!ReminderModel.validId(id)) {
            actionError = "That reminder can no longer be cancelled.";
            return false;
        }
        return runAction("cancel", [Config.binary, "_reminder-cancel", id]);
    }

    function clear() {
        return runAction("clear", [Config.binary, "reminder", "clear"]);
    }

    function runAction(name, command) {
        if (actionProcess.running) {
            return false;
        }
        actionError = "";
        lastAction = name;
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    property Process snapshotProcess: Process {
        command: [Config.binary, "_reminder-snapshot"]
        stdout: StdioCollector {
            id: snapshotOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: snapshotError
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.available = false;
                root.error = snapshotError.text.trim() || "Reminders are unavailable.";
                root.warning = "";
                root.active = [];
                return;
            }
            try {
                const snapshot = JSON.parse(snapshotOutput.text);
                root.available = snapshot.available === true;
                root.error = String(snapshot.error || "");
                root.warning = String(snapshot.warning || "");
                root.active = snapshot.reminders || [];
            } catch (parseError) {
                root.available = false;
                root.error = "Reminder state could not be read.";
                root.warning = "";
                root.active = [];
            }
        }
    }

    property Process actionProcess: Process {
        stdout: StdioCollector {
            id: actionOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: actionErrorOutput
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            root.actionError = exitCode === 0
                ? ""
                : (actionErrorOutput.text.trim() || "Reminder action failed.");
            if (exitCode === 0) {
                root.actionSerial++;
            }
            root.refresh();
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
