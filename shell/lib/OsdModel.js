// OSD presentation transforms shared by every per-screen surface. Icon
// choice is a pure function of kind, level, and mute state.

function volumeIcon(percent, muted) {
    if (muted || percent <= 0) {
        return "volume-x";
    }
    if (percent <= 33) {
        return "volume-1";
    }
    return "volume-2";
}

function iconFor(kind, percent, muted) {
    if (kind === "volume") {
        return volumeIcon(percent, muted);
    }
    if (kind === "mic") {
        return muted ? "mic-off" : "mic";
    }
    return "sun";
}

if (typeof module !== "undefined") {
    module.exports = {
        volumeIcon,
        iconFor,
    };
}
