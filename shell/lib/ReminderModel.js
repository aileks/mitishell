function validMinutes(value) {
    const minutes = String(value || "").trim();
    if (!/^[0-9]+$/.test(minutes)) {
        return null;
    }
    const numeric = Number(minutes);
    return Number.isSafeInteger(numeric) && numeric > 0 ? numeric : null;
}

function validId(value) {
    return /^[0-9a-f]{16}$/.test(String(value || ""));
}

function reminderArgs(minutes, message) {
    const valid = validMinutes(minutes);
    if (valid === null) {
        return [];
    }
    const args = [String(valid)];
    const text = String(message || "").trim();
    if (text !== "") {
        args.push(text);
    }
    return args;
}

function remainingLabel(fireAtSeconds, nowMilliseconds) {
    const remaining = Math.max(
        0,
        Math.ceil(Number(fireAtSeconds) - Number(nowMilliseconds) / 1000),
    );
    const minutes = Math.floor(remaining / 60);
    const seconds = remaining % 60;
    if (minutes > 0 && seconds > 0) {
        return minutes + "m " + seconds + "s";
    }
    if (minutes > 0) {
        return minutes + "m";
    }
    return seconds + "s";
}

function countLabel(count) {
    return count === 1 ? "1 active reminder" : count + " active reminders";
}

function overlayTransform(open) {
    return {
        opacity: open ? 1 : 0,
        scale: open ? 1 : 0.98,
        offset: open ? 0 : 12,
    };
}

if (typeof module !== "undefined") {
    module.exports = {
        countLabel,
        overlayTransform,
        reminderArgs,
        remainingLabel,
        validId,
        validMinutes,
    };
}
