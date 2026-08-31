const recentLimit = 5;

function valuesFrom(collection) {
    if (!collection) return [];
    if (Array.isArray(collection)) return collection.slice();
    const values = [];
    if (typeof collection.forEach === "function") {
        collection.forEach(function(value) { values.push(value); });
        return values;
    }
    const length = Number(collection.length || 0);
    for (let index = 0; index < length; index++) values.push(collection[index]);
    return values;
}

function applicationEntries(applications) {
    const values = valuesFrom(applications);
    return values.filter(function(entry) {
        return entry && entry.hidden !== true && entry.noDisplay !== true
            && String(entry.name || "").trim() !== "";
    }).map(function(entry) {
        const desktopId = String(entry.id || entry.name);
        const keywords = valuesFrom(entry.keywords);
        keywords.push(entry.genericName, entry.comment, desktopId);
        return {
            id: "app:" + desktopId,
            desktopId,
            source: "application",
            label: String(entry.name),
            detail: String(entry.genericName || entry.comment || "Application"),
            icon: String(entry.icon || "application-x-executable"),
            keywords: keywords.filter(Boolean),
            desktopEntry: entry,
        };
    });
}

function compareEntries(left, right) {
    const leftLabel = String(left.label || "").toLowerCase();
    const rightLabel = String(right.label || "").toLowerCase();
    if (leftLabel < rightLabel) return -1;
    if (leftLabel > rightLabel) return 1;
    return String(left.id || "") < String(right.id || "") ? -1 : 1;
}

function blankEntries(applications, actions, recentIds) {
    const apps = Array.isArray(applications) ? applications : [];
    const actionValues = Array.isArray(actions) ? actions : [];
    const byDesktopId = {};
    apps.forEach(function(entry) { byDesktopId[entry.desktopId] = entry; });

    const recent = [];
    const recentSet = {};
    (Array.isArray(recentIds) ? recentIds : []).forEach(function(id) {
        const entry = byDesktopId[id];
        if (entry && !recentSet[id] && recent.length < recentLimit) {
            recent.push(entry);
            recentSet[id] = true;
        }
    });
    const remaining = apps.filter(function(entry) {
        return !recentSet[entry.desktopId];
    }).concat(actionValues).sort(compareEntries);
    return recent.concat(remaining);
}

function addRecent(recentIds, desktopId) {
    const value = String(desktopId || "");
    if (value === "") return (Array.isArray(recentIds) ? recentIds : []).slice(0, recentLimit);
    return [value].concat((Array.isArray(recentIds) ? recentIds : []).filter(function(id) {
        return id !== value;
    })).slice(0, recentLimit);
}

function mergeRecents(primaryIds, fallbackIds) {
    const merged = (Array.isArray(primaryIds) ? primaryIds : []).slice(0, recentLimit);
    (Array.isArray(fallbackIds) ? fallbackIds : []).forEach(function(id) {
        if (merged.length < recentLimit && merged.indexOf(id) === -1) merged.push(id);
    });
    return merged;
}

function childEntries(entries, parentId) {
    const parent = String(parentId || "root");
    return (Array.isArray(entries) ? entries : []).filter(function(entry) {
        return String(entry.parent || "root") === parent;
    });
}

// Deep-opened menu ids can vanish between opens - an active recording swaps
// the record menus for a stop action - so stale requests fall back to the
// closest existing ancestor instead of an empty surface.
function resolveMenuId(entries, requestedId, fallbackId) {
    const values = Array.isArray(entries) ? entries : [];
    const exists = function(id) {
        return id === "root" || values.some(function(entry) { return entry.id === id; });
    };
    if (exists(requestedId)) return requestedId;
    return exists(fallbackId) ? fallbackId : "root";
}

function descendantEntries(entries, parentId) {
    const values = Array.isArray(entries) ? entries : [];
    const byParent = {};
    values.forEach(function(entry) {
        const parent = String(entry.parent || "root");
        if (!byParent[parent]) byParent[parent] = [];
        byParent[parent].push(entry);
    });
    const descendants = [];
    const pending = childEntries(values, parentId);
    const seen = {};
    while (pending.length > 0) {
        const entry = pending.shift();
        if (!entry || seen[entry.id]) continue;
        seen[entry.id] = true;
        descendants.push(entry);
        (byParent[entry.id] || []).forEach(function(child) { pending.push(child); });
    }
    return descendants;
}

function entryPath(entries, entryId) {
    const byId = {};
    (Array.isArray(entries) ? entries : []).forEach(function(entry) {
        byId[entry.id] = entry;
    });
    const labels = [];
    let current = byId[entryId];
    const seen = {};
    while (current && current.parent && current.parent !== "root" && !seen[current.id]) {
        seen[current.id] = true;
        current = byId[current.parent];
        if (current) labels.unshift(current.label);
    }
    return labels;
}

function searchableActions(entries, parentId) {
    const values = descendantEntries(entries, parentId);
    return values.map(function(entry) {
        const path = entryPath(entries, entry.id);
        if (path.length === 0) return entry;
        const copy = Object.assign({}, entry);
        copy.detail = path.join(" › ");
        copy.keywords = (Array.isArray(entry.keywords) ? entry.keywords : []).concat(path);
        return copy;
    });
}

// uwsm-managed sessions launch apps through `uwsm app --` so each lands in
// its own systemd scope; otherwise the raw argv runs directly.
function launchCommand(argv, uwsm) {
    const command = Array.isArray(argv) ? argv.slice() : [];
    if (command.length === 0) return [];
    if (!uwsm) return command;
    return ["uwsm", "app", "--"].concat(command);
}

function runCommand(text, uwsm) {
    const command = String(text || "").trim();
    if (command === "") return [];
    return launchCommand(["sh", "-c", command], uwsm);
}

function titleCase(value) {
    return String(value || "").split("-").map(function(word) {
        return word.charAt(0).toUpperCase() + word.slice(1);
    }).join(" ");
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

function desktopCommand(command, successMessage) {
    return {
        type: "desktop-command",
        command: Array.isArray(command) ? command.slice() : [],
        successMessage: String(successMessage || ""),
    };
}

const recordingAudioChoices = [
    ["No Audio", "none"],
    ["Microphone", "mic"],
    ["Desktop Audio", "desktop"],
    ["Desktop + Microphone", "desktop+mic"],
];

// Builds the nested Desktop Actions entries from a DesktopActions snapshot.
// Each group hides itself when its supporting tools are missing, and an
// active recording replaces the record menus with a stop action. Native
// DND, Night Light, and Reminders actions stay out; the launcher already
// exposes them as direct results.
function desktopActionEntries(snapshot, icons) {
    const state = snapshot || {};
    const iconSet = icons || {};
    const entries = [];
    const parent = "action:desktop-actions";
    const screenshotModes = Array.isArray(state.screenshotModes) ? state.screenshotModes : [];
    if (screenshotModes.length > 0) {
        screenshotModes.forEach(function(value) {
            const mode = titleCase(value);
            entries.push(action(
                "desktop-actions.screenshot-" + mode.toLowerCase(),
                "Screenshot " + mode,
                "Actions",
                iconSet.camera,
                desktopCommand(["screenshot", value]),
                parent,
            ));
        });
    }
    if (state.ocrAvailable === true) {
        entries.push(action("desktop-actions.extract-text", "Extract Text",
            "Actions", iconSet.textScan, desktopCommand(["text"]), parent));
    }
    if (state.qrAvailable === true) {
        entries.push(action("desktop-actions.scan-qr", "Scan QR Code",
            "Actions", iconSet.qrCode, desktopCommand(["qr"]), parent));
    }
    const recordingModes = Array.isArray(state.recordingModes) ? state.recordingModes : [];
    if (state.recordingActive === true || recordingModes.length > 0) {
        if (state.recordingActive === true) {
            entries.push(action("desktop-actions.stop-recording", "Stop Recording",
                "Actions", iconSet.record, desktopCommand(["record", "stop"]), parent));
        } else {
            recordingModes.forEach(function(value) {
                const mode = titleCase(value);
                const menuId = "desktop-actions.record-" + value;
                const menuEntry = menu(menuId, "Record " + mode,
                    "Actions", iconSet.record, parent);
                entries.push(menuEntry);
                recordingAudioChoices.forEach(function(audio) {
                    entries.push(action(
                        menuId + "." + audio[1],
                        audio[0],
                        "Record " + mode,
                        iconSet.record,
                        desktopCommand(["record", value, audio[1]]),
                        menuEntry.id,
                    ));
                });
            });
        }
    }
    const powerProfiles = Array.isArray(state.powerProfiles) ? state.powerProfiles : [];
    if (powerProfiles.length > 0) {
        const powerMenu = menu("desktop-actions.power-profile", "Power Profile",
            "Actions", iconSet.powerProfile, parent);
        entries.push(powerMenu);
        powerProfiles.forEach(function(profile) {
            entries.push(action(
                "desktop-actions.power-profile." + profile.name,
                titleCase(profile.name),
                profile.active ? "Active" : "Power Profile",
                profile.active ? iconSet.check : iconSet.powerProfile,
                desktopCommand(["power-profile", profile.name],
                    "Power profile set to " + titleCase(profile.name)),
                powerMenu.id,
            ));
        });
    }
    if (state.firmwareAvailable === true) {
        entries.push(action("desktop-actions.firmware", "Firmware Updates",
            "Actions", iconSet.update, desktopCommand(["firmware"]), parent));
    }
    return entries;
}

if (typeof module !== "undefined") {
    module.exports = {
        action,
        addRecent,
        applicationEntries,
        blankEntries,
        desktopActionEntries,
        launchCommand,
        menu,
        mergeRecents,
        childEntries,
        descendantEntries,
        entryPath,
        recentLimit,
        resolveMenuId,
        runCommand,
        searchableActions,
        valuesFrom,
    };
}
