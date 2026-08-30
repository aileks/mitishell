const test = require("node:test");
const assert = require("node:assert/strict");

const ClipboardModel = require("../shell/lib/ClipboardModel.js");

test("removeEntry drops only the matching entry", () => {
    const entries = ClipboardModel.removeEntry(["a", "b", "c"], "b");
    assert.deepEqual(entries, ["a", "c"]);
});

test("removeEntry tolerates unusable input", () => {
    assert.deepEqual(ClipboardModel.removeEntry(undefined, "a"), []);
    assert.deepEqual(ClipboardModel.removeEntry(["a"], null), ["a"]);
});

test("preview returns the first non-empty line for the row label", () => {
    assert.equal(ClipboardModel.preview("\nsecond line\nthird"), "second line");
    assert.equal(ClipboardModel.preview("  leading"), "leading");
    assert.equal(ClipboardModel.preview(""), "");
});

test("entryLimit falls back to 25 for unusable caps", () => {
    assert.equal(ClipboardModel.entryLimit(40), 40);
    assert.equal(ClipboardModel.entryLimit(undefined), 25);
    assert.equal(ClipboardModel.entryLimit(0), 25);
});
