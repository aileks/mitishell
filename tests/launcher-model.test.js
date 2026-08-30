const test = require("node:test");
const assert = require("node:assert/strict");

const LauncherModel = require("../shell/lib/LauncherModel.js");

function desktop(id, name, extra = {}) {
    return Object.assign({ id, name, genericName: "", comment: "", icon: "", keywords: [] }, extra);
}

test("launchCommand wraps app argv with uwsm when the session is managed", () => {
    assert.deepEqual(
        LauncherModel.launchCommand(["foot", "-e", "sh"], true),
        ["uwsm", "app", "--", "foot", "-e", "sh"],
    );
    assert.deepEqual(
        LauncherModel.launchCommand(["foot"], false),
        ["foot"],
    );
});

test("launchCommand passes through empty command lines untouched", () => {
    assert.deepEqual(LauncherModel.launchCommand([], true), []);
    assert.deepEqual(LauncherModel.launchCommand(undefined, false), []);
});

test("runCommand shells out through uwsm when the session is managed", () => {
    assert.deepEqual(
        LauncherModel.runCommand("killall wine", true),
        ["uwsm", "app", "--", "sh", "-c", "killall wine"],
    );
    assert.deepEqual(
        LauncherModel.runCommand("killall wine", false),
        ["sh", "-c", "killall wine"],
    );
    assert.deepEqual(LauncherModel.runCommand("   ", true), []);
    assert.deepEqual(LauncherModel.runCommand("", false), []);
});

test("application normalization filters hidden and unnamed entries", () => {
    const firefox = desktop("firefox.desktop", "Firefox", {
        genericName: "Web Browser",
        icon: "firefox",
        keywords: ["internet"],
    });
    const entries = LauncherModel.applicationEntries([
        firefox,
        desktop("hidden.desktop", "Hidden", { hidden: true }),
        desktop("no-display.desktop", "No display", { noDisplay: true }),
        desktop("nameless.desktop", "  "),
    ]);
    assert.deepEqual(firefox.keywords, ["internet"]);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].desktopEntry, firefox);
    assert.deepEqual(entries[0], {
        id: "app:firefox.desktop",
        desktopId: "firefox.desktop",
        source: "application",
        label: "Firefox",
        detail: "Web Browser",
        icon: "firefox",
        keywords: ["internet", "Web Browser", "firefox.desktop"],
        desktopEntry: firefox,
    });
});

test("application normalization accepts QuickShell-style list models", () => {
    const firefox = desktop("firefox.desktop", "Firefox");
    const listModel = {
        forEach(callback) { callback(firefox); },
    };
    assert.deepEqual(
        LauncherModel.applicationEntries(listModel).map((entry) => entry.desktopId),
        ["firefox.desktop"],
    );
});

test("blank launcher leads with available recents then sorts everything else", () => {
    const apps = LauncherModel.applicationEntries([
        desktop("z.desktop", "Zed"),
        desktop("a.desktop", "Alacritty"),
        desktop("f.desktop", "Firefox"),
    ]);
    const actions = [{ id: "action:settings", label: "Settings", source: "action" }];
    const result = LauncherModel.blankEntries(
        apps,
        actions,
        ["f.desktop", "missing.desktop", "z.desktop"],
    );
    assert.deepEqual(result.map((entry) => entry.id), [
        "app:f.desktop", "app:z.desktop", "app:a.desktop", "action:settings",
    ]);
});

test("recent updates are unique and bounded", () => {
    const original = ["one", "two", "three", "four", "five"];
    assert.deepEqual(LauncherModel.addRecent(original, "three"), [
        "three", "one", "two", "four", "five",
    ]);
    assert.deepEqual(LauncherModel.addRecent(original, "six"), [
        "six", "one", "two", "three", "four",
    ]);
});

test("loaded recents append without displacing launches made during startup", () => {
    assert.deepEqual(
        LauncherModel.mergeRecents(
            ["new.desktop"],
            ["old-one.desktop", "old-two.desktop"],
        ),
        ["new.desktop", "old-one.desktop", "old-two.desktop"],
    );
    assert.deepEqual(
        LauncherModel.mergeRecents(
            ["new.desktop", "old-one.desktop"],
            ["old-one.desktop", "old-two.desktop"],
        ),
        ["new.desktop", "old-one.desktop", "old-two.desktop"],
    );
});
