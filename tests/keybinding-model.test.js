const test = require("node:test");
const assert = require("node:assert/strict");

const KeybindingModel = require("../shell/lib/KeybindingModel.js");

test("modifier masks use canonical order and retain unknown bits", () => {
    assert.deepEqual(KeybindingModel.modifiersForMask(64 | 4 | 1), ["SUPER", "CTRL", "SHIFT"]);
    assert.deepEqual(KeybindingModel.modifiersForMask(256), ["0x100"]);
});

test("parser preserves duplicates, missing descriptions, keys, and keycodes", () => {
    const parsed = KeybindingModel.parseBindings(JSON.stringify([
        { modmask: 64, key: "Space", description: "Launcher", submap: "" },
        { modmask: 64, key: "Space", description: "", submap: "resize", repeat: true },
        { modmask: 0, key: "", keycode: 42, description: "Keycode", submap: "" },
    ]));
    assert.equal(parsed.ok, true);
    assert.equal(parsed.entries.length, 3);
    assert.equal(parsed.entries[0].shortcut, "SUPER + Space");
    assert.equal(parsed.entries[1].description, "Undescribed binding");
    assert.deepEqual(parsed.entries[1].flags, ["Repeat"]);
    assert.equal(parsed.entries[2].key, "code:42");
});

test("launcher binding uses the concise viewer label", () => {
    assert.equal(KeybindingModel.bindingDescription({
        description: "Application launcher",
    }), "Launcher");
});

test("special binding flags receive readable labels", () => {
    assert.deepEqual(KeybindingModel.flagsFor({
        mouse: true,
        locked: true,
        release: true,
        repeat: true,
        longPress: true,
        non_consuming: true,
        auto_consuming: true,
        catch_all: true,
        submap_universal: "true",
    }), [
        "Mouse", "Locked", "Release", "Repeat", "Long press",
        "Non-consuming", "Auto-consuming", "Catch all", "Universal",
    ]);
});

test("bindings group globally then by submap in first-seen order", () => {
    const entries = [
        { id: "1", submap: "resize" },
        { id: "2", submap: "" },
        { id: "3", submap: "move" },
        { id: "4", submap: "resize" },
    ];
    const grouped = KeybindingModel.groupBindings(entries);
    assert.deepEqual(grouped.map((entry) => entry.id), ["2", "1", "4", "3"]);
    assert.deepEqual(grouped.map((entry) => entry.groupLabel), ["Global", "resize", "", "move"]);
});

test("invalid binding JSON is reported", () => {
    assert.equal(KeybindingModel.parseBindings("not json").ok, false);
    assert.equal(KeybindingModel.parseBindings("{}").ok, false);
});
