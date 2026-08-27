const test = require("node:test");
const assert = require("node:assert/strict");

const ConfigModel = require("../shell/lib/ConfigModel.js");

test("wildcard enables every output", () => {
    assert.equal(ConfigModel.outputEnabled(["*"], "DP-4"), true);
    assert.equal(ConfigModel.outputEnabled(["*"], "HDMI-A-2"), true);
});

test("explicit outputs enable only matching connectors", () => {
    assert.equal(ConfigModel.outputEnabled(["DP-4"], "DP-4"), true);
    assert.equal(ConfigModel.outputEnabled(["DP-4"], "HDMI-A-2"), false);
});

test("bar targets mirror the wildcard and configured intersections", () => {
    assert.deepEqual(ConfigModel.barTargets(["*"], ["DP-1", "eDP-1"]), ["DP-1", "eDP-1"]);
    assert.deepEqual(
        ConfigModel.barTargets(["DP-1", "HDMI-A-1"], ["DP-1", "eDP-1"]),
        ["DP-1"],
    );
});

test("bar targets fall back to the first live screen when outputs vanish", () => {
    assert.deepEqual(ConfigModel.barTargets(["DP-1"], ["eDP-1", "DP-2"]), ["DP-2"]);
    assert.deepEqual(ConfigModel.barTargets(["DP-1"], []), []);
});
