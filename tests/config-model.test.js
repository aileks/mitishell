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
