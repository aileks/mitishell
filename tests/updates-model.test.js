const test = require("node:test");
const assert = require("node:assert/strict");

const UpdatesModel = require("../shell/lib/UpdatesModel.js");

test("delay targets 9 am the same morning before it passes", () => {
    const now = new Date(2026, 7, 28, 7, 30);
    assert.equal(UpdatesModel.nextDailyDelayMs(9, now), 90 * 60 * 1000);
});

test("delay rolls to the next morning after 9 am", () => {
    const now = new Date(2026, 7, 28, 12, 0);
    assert.equal(UpdatesModel.nextDailyDelayMs(9, now), 21 * 60 * 60 * 1000);
});

test("a call exactly at 9 am schedules the following day", () => {
    const now = new Date(2026, 7, 28, 9, 0, 0, 0);
    assert.equal(UpdatesModel.nextDailyDelayMs(9, now), 24 * 60 * 60 * 1000);
});

test("delay keeps sub-minute precision", () => {
    const now = new Date(2026, 7, 28, 8, 59, 30, 500);
    assert.equal(UpdatesModel.nextDailyDelayMs(9, now), 29500);
});
