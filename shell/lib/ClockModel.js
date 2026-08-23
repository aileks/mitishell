function timePattern(preset, localePattern) {
    switch (preset) {
    case "24h":
        return "HH:mm";
    case "12h":
        return "h:mm AP";
    case "24h-seconds":
        return "HH:mm:ss";
    case "12h-seconds":
        return "h:mm:ss AP";
    default:
        return localePattern;
    }
}

function isoWeekNumber(year, month, day) {
    const date = new Date(year, month, day, 12);
    const mondayOffset = (date.getDay() + 6) % 7;
    date.setDate(date.getDate() - mondayOffset + 3);

    const isoYear = date.getFullYear();
    const firstThursday = new Date(isoYear, 0, 4, 12);
    const firstOffset = (firstThursday.getDay() + 6) % 7;
    firstThursday.setDate(firstThursday.getDate() - firstOffset + 3);

    return 1 + Math.round((date - firstThursday) / (7 * 86400000));
}

// One ISO week label per calendar grid row, taken from the row's Thursday
// so a row maps to exactly one ISO week regardless of the first day of week.
function rowWeekNumbers(cells) {
    const weeks = [];
    for (let row = 0; row < 6; row += 1) {
        const thursday = cells[row * 7 + 3];
        weeks.push(isoWeekNumber(thursday.year, thursday.month, thursday.day));
    }
    return weeks;
}

function zoneOffsetMinutes(date, zone) {
    try {
        const localized = date.toLocaleString("sv-SE", { timeZone: zone });
        const asUTC = new Date(String(localized).replace(" ", "T") + "Z");
        if (!isNaN(asUTC.getTime())) {
            return Math.round((asUTC.getTime() - date.getTime()) / 60000);
        }
    } catch (error) {
        // Fall through to the local-time fallback below.
    }
    return 0;
}

function zoneShifted(date, zone) {
    return new Date(date.getTime() + zoneOffsetMinutes(date, zone) * 60000);
}

function zoneClock(date, zone) {
    const shifted = zoneShifted(date, zone);
    return pad2(shifted.getUTCHours()) + ":" + pad2(shifted.getUTCMinutes());
}

function zoneDayDelta(date, zone) {
    const shifted = zoneShifted(date, zone);
    const zoneDay = Date.UTC(
        shifted.getUTCFullYear(),
        shifted.getUTCMonth(),
        shifted.getUTCDate(),
    );
    const localDay = Date.UTC(
        date.getFullYear(),
        date.getMonth(),
        date.getDate(),
    );
    return Math.round((zoneDay - localDay) / 86400000);
}

function zoneLabel(zone) {
    const parts = String(zone || "").split("/");
    return parts[parts.length - 1].replace(/_/g, " ");
}

function pad2(value) {
    return String(value).padStart(2, "0");
}

if (typeof module !== "undefined") {
    module.exports = {
        timePattern,
        isoWeekNumber,
        rowWeekNumbers,
        zoneOffsetMinutes,
        zoneClock,
        zoneDayDelta,
        zoneLabel,
    };
}
