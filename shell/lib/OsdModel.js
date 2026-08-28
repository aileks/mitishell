const aliases = {
    "bell": { kind: "text", value: "󰂚" },
    "bell-off": { kind: "text", value: "󰂛" },
    "brightness": { kind: "text", value: "󰖙" },
    "connectivity": { kind: "text", value: "󰖩" },
    "error": { kind: "text", value: "󰅚" },
    "media": { kind: "text", value: "󰐊" },
    "mic": { kind: "text", value: "󰍬" },
    "mic-off": { kind: "text", value: "󰍭" },
    "microphone": { kind: "text", value: "󰍬" },
    "microphone-muted": { kind: "text", value: "󰍭" },
    "moon": { kind: "text", value: "󰖔" },
    "notification": { kind: "text", value: "󰂚" },
    "play": { kind: "text", value: "󰐊" },
    "power": { kind: "text", value: "󰐥" },
    "reminder": { kind: "text", value: "󰔛" },
    "settings": { kind: "text", value: "󰒓" },
    "success": { kind: "text", value: "󰄬" },
    "sun": { kind: "text", value: "󰖙" },
    "volume": { kind: "text", value: "󰕾" },
    "volume-1": { kind: "text", value: "󰕿" },
    "volume-2": { kind: "text", value: "󰕾" },
    "volume-low": { kind: "text", value: "󰕿" },
    "volume-muted": { kind: "text", value: "󰝟" },
    "volume-x": { kind: "text", value: "󰝟" },
    "warning": { kind: "text", value: "󰀪" },
    "wifi": { kind: "text", value: "󰖩" },
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
        genericLayout,
        iconCandidate,
        iconFor,
        resolveIcon,
        volumeIcon,
    };
}
