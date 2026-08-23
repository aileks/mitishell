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

test("icon resolution follows aliases, local files, bundled icons, and themes", () => {
    assert.deepEqual(OsdModel.resolveIcon("reminder", false), {
        kind: "bundled", value: "bell", fallback: "reminder",
    });
    assert.deepEqual(OsdModel.resolveIcon("file:///tmp/icon.png", false), {
        kind: "image", value: "file:///tmp/icon.png", fallback: "file:///tmp/icon.png",
    });
    assert.deepEqual(OsdModel.resolveIcon("settings", false), {
        kind: "bundled", value: "settings", fallback: "settings",
    });
    assert.deepEqual(OsdModel.resolveIcon("network-wireless", true), {
        kind: "theme", value: "network-wireless", fallback: "network-wireless",
    });
});

test("literal Nerd Font glyphs and text remain text", () => {
    assert.equal(OsdModel.resolveIcon("󰀻", false).kind, "text");
    assert.equal(OsdModel.resolveIcon("timer done", false).kind, "text");
    assert.deepEqual(OsdModel.resolveIcon("missing-theme-icon", false), {
        kind: "text", value: "missing-theme-icon", fallback: "missing-theme-icon",
    });
});

test("generic layout allows message and progress together", () => {
    assert.deepEqual(OsdModel.genericLayout("Compiling", 42.5), {
        hasMessage: true,
        hasProgress: true,
        message: "Compiling",
        progress: 0.425,
        label: "43%",
    });
    assert.deepEqual(OsdModel.genericLayout("", 7), {
        hasMessage: false,
        hasProgress: true,
        message: "",
        progress: 0.07,
        label: "7%",
    });
});
