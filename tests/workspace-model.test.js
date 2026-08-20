const test = require("node:test");
const assert = require("node:assert/strict");

const WorkspaceModel = require("../shell/lib/WorkspaceModel.js");

test("workspace ids are filtered by output and ordered numerically", () => {
    const workspaces = [
        { id: 8, monitor: { name: "HDMI-A-2" } },
        { id: 3, monitor: { name: "DP-4" } },
        { id: 1, monitor: { name: "DP-4" } },
        { id: -99, monitor: { name: "DP-4" } },
        { id: 2, monitor: { name: "DP-4" } },
    ];

    assert.deepEqual(WorkspaceModel.idsForMonitor(workspaces, "DP-4"), [1, 2, 3]);
});

test("workspace label maps ten to zero", () => {
    assert.equal(WorkspaceModel.label(10), "0");
    assert.equal(WorkspaceModel.label(4), "4");
});

test("window title uses the active workspace title with a desktop fallback", () => {
    assert.equal(
        WorkspaceModel.windowTitle({ lastIpcObject: { lastwindowtitle: "Terminal" } }),
        "Terminal",
    );
    assert.equal(WorkspaceModel.windowTitle(null), "Desktop");
    assert.equal(
        WorkspaceModel.windowTitle({ lastIpcObject: { lastwindowtitle: "   " } }),
        "Desktop",
    );
});
