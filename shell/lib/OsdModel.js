const bundledIcons = [
    "bell",
    "bell-off",
    "mic",
    "mic-off",
    "moon",
    "play",
    "power",
    "settings",
    "sun",
    "volume-1",
    "volume-2",
    "volume-x",
    "wifi",
];

const aliases = {
    "brightness": { kind: "bundled", value: "sun" },
    "connectivity": { kind: "bundled", value: "wifi" },
    "error": { kind: "text", value: "󰅚" },
    "media": { kind: "bundled", value: "play" },
    "microphone": { kind: "bundled", value: "mic" },
    "microphone-muted": { kind: "bundled", value: "mic-off" },
    "notification": { kind: "bundled", value: "bell" },
    "power": { kind: "bundled", value: "power" },
    "reminder": { kind: "bundled", value: "bell" },
    "settings": { kind: "bundled", value: "settings" },
    "success": { kind: "text", value: "󰄬" },
    "volume": { kind: "bundled", value: "volume-2" },
    "volume-low": { kind: "bundled", value: "volume-1" },
    "volume-muted": { kind: "bundled", value: "volume-x" },
    "warning": { kind: "text", value: "󰀪" },
};

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

function aliasKey(value) {
    return value.indexOf("mitishell:") === 0 ? value.slice(11) : value;
}

function iconCandidate(value) {
    value = String(value || "");
    if (value === "") {
        return { kind: "none", value: "", fallback: "" };
    }
    const alias = aliases[aliasKey(value)];
    if (alias !== undefined) {
        return { kind: alias.kind, value: alias.value, fallback: value };
    }
    if (value.indexOf("/") === 0 || value.indexOf("file:") === 0) {
        return { kind: "image", value: value, fallback: value };
    }
    if (bundledIcons.indexOf(value) !== -1) {
        return { kind: "bundled", value: value, fallback: value };
    }
    // Private-use glyphs and strings that cannot be icon names are
    // unambiguously literal, so they do not need a theme lookup.
    if (!/^[A-Za-z0-9._-]+$/.test(value)) {
        return { kind: "text", value: value, fallback: value };
    }
    return { kind: "theme", value: value, fallback: value };
}

function resolveIcon(value, themeAvailable) {
    const candidate = iconCandidate(value);
    if (candidate.kind !== "theme" || themeAvailable) {
        return candidate;
    }
    return { kind: "text", value: candidate.fallback, fallback: candidate.fallback };
}

function genericLayout(message, progress) {
    const numericProgress = progress === null || progress === undefined || progress === ""
        ? null
        : Number(progress);
    const hasProgress = numericProgress !== null && Number.isFinite(numericProgress);
    const boundedProgress = hasProgress
        ? Math.max(0, Math.min(100, numericProgress))
        : 0;
    return {
        hasMessage: String(message || "") !== "",
        hasProgress: hasProgress,
        message: String(message || ""),
        progress: boundedProgress / 100,
        label: hasProgress ? Math.round(boundedProgress) + "%" : "",
    };
}

if (typeof module !== "undefined") {
    module.exports = {
        bundledIcons,
        genericLayout,
        iconCandidate,
        iconFor,
        resolveIcon,
        volumeIcon,
    };
}
