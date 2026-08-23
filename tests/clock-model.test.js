const test = require("node:test");
const assert = require("node:assert/strict");

const ClockModel = require("../shell/lib/ClockModel.js");

test("time pattern presets map to fixed patterns", () => {
    assert.equal(ClockModel.timePattern("24h", "h:mm AP"), "HH:mm");
    assert.equal(ClockModel.timePattern("12h", "H:mm"), "h:mm AP");
    assert.equal(ClockModel.timePattern("24h-seconds", "H:mm"), "HH:mm:ss");
    assert.equal(ClockModel.timePattern("12h-seconds", "H:mm"), "h:mm:ss AP");
});

test("auto time pattern falls back to the locale pattern", () => {
    assert.equal(ClockModel.timePattern("auto", "HH:mm"), "HH:mm");
    assert.equal(ClockModel.timePattern("unknown", "h:mm"), "h:mm");
});

test("iso week numbers match ISO 8601 week boundaries", () => {
    assert.equal(ClockModel.isoWeekNumber(2026, 0, 1), 1);
    assert.equal(ClockModel.isoWeekNumber(2025, 11, 28), 52);
    assert.equal(ClockModel.isoWeekNumber(2025, 11, 29), 1);
    assert.equal(ClockModel.isoWeekNumber(2026, 7, 23), 34);
    assert.equal(ClockModel.isoWeekNumber(2026, 11, 28), 53);
    assert.equal(ClockModel.isoWeekNumber(2027, 0, 1), 53);
});

test("row week numbers label each grid row once", () => {
    const cells = [];
    for (let index = 0; index < 42; index += 1) {
        // August 2026 starts on Saturday; a Monday-first grid opens with
        // the tail of July, and its Thursdays step one ISO week per row.
        cells.push({ year: 2026, month: 7, day: index - 5 });
    }
    const cellsWithRealDates = cells.map(function(cell) {
        const date = new Date(cell.year, cell.month, cell.day, 12);
        return {
            year: date.getFullYear(),
            month: date.getMonth(),
            day: date.getDate(),
        };
    });

    const weeks = ClockModel.rowWeekNumbers(cellsWithRealDates);
    assert.equal(weeks.length, 6);
    assert.deepEqual(weeks, [31, 32, 33, 34, 35, 36]);
});

test("zone clock renders wall time in the requested zone", () => {
    // 2026-08-23 16:00 UTC is 12:00 in New York (EDT, UTC-4) and 18:00
    // in Berlin (CEST, UTC+2).
    const moment = new Date(Date.UTC(2026, 7, 23, 16, 0, 0));
    assert.equal(ClockModel.zoneClock(moment, "UTC"), "16:00");
    assert.equal(ClockModel.zoneClock(moment, "America/New_York"), "12:00");
    assert.equal(ClockModel.zoneClock(moment, "Europe/Berlin"), "18:00");
    assert.equal(ClockModel.zoneClock(moment, "Asia/Kolkata"), "21:30");
});

test("zone day delta reports calendar-day drift", () => {
    // Deltas compare a zone's calendar day against the viewer's local day,
    // so assertions are relative to the UTC delta and hold in any TZ.
    const moment = new Date(Date.UTC(2026, 7, 23, 16, 0, 0));
    const utcDelta = ClockModel.zoneDayDelta(moment, "UTC");
    assert.equal(ClockModel.zoneDayDelta(moment, "America/Los_Angeles"), utcDelta);
    assert.equal(ClockModel.zoneDayDelta(moment, "Asia/Tokyo"), utcDelta + 1);
    const lateMoment = new Date(Date.UTC(2026, 7, 23, 2, 0, 0));
    const lateUtcDelta = ClockModel.zoneDayDelta(lateMoment, "UTC");
    assert.equal(
        ClockModel.zoneDayDelta(lateMoment, "America/Los_Angeles"),
        lateUtcDelta - 1,
    );
});

test("unknown zones fall back to UTC rendering", () => {
    const moment = new Date(Date.UTC(2026, 7, 23, 16, 0, 0));
    assert.equal(ClockModel.zoneClock(moment, "Mars/Olympus"), "16:00");
    assert.equal(
        ClockModel.zoneDayDelta(moment, "Mars/Olympus"),
        ClockModel.zoneDayDelta(moment, "UTC"),
    );
});

test("zone labels keep the city and expand underscores", () => {
    assert.equal(ClockModel.zoneLabel("Europe/Berlin"), "Berlin");
    assert.equal(ClockModel.zoneLabel("America/New_York"), "New York");
    assert.equal(ClockModel.zoneLabel("UTC"), "UTC");
});
