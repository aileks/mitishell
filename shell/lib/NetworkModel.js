// Network page presentation transforms.

function signalBars(signal) {
    if (signal >= 80) return 4;
    if (signal >= 55) return 3;
    if (signal >= 30) return 2;
    if (signal > 0) return 1;
    return 0;
}

function securityLabel(security) {
    switch (security) {
    case "open":
        return "Open";
    case "wpa2":
        return "WPA2";
    case "wpa3":
        return "WPA3";
    case "wep":
        return "WEP";
    case "enterprise":
        return "Enterprise";
    default:
        return "Secured";
    }
}

function stateLabel(state) {
    switch (state) {
    case "connected":
        return "Connected";
    case "connecting":
        return "Connecting";
    case "failed":
        return "Connection failed";
    case "disconnected":
        return "Disconnected";
    default:
        return "Unavailable";
    }
}

// Stations the page lists: everything visible plus saved networks that are
// not currently in range, so a saved profile can still be joined or removed.
function listableStations(stations, saved) {
    const listed = stations.slice();
    const inRange = {};
    stations.forEach(function(station) {
        inRange[station.ssid] = true;
    });
    (saved || []).forEach(function(entry) {
        if (!inRange[entry.ssid] && entry.ssid !== "") {
            listed.push({
                ssid: entry.ssid,
                signal: 0,
                security: "unknown",
                inUse: false,
                saved: true,
                outOfRange: true,
            });
        }
    });
    return listed;
}

if (typeof module !== "undefined") {
    module.exports = {
        signalBars,
        securityLabel,
        stateLabel,
        listableStations,
    };
}
