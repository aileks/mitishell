const test = require("node:test");
const assert = require("node:assert/strict");

const ClipboardModel = require("../shell/lib/ClipboardModel.js");

test("removeEntry drops only the matching entry", () => {
    const entries = ClipboardModel.removeEntry([
        { id: "a" }, { id: "b" }, { id: "c" },
    ], "b");
    assert.deepEqual(entries, [{ id: "a" }, { id: "c" }]);
});

test("removeEntry tolerates unusable input", () => {
    assert.deepEqual(ClipboardModel.removeEntry(undefined, "a"), []);
    assert.deepEqual(ClipboardModel.removeEntry([{ id: "a" }], null), [{ id: "a" }]);
});

test("preview returns the first non-empty line for the row label", () => {
    assert.equal(ClipboardModel.preview({ kind: "text", text: "\nsecond line\nthird" }), "second line");
    assert.equal(ClipboardModel.preview({ kind: "text", text: "  leading" }), "leading");
    assert.equal(ClipboardModel.preview({ kind: "text", text: "" }), "");
    assert.equal(ClipboardModel.preview({ kind: "image" }), "Image");
});

test("image rows expose dimensions, format, and searchable metadata", () => {
    const image = { kind: "image", width: 1920, height: 1080, mimeType: "image/png" };
    assert.equal(ClipboardModel.detail(image), "1920 × 1080 PNG");
    assert.deepEqual(ClipboardModel.keywords(image), ["image", "image/png", "1920 × 1080 PNG"]);
});
