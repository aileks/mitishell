const test = require("node:test");
const assert = require("node:assert/strict");

const CalendarModel = require("../shell/lib/CalendarModel.js");

test("month grid honors the locale first day of week", () => {
    const mondayFirst = CalendarModel.monthGrid(2026, 4, 1);
    const sundayFirst = CalendarModel.monthGrid(2026, 4, 7);

    assert.deepEqual(mondayFirst[0], { year: 2026, month: 3, day: 27, inMonth: false });
    assert.deepEqual(mondayFirst[41], { year: 2026, month: 5, day: 7, inMonth: false });
    assert.deepEqual(sundayFirst[0], { year: 2026, month: 3, day: 26, inMonth: false });
});

test("month navigation crosses year boundaries", () => {
    assert.deepEqual(CalendarModel.shiftMonth(2026, 0, -1), { year: 2025, month: 11 });
    assert.deepEqual(CalendarModel.shiftMonth(2026, 11, 1), { year: 2027, month: 0 });
});

test("keyboard date movement crosses month boundaries", () => {
    assert.deepEqual(
        CalendarModel.moveDate({ year: 2026, month: 4, day: 1 }, -1),
        { year: 2026, month: 3, day: 30 },
    );
    assert.deepEqual(
        CalendarModel.moveDate({ year: 2026, month: 11, day: 31 }, 1),
        { year: 2027, month: 0, day: 1 },
    );
});

test("date equality compares calendar dates without time", () => {
    assert.equal(
        CalendarModel.sameDate(
            { year: 2026, month: 7, day: 20 },
            { year: 2026, month: 7, day: 20 },
        ),
        true,
    );
    assert.equal(
        CalendarModel.sameDate(
            { year: 2026, month: 7, day: 20 },
            { year: 2026, month: 7, day: 21 },
        ),
        false,
    );
});
