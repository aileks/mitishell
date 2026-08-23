const lowPopupDuration = 5000;
const normalPopupDuration = 8000;
const maxPopupDuration = 30000;
const historyLimit = 50;

// Critical popups stay until dismissed; others take the sender's timeout
// when it is longer than the urgency floor, capped at 30 seconds.
function popupDuration(urgency, expireTimeout) {
    if (urgency === 2) {
        return 0;
    }
    const floor = urgency === 0 ? lowPopupDuration : normalPopupDuration;
    const requested = Number(expireTimeout || 0);
    if (!Number.isFinite(requested) || requested <= 0) {
        return floor;
    }
    return Math.min(maxPopupDuration, Math.max(floor, requested));
}

// Bodies carry limited markup; cards render plain text.
function plainBody(body) {
    return String(body || "")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<[^>]+>/g, "")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'")
        .replace(/&amp;/g, "&")
        .trim();
}

// Copy the drawable fields of a live notification into a plain object;
// models must never hold the notification QObject itself.
function snapshotOf(notification, timestamp, recordId) {
    const actions = (notification.actions || []).map(function(action) {
        return { identifier: action.identifier, text: action.text };
    });
    const urgency = Number(notification.urgency);
    const expireTimeout = Number(notification.expireTimeout);
    return {
        recordId: String(recordId || (Math.round(timestamp) + "-" + notification.id)),
        liveId: notification.id,
        appName: String(notification.appName || ""),
        appIcon: String(notification.appIcon || ""),
        desktopEntry: String(notification.desktopEntry || ""),
        image: String(notification.image || ""),
        persistedAppIcon: "",
        persistedImage: "",
        summary: plainBody(notification.summary),
        body: plainBody(notification.body),
        urgency: Number.isFinite(urgency) ? urgency : 1,
        timeout: popupDuration(urgency, expireTimeout),
        transient: notification.transient === true,
        actions: actions,
        timestamp: timestamp,
        live: true,
    };
}

function durableEntry(snapshot) {
    return {
        recordId: snapshot.recordId,
        appName: snapshot.appName,
        desktopEntry: snapshot.desktopEntry,
        appIcon: snapshot.persistedAppIcon || "",
        image: snapshot.persistedImage || "",
        summary: snapshot.summary,
        body: snapshot.body,
        urgency: snapshot.urgency,
        timestamp: snapshot.timestamp,
    };
}

function durableEntries(history) {
    return history.filter(function(snapshot) {
        return !snapshot.transient;
    }).map(durableEntry);
}

function restoredSnapshot(entry) {
    return {
        recordId: entry.recordId,
        liveId: -1,
        appName: String(entry.appName || ""),
        appIcon: String(entry.appIcon || ""),
        desktopEntry: String(entry.desktopEntry || ""),
        image: String(entry.image || ""),
        persistedAppIcon: String(entry.appIcon || ""),
        persistedImage: String(entry.image || ""),
        summary: String(entry.summary || ""),
        body: String(entry.body || ""),
        urgency: Number(entry.urgency),
        timeout: 0,
        transient: false,
        actions: [],
        timestamp: Number(entry.timestamp),
        live: false,
    };
}

function timeLabel(timestamp, now) {
    const age = Math.max(0, now - timestamp);
    const minutes = Math.floor(age / 60000);
    if (minutes < 1) {
        return "now";
    }
    if (minutes < 60) {
        return minutes + "m";
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
        return hours + "h";
    }
    return Math.floor(hours / 24) + "d";
}

function unreadCount(history, lastSeenAt) {
    return history.filter(function(notification) {
        return notification.timestamp > lastSeenAt;
    }).length;
}

// The output that shows toast popups: the focused output when it has a bar,
// otherwise the first output with one. An empty name means no popups.
function popupTarget(focusedName, screenNames, outputs) {
    const wildcard = outputs.indexOf("*") !== -1;
    const enabled = function(name) {
        return wildcard || outputs.indexOf(name) !== -1;
    };
    if (enabled(focusedName)) {
        return focusedName;
    }
    for (let index = 0; index < screenNames.length; index++) {
        if (enabled(screenNames[index])) {
            return screenNames[index];
        }
    }
    return "";
}

if (typeof module !== "undefined") {
    module.exports = {
        historyLimit,
        durableEntry,
        durableEntries,
        popupDuration,
        plainBody,
        popupTarget,
        restoredSnapshot,
        snapshotOf,
        timeLabel,
        unreadCount,
    };
}
