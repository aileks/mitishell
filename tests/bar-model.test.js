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

test("drop target picks the pill in the pointer row and reports its side", () => {
    const rects = [
        { id: "updates", x: 0, y: 0, width: 80, height: 28 },
        { id: "system", x: 88, y: 0, width: 80, height: 28 },
        { id: "audio", x: 176, y: 0, width: 80, height: 28 },
        { id: "quickSettings", x: 0, y: 32, width: 120, height: 28 },
    ];
    assert.deepEqual(model.dropTargetAt(rects, 60, 14), { id: "updates", after: true });
    assert.deepEqual(model.dropTargetAt(rects, 20, 10), { id: "updates", after: false });
    assert.deepEqual(model.dropTargetAt(rects, 40, 46), { id: "quickSettings", after: false });
    assert.deepEqual(model.dropTargetAt(rects, 100, 46), { id: "quickSettings", after: true });
    assert.equal(model.dropTargetAt(rects, 100, 30), null);
    assert.equal(model.dropTargetAt([], 0, 0), null);
});

test("arrow keys map to the four keyboard move directions", () => {
    assert.equal(model.moveDirection(0x01000012), "previous");
    assert.equal(model.moveDirection(0x01000013), "next");
    assert.equal(model.moveDirection(0x01000014), "previous-section");
    assert.equal(model.moveDirection(0x01000015), "next-section");
    assert.equal(model.moveDirection(0x41), "");
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

test("light sides keep an even budget split", () => {
    const widths = { workspaces: 100, power: 60 };
    assert.deepEqual(
        model.overflowBudgets(["workspaces"], ["power"], widths, 400, 4, 28),
        { left: 200, right: 200 },
    );
});

test("a crowded side uses the other side's unused space", () => {
    const widths = { workspaces: 100, media: 200, power: 60 };
    const budgets = model.overflowBudgets(
        ["workspaces", "media"],
        ["power"],
        widths,
        400,
        4,
        28,
    );
    assert.deepEqual(budgets, { left: 304, right: 96 });
    assert.deepEqual(model.overflowFor(["workspaces", "media"], widths, budgets.left, 4, 28), []);
    assert.deepEqual(model.overflowFor(["power"], widths, budgets.right, 4, 28), []);
});

test("sides over their share fall back to an even split", () => {
    const widths = { workspaces: 100, media: 200, clock: 100, updates: 200 };
    assert.deepEqual(
        model.overflowBudgets(
            ["workspaces", "media"],
            ["clock", "updates"],
            widths,
            400,
            4,
            28,
        ),
        { left: 200, right: 200 },
    );
});

test("essential-heavy sides keep the even split rather than hiding access", () => {
    const widths = { workspaces: 300, power: 300 };
    assert.deepEqual(
        model.overflowBudgets(["workspaces"], ["power"], widths, 400, 4, 28),
        { left: 200, right: 200 },
    );
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
