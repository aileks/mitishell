function choosePlayer(players, preferredDbusName) {
    if (preferredDbusName !== "") {
        const preferred = players.find(function(player) {
            return player.dbusName === preferredDbusName;
        });
        if (preferred !== undefined) {
            return preferred;
        }
    }

    return players.find(function(player) {
        return player.isPlaying && player.canControl;
    }) || players.find(function(player) {
        return player.isPlaying;
    }) || players.find(function(player) {
        return player.canControl;
    }) || players[0] || null;
}

function title(player) {
    if (player === null || player === undefined) {
        return "No media";
    }
    return clean(player.trackTitle) || clean(player.identity) || "No media";
}

function artist(player) {
    if (player === null || player === undefined) {
        return "";
    }
    return clean(player.trackArtist);
}

function duration(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0) {
        return "--:--";
    }

    const wholeSeconds = Math.floor(seconds);
    const hours = Math.floor(wholeSeconds / 3600);
    const minutes = Math.floor((wholeSeconds % 3600) / 60);
    const remainder = wholeSeconds % 60;
    if (hours > 0) {
        return hours + ":" + pad(minutes) + ":" + pad(remainder);
    }
    return minutes + ":" + pad(remainder);
}

function clean(value) {
    return String(value || "").trim();
}

function pad(value) {
    return String(value).padStart(2, "0");
}

if (typeof module !== "undefined") {
    module.exports = { choosePlayer, title, artist, duration };
}
