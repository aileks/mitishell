const test = require("node:test");
const assert = require("node:assert/strict");
const model = require("../shell/lib/BarModel.js");

test("islands move without losing hidden ids", () => {
    assert.deepEqual(model.move(["system", "audio", "weather"], 2, 0), ["weather", "system", "audio"]);
    assert.deepEqual(model.move(["system", "audio"], -1, 1), ["system", "audio"]);
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

test("pointer drops place islands before or after visible targets", () => {
    const order = ["system", "keyboardLayout", "audio", "updates", "clock"];

    assert.deepEqual(
        model.moveAtDrop(order, "clock", "system", false),
        ["clock", "system", "keyboardLayout", "audio", "updates"],
    );
    assert.deepEqual(
        model.moveAtDrop(order, "system", "audio", true),
        ["keyboardLayout", "audio", "system", "updates", "clock"],
    );
    assert.deepEqual(
        model.moveAtDrop(order, "audio", "clock", true),
        ["system", "keyboardLayout", "updates", "clock", "audio"],
    );
});

test("pointer drops preserve hidden islands and ignore no-op targets", () => {
    const order = ["system", "keyboardLayout", "audio", "updates", "clock"];

    assert.deepEqual(model.moveAtDrop(order, "audio", "audio", false), order);
    assert.deepEqual(model.moveAtDrop(order, "audio", "audio", true), order);
    assert.deepEqual(model.moveAtDrop(order, "missing", "clock", false), order);
    assert.deepEqual(model.moveAtDrop(order, "audio", "missing", false), order);
});
