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
        deviceLabel,
    };
}
