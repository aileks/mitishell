const minimumBrightness = 1;
const maximumBrightness = 100;

// Brightness never goes fully dark: writes floor at 1 percent so a step can
// always be undone on screen.
function clampBrightness(brightness) {
    if (!Number.isFinite(brightness)) {
        return minimumBrightness;
    }
    return Math.max(minimumBrightness, Math.min(maximumBrightness, brightness));
}

function stepBrightness(brightness, delta) {
    const current = clampBrightness(brightness);
    if (delta > 0) {
        return clampBrightness(current + (current < 5 ? 1 : delta));
    }
    if (delta < 0) {
        return clampBrightness(current + (current <= 5 ? -1 : delta));
    }
    return current;
}

function progress(brightness) {
    return clampBrightness(brightness) / maximumBrightness;
}

function percentLabel(brightness) {
    return Math.round(clampBrightness(brightness)) + "%";
}

if (typeof module !== "undefined") {
    module.exports = {
        minimumBrightness,
        maximumBrightness,
        clampBrightness,
        stepBrightness,
        progress,
        percentLabel,
    };
}
