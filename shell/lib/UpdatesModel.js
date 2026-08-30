// Pure scheduling math for the daily update check. Kept free of QML and
// I/O so node --test can exercise it directly.

// Milliseconds from `now` until the next occurrence of local `hour`:00.
// A call made exactly at `hour`:00 schedules the following day, so the
// timer never re-fires in the same minute.
function nextDailyDelayMs(hour, now) {
    const next = new Date(now);
    next.setHours(hour, 0, 0, 0);
    if (next.getTime() <= now.getTime()) {
        next.setDate(next.getDate() + 1);
    }
    return next.getTime() - now.getTime();
}

if (typeof module !== "undefined") {
    module.exports = { nextDailyDelayMs };
}
