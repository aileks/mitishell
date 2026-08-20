function condition(code) {
    if (code === 0) {
        return { key: "clear", label: "Clear" };
    }
    if (code >= 1 && code <= 3) {
        return { key: "cloudy", label: code === 1 ? "Mostly clear" : "Cloudy" };
    }
    if (code === 45 || code === 48) {
        return { key: "fog", label: "Fog" };
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
        return { key: "rain", label: "Rain" };
    }
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) {
        return { key: "snow", label: "Snow" };
    }
    if (code >= 95 && code <= 99) {
        return { key: "storm", label: "Thunderstorm" };
    }
    return { key: "unknown", label: "Unknown" };
}

function temperature(value) {
    return Number.isFinite(value) ? Math.round(value) + "°" : "--°";
}

function hour(value) {
    const text = String(value || "");
    return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text) ? text.slice(11) : "--:--";
}

if (typeof module !== "undefined") {
    module.exports = { condition, temperature, hour };
}
