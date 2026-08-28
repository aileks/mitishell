pragma Singleton

import QtQuick
import Quickshell
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
    property string historyError: ""
    property bool historyLoaded: false
    property bool historyWritable: true
    property var mediaQueue: []
    property string pendingSavePayload: ""
    property bool savePending: false
    property bool clearRequested: false

    // The live notification objects by id, for action invocation; entries
    // leave when the server reports the notification closed.
    property var liveById: ({})
    property var recordByLiveId: ({})

    readonly property int unread: NotificationModel.unreadCount(history, lastSeenAt)

    // Popups anchor under the bell widget, so they need an output that has
    // a bar: the focused one when it qualifies, otherwise the first that does.
    readonly property var screenNames: {
        const screens = Quickshell.screens !== undefined ? Quickshell.screens : [];
        return screens.map(function(screen) { return screen.name; });
    }
    readonly property string popupScreenName: NotificationModel.popupTarget(
        Osd.screenName, screenNames, Config.barTargetConnectors)

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
    }

    function markSeen() {
        lastSeenAt = Date.now();
        scheduleSave();
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

    function dismissPopup(recordId, expired) {
        const record = findRecord(recordId);
        popups = popups.filter(function(popup) { return popup.recordId !== recordId; });
        const live = record === null ? undefined : liveById[record.liveId];
        if (live !== undefined) {
            if (expired) {
                live.expire();
            } else {
                live.dismiss();
            }
        }
    }

    function dismissFromHistory(recordId) {
        const record = findRecord(recordId);
        history = history.filter(function(entry) { return entry.recordId !== recordId; });
        popups = popups.filter(function(entry) { return entry.recordId !== recordId; });
        mediaQueue = mediaQueue.filter(function(task) { return task.recordId !== recordId; });
        if (record !== null && record.live) {
            const live = liveById[record.liveId];
            if (live !== undefined) {
                live.dismiss();
            }
        }
        scheduleSave();
    }

    function clearHistory() {
        history = [];
        mediaQueue = [];
        savePending = false;
        saveDebounce.stop();
        clearRequested = true;
        if (!historySave.running && !historyClear.running) {
            historyClear.running = true;
        }
    }

    function findRecord(recordId) {
        for (let index = 0; index < popups.length; index++) {
            if (popups[index].recordId === recordId) {
                return popups[index];
            }
        }
        for (let index = 0; index < history.length; index++) {
            if (history[index].recordId === recordId) {
                return history[index];
            }
        }
        return null;
    }

    function handleNotification(notification) {
        notification.tracked = true;
        const snapshot = NotificationModel.snapshotOf(notification, Date.now());
        liveById[snapshot.liveId] = notification;
        recordByLiveId[snapshot.liveId] = snapshot.recordId;
        notification.closed.connect(function() {
            if (liveById[snapshot.liveId] === notification) {
                delete liveById[snapshot.liveId];
            }
        });
        watchForUpdates(notification, snapshot.liveId);

        upsertHistory(snapshot);
        // Critical and explicit reminder traffic break through do-not-disturb;
        // suppressed records still land in history, except transient popups.
        if (!NotificationModel.popupAllowed(doNotDisturb, snapshot)) {
            if (snapshot.transient) {
                notification.tracked = false;
                delete liveById[snapshot.liveId];
            }
            return;
        }
        replacePopup(snapshot);
    }

    // A client updating through replaces_id writes onto the same object
    // without a second notification signal, so re-snapshot on change.
    function watchForUpdates(notification, id) {
        const signals = [
            "summaryChanged",
            "bodyChanged",
            "appNameChanged",
            "appIconChanged",
            "desktopEntryChanged",
            "imageChanged",
            "urgencyChanged",
            "actionsChanged",
        ];
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
        const snapshot = NotificationModel.snapshotOf(
            notification,
            Date.now(),
            recordByLiveId[id],
        );
        upsertHistory(snapshot);
        replacePopup(snapshot);
    }

    function upsertHistory(snapshot) {
        if (snapshot.transient) {
            return;
        }
        const updated = [];
        let inserted = false;
        for (let index = 0; index < history.length; index++) {
            if (history[index].recordId === snapshot.recordId) {
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
        queueMedia(snapshot);
        scheduleSave();
    }

    function replacePopup(snapshot) {
        const updated = popups.filter(function(popup) {
            return popup.recordId !== snapshot.recordId;
        });
        updated.unshift(snapshot);
        popups = updated.slice(0, 5);
    }

    function queueMedia(snapshot) {
        if (snapshot.transient) {
            return;
        }
        enqueueMedia(
            snapshot.recordId,
            "appIcon",
            snapshot.appIcon !== "" ? snapshot.appIcon : snapshot.desktopEntry,
        );
        enqueueMedia(snapshot.recordId, "image", snapshot.image);
    }

    function enqueueMedia(recordId, role, source) {
        if (source === "") {
            return;
        }
        const exists = mediaQueue.some(function(task) {
            return task.recordId === recordId && task.role === role && task.source === source;
        });
        if (!exists) {
            mediaQueue = mediaQueue.concat([{
                recordId: recordId,
                role: role,
                source: source,
            }]);
        }
    }

    function completeMediaCapture(recordId, role, mediaUrl) {
        mediaQueue = mediaQueue.filter(function(task) {
            return !(task.recordId === recordId && task.role === role);
        });
        if (mediaUrl === "") {
            return;
        }
        const persistedField = role === "appIcon" ? "persistedAppIcon" : "persistedImage";
        const visibleField = role === "appIcon" ? "appIcon" : "image";
        const update = function(entry) {
            if (entry.recordId !== recordId) {
                return entry;
            }
            const copy = Object.assign({}, entry);
            copy[persistedField] = mediaUrl;
            copy[visibleField] = mediaUrl;
            return copy;
        };
        history = history.map(update);
        popups = popups.map(update);
        scheduleSave();
    }

    function durableState() {
        return {
            version: 1,
            lastSeenAt: Math.round(lastSeenAt),
            entries: NotificationModel.durableEntries(history),
        };
    }

    function scheduleSave() {
        if (historyLoaded && historyWritable) {
            savePending = true;
            if (!historySave.running && !historyClear.running && !clearRequested) {
                saveDebounce.restart();
            }
        }
    }

    function saveNow() {
        if (!historyWritable || historySave.running) {
            return;
        }
        savePending = false;
        pendingSavePayload = JSON.stringify(durableState());
        historySave.running = true;
    }

    function mergeLoadedState(state) {
        const current = history.slice();
        const known = {};
        current.forEach(function(entry) { known[entry.recordId] = true; });
        (state.entries || []).forEach(function(entry) {
            if (!known[entry.recordId]) {
                current.push(NotificationModel.restoredSnapshot(entry));
                known[entry.recordId] = true;
            }
        });
        history = current.slice(0, NotificationModel.historyLimit);
        lastSeenAt = Number(state.lastSeenAt || 0);
    }

    property Timer saveDebounce: Timer {
        interval: 180
        onTriggered: root.saveNow()
    }

    property Process historyLoad: Process {
        command: [Config.binary, "_notification-history-load"]
        stdout: StdioCollector {
            id: historyLoadOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: historyLoadError
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode === 0) {
                try {
                    root.mergeLoadedState(JSON.parse(historyLoadOutput.text));
                } catch (parseError) {
                    root.historyError = "Could not read saved notification history.";
                    root.historyWritable = false;
                }
            } else {
                root.historyError = historyLoadError.text.trim()
                    || "Saved notification history is unavailable.";
                root.historyWritable = false;
            }
            root.historyLoaded = true;
            if (root.historyWritable) {
                root.scheduleSave();
            }
        }
    }

    property Process historySave: Process {
        command: [Config.binary, "_notification-history-save"]
        stdinEnabled: true
        stderr: StdioCollector {
            id: historySaveError
            waitForEnd: true
        }
        onStarted: write(root.pendingSavePayload)
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode !== 0) {
                root.historyError = historySaveError.text.trim()
                    || "Notification history could not be saved.";
            } else if (root.historyWritable) {
                root.historyError = "";
            }
            if (root.clearRequested && !historyClear.running) {
                historyClear.running = true;
            } else if (root.savePending) {
                root.scheduleSave();
            }
        }
    }

    property Process historyClear: Process {
        command: [Config.binary, "_notification-history-clear"]
        stderr: StdioCollector {
            id: historyClearError
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode, exitStatus) {
            // qmllint enable signal-handler-parameters
            if (exitCode === 0) {
                root.historyWritable = true;
                root.historyError = "";
            } else {
                root.historyError = historyClearError.text.trim()
                    || "Notification history could not be cleared.";
            }
            root.clearRequested = false;
            if (root.savePending) {
                root.scheduleSave();
            }
        }
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        onNotification: function(notification) {
            root.handleNotification(notification);
        }
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

        // qmllint disable signal-handler-parameters
        onExited: {
            // qmllint enable signal-handler-parameters
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

        // qmllint disable signal-handler-parameters
        onExited: {
            // qmllint enable signal-handler-parameters
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

    Component.onCompleted: historyLoad.running = true
}
