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

if (typeof module !== "undefined") {
    module.exports = {
        addRecent,
        applicationEntries,
        blankEntries,
        launchCommand,
        mergeRecents,
        recentLimit,
        runCommand,
        valuesFrom,
    };
}
