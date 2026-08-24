const test = require("node:test");
const assert = require("node:assert/strict");
const model = require("../shell/lib/BarModel.js");

test("islands move without losing hidden ids", () => {
    assert.deepEqual(model.move(["system", "audio", "weather"], 2, 0), ["weather", "system", "audio"]);
    assert.deepEqual(model.move(["system", "audio"], -1, 1), ["system", "audio"]);
});

test("separator lookup skips hidden islands and avoids edges", () => {
    const order = ["system", "updates", "clock", "weather"];
    const visible = id => id !== "updates";
    assert.equal(model.nextVisible(order, 0, visible), "clock");
    assert.equal(model.separatorAfter("system", "clock"), true);
    assert.equal(model.separatorAfter("clock", "weather"), true);
    assert.equal(model.separatorAfter("weather", ""), false);
});

test("render order derives only meaningful separators", () => {
    const visible = id => !["keyboardLayout", "updates", "reminders"].includes(id);
    assert.deepEqual(
        model.render(["weather", "system", "keyboardLayout", "audio", "updates", "clock", "reminders"], visible),
        [
            { id: "weather", separatorAfter: false },
            { id: "system", separatorAfter: true },
            { id: "audio", separatorAfter: true },
            { id: "clock", separatorAfter: false },
        ],
    );
});

test("keyboard moves use visible neighbors and retain hidden islands", () => {
    const order = ["system", "keyboardLayout", "audio", "updates", "clock"];
    const visible = id => id !== "keyboardLayout" && id !== "updates";
    assert.equal(model.visibleTarget(order, 0, 1, visible), 2);
    assert.deepEqual(
        model.moveVisible(order, 0, 1, visible),
        ["keyboardLayout", "audio", "system", "updates", "clock"],
    );
    assert.deepEqual(model.moveVisible(order, 4, 1, visible), order);
});
