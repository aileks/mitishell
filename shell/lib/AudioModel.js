const maximumVolume = 1.5;

function clampVolume(volume) {
    if (!Number.isFinite(volume)) {
        return 0;
    }
    return Math.max(0, Math.min(maximumVolume, volume));
}

function stepVolume(volume, delta) {
    return clampVolume(volume + delta);
}

// Keybind steps stay within 100 percent to match the OSD scale; the wheel
// and slider keep access to the full 150 percent range.
function stepVolumeWithin(volume, delta, maximum) {
    return Math.max(0, Math.min(maximum, volume + delta));
}

function percent(volume) {
    return Math.round(clampVolume(volume) * 100);
}

function sinks(nodes) {
    return nodes.filter(function(node) {
        return node !== null && node !== undefined && node.isSink && !node.isStream;
    });
}

function sources(nodes) {
    return nodes.filter(function(node) {
        return node !== null && node !== undefined && !node.isSink && !node.isStream;
    });
}

// Playback streams: apps and players rendering sound. Classification sticks
// to the bound node flags and never reads node.properties, which can
// destabilize QuickShell's Pipewire service when read too early.
function isPlaybackStream(node) {
    if (node === null || node === undefined || !node.isStream) {
        return false;
    }
    if (node.isSink === true) {
        return true;
    }
    // Some playback streams only expose their direction through type flags.
    const type = String(node.type || "");
    return type.indexOf("Output") !== -1 || type.indexOf("AudioOutStream") !== -1;
}

function playbackStreams(nodes) {
    return nodes.filter(function(node) {
        return isPlaybackStream(node) && node.name !== "quickshell";
    });
}

// One logical stream per application: multi-window apps such as browsers
// keep a playback node per window, and the applications section should
// present the app, not its node count. Writes fan out to the whole group.
function logicalStreams(nodes) {
    const groups = [];
    const byLabel = {};
    playbackStreams(nodes).forEach(function(node) {
        const properties = node.properties || {};
        const label = clean(properties["application.name"])
            || clean(node.description)
            || clean(properties["media.name"])
            || clean(node.name)
            || "Unknown application";
        const key = clean(properties["application.name"]) || clean(node.name) || label;
        if (byLabel[key] === undefined) {
            byLabel[key] = { label: label, nodes: [] };
            groups.push(byLabel[key]);
        }
        byLabel[key].nodes.push(node);
    });
    return groups;
}

function streamLabel(node) {
    if (node === null || node === undefined) {
        return "Unknown application";
    }
    const properties = node.properties || {};
    return clean(properties["application.name"])
        || clean(node.description)
        || clean(properties["media.name"])
        || clean(node.name)
        || "Unknown application";
}

function deviceLabel(node) {
    if (node === null || node === undefined) {
        return "Unavailable";
    }
    return clean(node.description) || clean(node.nickname) || clean(node.name) || "Unknown device";
}

function clean(value) {
    return String(value || "").trim();
}

if (typeof module !== "undefined") {
    module.exports = {
        maximumVolume,
        clampVolume,
        stepVolume,
        stepVolumeWithin,
        percent,
        sinks,
        sources,
        isPlaybackStream,
        playbackStreams,
        logicalStreams,
        streamLabel,
        deviceLabel,
    };
}
