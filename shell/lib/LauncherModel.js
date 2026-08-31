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

if (typeof module !== "undefined") {
    module.exports = {
        addRecent,
        applicationEntries,
        blankEntries,
        launchCommand,
        mergeRecents,
        childEntries,
        descendantEntries,
        entryPath,
        recentLimit,
        runCommand,
        searchableActions,
        valuesFrom,
    };
}
