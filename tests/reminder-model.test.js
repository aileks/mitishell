const test = require("node:test");
const assert = require("node:assert/strict");

const ReminderModel = require("../shell/lib/ReminderModel.js");

test("reminder minutes are positive whole numbers", () => {
    assert.equal(ReminderModel.validMinutes("5"), 5);
    assert.equal(ReminderModel.validMinutes(" 12 "), 12);
    assert.equal(ReminderModel.validMinutes("0"), null);
    assert.equal(ReminderModel.validMinutes("-1"), null);
    assert.equal(ReminderModel.validMinutes("1.5"), null);
    assert.equal(ReminderModel.validMinutes("five"), null);
});

test("reminder arguments keep the message as one safe argument", () => {
    assert.deepEqual(ReminderModel.reminderArgs("5", "Check the oven"), ["5", "Check the oven"]);
    assert.deepEqual(ReminderModel.reminderArgs("5", ""), ["5"]);
    assert.deepEqual(ReminderModel.reminderArgs("nope", "message"), []);
});

test("remaining labels update through minutes and seconds", () => {
    const now = 1_000_000;
    assert.equal(ReminderModel.remainingLabel(1062, now), "1m 2s");
    assert.equal(ReminderModel.remainingLabel(1060, now), "1m");
    assert.equal(ReminderModel.remainingLabel(1007, now), "7s");
    assert.equal(ReminderModel.remainingLabel(900, now), "0s");
});

test("typed ids and count labels stay explicit", () => {
    assert.equal(ReminderModel.validId("0123456789abcdef"), true);
    assert.equal(ReminderModel.validId("../../timer"), false);
    assert.equal(ReminderModel.countLabel(1), "1 active reminder");
    assert.equal(ReminderModel.countLabel(3), "3 active reminders");
});

test("overlay transforms use the shared restrained entrance", () => {
    assert.deepEqual(ReminderModel.overlayTransform(true), { opacity: 1, scale: 1, offset: 0 });
    assert.deepEqual(ReminderModel.overlayTransform(false), { opacity: 0, scale: 0.98, offset: 12 });
});
