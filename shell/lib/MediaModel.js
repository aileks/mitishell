function choosePlayer(players, preferredPlayerKey) {
    if (preferredPlayerKey !== "") {
        const preferred = players.find(function(player) {
            return playerKey(player) === preferredPlayerKey;
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

function logicalPlayers(players, activityByDbusName) {
    const choices = [];
    const indexes = new Map();
    const activity = activityByDbusName || {};

    players.forEach(function(player) {
        const key = playerKey(player);
        const existingIndex = indexes.get(key);
        if (existingIndex === undefined) {
            indexes.set(key, choices.length);
            choices.push(player);
            return;
        }

        if (betterRepresentative(player, choices[existingIndex], activity)) {
            choices[existingIndex] = player;
        }
    });

    return choices;
}

function playerKey(player) {
    if (player === null || player === undefined) {
        return "";
    }
    return clean(player.desktopEntry).toLowerCase()
        || clean(player.identity).toLowerCase()
        || clean(player.dbusName);
}

function betterRepresentative(candidate, current, activity) {
    if (Boolean(candidate.isPlaying) !== Boolean(current.isPlaying)) {
        return Boolean(candidate.isPlaying);
    }

    const candidateActivity = activity[candidate.dbusName] || 0;
    const currentActivity = activity[current.dbusName] || 0;
    if (candidateActivity !== currentActivity) {
        return candidateActivity > currentActivity;
    }

    if (hasMetadata(candidate) !== hasMetadata(current)) {
        return hasMetadata(candidate);
    }
    if (Boolean(candidate.canControl) !== Boolean(current.canControl)) {
        return Boolean(candidate.canControl);
    }
    return false;
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

function hasMetadata(player) {
    return player !== null && player !== undefined
        && (clean(player.trackTitle) !== "" || clean(player.trackArtist) !== "");
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
    module.exports = {
        choosePlayer,
        logicalPlayers,
        playerKey,
        title,
        artist,
        hasMetadata,
        duration,
    };
}
