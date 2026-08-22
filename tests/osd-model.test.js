const test = require("node:test");
const assert = require("node:assert/strict");

const OsdModel = require("../shell/lib/OsdModel.js");

test("volume icons follow level thresholds", () => {
    assert.equal(OsdModel.volumeIcon(0, false), "volume-x");
    assert.equal(OsdModel.volumeIcon(50, true), "volume-x");
    assert.equal(OsdModel.volumeIcon(33, false), "volume-1");
    assert.equal(OsdModel.volumeIcon(34, false), "volume-2");
    assert.equal(OsdModel.volumeIcon(100, false), "volume-2");
});

test("osd icons map by kind", () => {
    assert.equal(OsdModel.iconFor("volume", 80, false), "volume-2");
    assert.equal(OsdModel.iconFor("mic", 40, true), "mic-off");
    assert.equal(OsdModel.iconFor("mic", 40, false), "mic");
    assert.equal(OsdModel.iconFor("brightness", 20, false), "sun");
});
