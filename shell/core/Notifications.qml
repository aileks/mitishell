pragma Singleton

import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications
import "../lib/NotificationModel.js" as NotificationModel

QtObject {
    id: root

    // The freedesktop notification server lives in QuickShell; this service
    // owns history, popups, and do-not-disturb. Snapshots are copied into
    // plain objects because models must not hold the live notification.

    property bool doNotDisturb: false
    property var history: []
    property var popups: []
    property real lastSeenAt: 0
    property bool sessionLocked: false
    property bool focusedFullscreen: false

    // The live notification objects by id, for action invocation; entries
    // leave when the server reports the notification closed.
    property var liveById: ({})

    readonly property int unread: NotificationModel.unreadCount(history, lastSeenAt)

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
    }

    function markSeen() {
        lastSeenAt = Date.now();
    }

    function invokeAction(id, identifier) {
        const live = liveById[id];
        if (live === undefined) {
            return;
        }
        const actions = live.actions || [];
        for (let index = 0; index < actions.length; index++) {
            if (actions[index].identifier === identifier) {
                actions[index].invoke();
                return;
            }
        }
    }

    function dismissPopup(id, expired) {
        popups = popups.filter(function(popup) { return popup.id !== id; });
        const live = liveById[id];
        if (live !== undefined) {
            if (expired) {
                live.expire();
            } else {
                live.dismiss();
            }
        }
    }

    function dismissFromHistory(id) {
        history = history.filter(function(entry) { return entry.id !== id; });
        dismissPopup(id, false);
    }

    function clearHistory() {
        history = [];
    }

    function handleNotification(notification) {
        notification.tracked = true;
        const snapshot = NotificationModel.snapshotOf(notification, Date.now());
        liveById[snapshot.id] = notification;
        notification.closed.connect(function() {
            if (liveById[snapshot.id] === notification) {
                delete liveById[snapshot.id];
            }
        });
        watchForUpdates(notification, snapshot.id);

        upsertHistory(snapshot);
        // Critical notifications break through do-not-disturb; suppressed
        // ones still land in history, except transient popups.
        if (doNotDisturb && snapshot.urgency !== 2) {
            if (snapshot.transient) {
                notification.tracked = false;
                delete liveById[snapshot.id];
            }
            return;
        }
        replacePopup(snapshot);
    }

    // A client updating through replaces_id writes onto the same object
    // without a second notification signal, so re-snapshot on change.
    function watchForUpdates(notification, id) {
        const signals = ["summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged"];
        signals.forEach(function(name) {
            const signal = notification[name];
            if (signal !== undefined && typeof signal.connect === "function") {
                signal.connect(function() {
                    root.refreshSnapshot(notification, id);
                });
            }
        });
    }

    function refreshSnapshot(notification, id) {
        if (liveById[id] !== notification) {
            return;
        }
        const snapshot = NotificationModel.snapshotOf(notification, Date.now());
        upsertHistory(snapshot);
        replacePopup(snapshot);
    }

    function upsertHistory(snapshot) {
        const updated = [];
        let inserted = false;
        for (let index = 0; index < history.length; index++) {
            if (history[index].id === snapshot.id) {
                updated.push(snapshot);
                inserted = true;
            } else {
                updated.push(history[index]);
            }
        }
        if (!inserted) {
            updated.unshift(snapshot);
        }
        history = updated.slice(0, NotificationModel.historyLimit);
    }

    function replacePopup(snapshot) {
        const updated = popups.filter(function(popup) { return popup.id !== snapshot.id; });
        updated.unshift(snapshot);
        popups = updated.slice(0, 5);
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        onNotification: root.handleNotification(notification)
    }

    // Hyprland exposes no lock or fullscreen signals on the focused window;
    // poll the monitor blockers (LOCK marks an ext-session-lock) and the
    // active window dump for the popup suppression policy.
    property Process lockProbe: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            id: lockOutput
            waitForEnd: true
        }

        onExited: {
            try {
                const monitors = JSON.parse(lockOutput.text);
                root.sessionLocked = monitors.some(function(monitor) {
                    return (monitor.solitaryBlockedBy || []).indexOf("LOCK") !== -1;
                });
            } catch (parseError) {
                root.sessionLocked = false;
            }
        }
    }

    property Process fullscreenProbe: Process {
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            id: fullscreenOutput
            waitForEnd: true
        }

        onExited: {
            try {
                const active = JSON.parse(fullscreenOutput.text);
                const fullscreen = active.fullscreen;
                root.focusedFullscreen = fullscreen === true || fullscreen === 1;
            } catch (parseError) {
                root.focusedFullscreen = false;
            }
        }
    }

    property Timer suppressionTimer: Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (!lockProbe.running) {
                lockProbe.running = true;
            }
            if (!fullscreenProbe.running) {
                fullscreenProbe.running = true;
            }
        }
    }
}
