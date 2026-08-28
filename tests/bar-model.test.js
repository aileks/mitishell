const test = require("node:test");
const assert = require("node:assert/strict");
const model = require("../shell/lib/BarModel.js");

function layout() {
    return {
        left: ["workspaces", "windowTitle"],
        center: ["media"],
        right: ["audio", "clock", "status", "power"],
        hidden: ["weather"],
    };
}

test("widgets move within and across sections without duplication", () => {
    const moved = model.moveAtDrop(layout(), "weather", "clock", false);
    assert.deepEqual(moved.right, ["audio", "weather", "clock", "status", "power"]);
    assert.deepEqual(moved.hidden, []);
});

test("interactive moves reject a fourth center widget", () => {
    const current = layout();
    current.center = ["media", "clock", "weather"];
    current.right = ["audio", "status", "power"];
    assert.deepEqual(model.moveTo(current, "audio", "center", 3), current);
});

test("keyboard movement crosses sections and respects center capacity", () => {
    const moved = model.moveKeyboard(layout(), "windowTitle", "next-section");
    assert.deepEqual(moved.left, ["workspaces"]);
    assert.deepEqual(moved.center, ["media", "windowTitle"]);
});

test("responsive overflow is non-mutating and preserves configured order", () => {
    const ids = ["audio", "clock", "weather", "status", "power"];
    const before = ids.slice();
    const overflow = model.overflowFor(
        ids,
        { audio: 50, clock: 50, weather: 50, status: 50, power: 50 },
        170,
        4,
        28,
    );
    assert.deepEqual(ids, before);
    assert.deepEqual(overflow, ["audio", "weather"]);
});

test("essential access remains visible when low-priority widgets can overflow", () => {
    assert.equal(model.priority("status"), 100);
    assert.equal(model.priority("power"), 100);
    assert.equal(model.priority("quickSettings"), 100);
    assert.equal(model.priority("audio"), 10);
});

test("a disabled hidden popover copy cannot activate", () => {
    const screen = { name: "DP-1" };
    assert.equal(
        model.popoverActive("networkQuick", screen, "networkQuick", screen, false),
        false,
    );
    assert.equal(
        model.popoverActive("networkQuick", screen, "networkQuick", screen, true),
        true,
    );
});

test("overflow stays open only for quick surfaces it contains", () => {
    const screen = { name: "DP-1" };
    const overflowIds = ["system", "audio"];
    assert.equal(
        model.overflowOpen(false, "networkQuick", screen, screen, overflowIds),
        false,
    );
    assert.equal(
        model.overflowOpen(false, "system", screen, screen, overflowIds),
        true,
    );
    assert.equal(
        model.overflowOpen(true, "barOverflow", screen, screen, overflowIds),
        true,
    );
});
