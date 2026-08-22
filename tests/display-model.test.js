const test = require("node:test");
const assert = require("node:assert/strict");

const DisplayModel = require("../shell/lib/DisplayModel.js");

test("brightness stays inside the 1-100 policy", () => {
    assert.equal(DisplayModel.clampBrightness(-10), 1);
    assert.equal(DisplayModel.clampBrightness(0), 1);
    assert.equal(DisplayModel.clampBrightness(64), 64);
    assert.equal(DisplayModel.clampBrightness(150), 100);
    assert.equal(DisplayModel.clampBrightness(Number.NaN), 1);
});

test("brightness steps use fine control near the bottom", () => {
    assert.equal(DisplayModel.stepBrightness(50, 5), 55);
    assert.equal(DisplayModel.stepBrightness(50, -5), 45);
    assert.equal(DisplayModel.stepBrightness(3, 5), 4);
    assert.equal(DisplayModel.stepBrightness(5, -5), 4);
    assert.equal(DisplayModel.stepBrightness(1, -5), 1);
    assert.equal(DisplayModel.stepBrightness(98, 5), 100);
});

test("brightness progress and labels serve the osd", () => {
    assert.equal(DisplayModel.progress(50), 0.5);
    assert.equal(DisplayModel.progress(100), 1);
    assert.equal(DisplayModel.percentLabel(55.4), "55%");
    assert.equal(DisplayModel.percentLabel(0), "1%");
});
