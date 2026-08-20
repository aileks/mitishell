function parseCpu(text) {
    const line = String(text || "").split("\n")[0].trim().split(/\s+/);
    if (line[0] !== "cpu" || line.length < 5) {
        return null;
    }

    const values = line.slice(1, 9).map(Number);
    if (values.some(function(value) { return !Number.isFinite(value); })) {
        return null;
    }

    return {
        idle: values[3] + (values[4] || 0),
        total: values.reduce(function(sum, value) { return sum + value; }, 0),
    };
}

function cpuUsage(previous, current) {
    if (previous === null || current === null) {
        return 0;
    }
    const totalDelta = current.total - previous.total;
    const idleDelta = current.idle - previous.idle;
    if (totalDelta <= 0) {
        return 0;
    }
    return Math.round(clamp((totalDelta - idleDelta) / totalDelta) * 100);
}

function memory(text) {
    const values = {};
    String(text || "").split("\n").forEach(function(line) {
        const match = line.match(/^(MemTotal|MemAvailable):\s+(\d+)\s+kB$/);
        if (match !== null) {
            values[match[1]] = Number(match[2]) * 1024;
        }
    });

    const totalBytes = values.MemTotal || 0;
    const usedBytes = Math.max(0, totalBytes - (values.MemAvailable || 0));
    return {
        totalBytes,
        usedBytes,
        percent: totalBytes > 0 ? Math.round(usedBytes / totalBytes * 100) : 0,
    };
}

function load(text) {
    const values = String(text || "").trim().split(/\s+/).slice(0, 3).map(Number);
    return values.length === 3 && values.every(Number.isFinite) ? values : [0, 0, 0];
}

function uptime(text) {
    const value = Number(String(text || "").trim().split(/\s+/)[0]);
    return Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
}

function temperature(text) {
    const value = Number(String(text || "").trim());
    return Number.isFinite(value) && value >= 0 ? value / 1000 : null;
}

function bytes(value) {
    if (!Number.isFinite(value) || value < 0) {
        return "0.0 GiB";
    }
    return (value / 1073741824).toFixed(1) + " GiB";
}

function uptimeLabel(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor(seconds % 86400 / 3600);
    const minutes = Math.floor(seconds % 3600 / 60);
    if (days > 0) {
        return days + "d " + hours + "h";
    }
    if (hours > 0) {
        return hours + "h " + minutes + "m";
    }
    return minutes + "m";
}

function clamp(value) {
    return Math.max(0, Math.min(1, value));
}

if (typeof module !== "undefined") {
    module.exports = {
        parseCpu,
        cpuUsage,
        memory,
        load,
        uptime,
        temperature,
        bytes,
        uptimeLabel,
    };
}
