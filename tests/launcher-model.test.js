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

test("nested launcher actions keep direct-child order and searchable paths", () => {
    const entries = [
        { id: "desktop", parent: "root", source: "menu", label: "Actions", keywords: [] },
        { id: "screenshot", parent: "desktop", source: "action", label: "Screenshot Region", keywords: [] },
        { id: "record", parent: "desktop", source: "menu", label: "Record Region", keywords: [] },
        { id: "record-mic", parent: "record", source: "action", label: "Microphone", keywords: [] },
    ];
    assert.deepEqual(
        LauncherModel.childEntries(entries, "desktop").map((entry) => entry.id),
        ["screenshot", "record"],
    );
    const searchable = LauncherModel.searchableActions(entries, "root");
    assert.deepEqual(searchable.map((entry) => entry.id), [
        "desktop", "screenshot", "record", "record-mic",
    ]);
    assert.equal(searchable[3].detail, "Actions › Record Region");
    assert.deepEqual(searchable[3].keywords, ["Actions", "Record Region"]);
});

test("descendant traversal ignores malformed cycles", () => {
    const entries = [
        { id: "one", parent: "root" },
        { id: "two", parent: "one" },
        { id: "one", parent: "two" },
    ];
    assert.deepEqual(
        LauncherModel.descendantEntries(entries, "root").map((entry) => entry.id),
        ["one", "two"],
    );
});

function desktopActionsSnapshot(overrides = {}) {
    return Object.assign({
        screenshotModes: ["region", "window", "output", "desktop"],
        ocrAvailable: true,
        qrAvailable: true,
        recordingModes: ["region", "output"],
        recordingActive: false,
        powerProfiles: [
            { name: "power-saver", active: false },
            { name: "balanced", active: true },
            { name: "performance", active: false },
        ],
        firmwareAvailable: true,
    }, overrides);
}

function entryIds(entries) {
    return entries.map((entry) => entry.id);
}

test("desktop action entries mirror the snapshot in menu order", () => {
    const entries = LauncherModel.desktopActionEntries(desktopActionsSnapshot(), {});
    assert.deepEqual(entryIds(entries), [
        "action:desktop-actions.screenshot-region",
        "action:desktop-actions.screenshot-window",
        "action:desktop-actions.screenshot-output",
        "action:desktop-actions.screenshot-desktop",
        "action:desktop-actions.extract-text",
        "action:desktop-actions.scan-qr",
        "action:desktop-actions.record-region",
        "action:desktop-actions.record-region.none",
        "action:desktop-actions.record-region.mic",
        "action:desktop-actions.record-region.desktop",
        "action:desktop-actions.record-region.desktop+mic",
        "action:desktop-actions.record-output",
        "action:desktop-actions.record-output.none",
        "action:desktop-actions.record-output.mic",
        "action:desktop-actions.record-output.desktop",
        "action:desktop-actions.record-output.desktop+mic",
        "action:desktop-actions.power-profile",
        "action:desktop-actions.power-profile.power-saver",
        "action:desktop-actions.power-profile.balanced",
        "action:desktop-actions.power-profile.performance",
        "action:desktop-actions.firmware",
    ]);
    const screenshot = entries.find((entry) => entry.id === "action:desktop-actions.screenshot-window");
    assert.deepEqual(screenshot.action.command, ["screenshot", "window"]);
    const microphone = entries.find((entry) => entry.id === "action:desktop-actions.record-region.mic");
    assert.equal(microphone.label, "Microphone");
    assert.deepEqual(microphone.action.command, ["record", "region", "mic"]);
    const desktopAudio = entries.find((entry) => entry.id === "action:desktop-actions.record-output.desktop");
    assert.deepEqual(desktopAudio.action.command, ["record", "output", "desktop"]);
});

test("desktop action entries nest audio choices under their record menu", () => {
    const entries = LauncherModel.desktopActionEntries(desktopActionsSnapshot(), {});
    const menu = entries.find((entry) => entry.id === "action:desktop-actions.record-region");
    const children = LauncherModel.childEntries(entries, menu.id);
    assert.deepEqual(children.map((child) => child.label), [
        "No Audio", "Microphone", "Desktop Audio", "Desktop + Microphone",
    ]);
});

test("an active recording replaces the record menus with a stop action", () => {
    const entries = LauncherModel.desktopActionEntries(
        desktopActionsSnapshot({ recordingActive: true }), {});
    const recordingEntries = entries.filter((entry) => entry.id.includes("record"));
    assert.deepEqual(entryIds(recordingEntries), ["action:desktop-actions.stop-recording"]);
    assert.deepEqual(recordingEntries[0].action.command, ["record", "stop"]);
});

test("record menus follow the available recording modes", () => {
    const entries = LauncherModel.desktopActionEntries(
        desktopActionsSnapshot({ recordingModes: ["region"] }), {});
    const recordingEntries = entryIds(entries.filter((entry) => entry.id.includes("record")));
    assert.deepEqual(recordingEntries, [
        "action:desktop-actions.record-region",
        "action:desktop-actions.record-region.none",
        "action:desktop-actions.record-region.mic",
        "action:desktop-actions.record-region.desktop",
        "action:desktop-actions.record-region.desktop+mic",
    ]);
});

test("entries hide when their supporting tools are missing", () => {
    const entries = LauncherModel.desktopActionEntries(desktopActionsSnapshot({
        screenshotModes: ["desktop"],
        ocrAvailable: false,
        qrAvailable: false,
        recordingModes: [],
        powerProfiles: [],
        firmwareAvailable: false,
    }), {});
    assert.deepEqual(entryIds(entries), ["action:desktop-actions.screenshot-desktop"]);
    assert.deepEqual(LauncherModel.desktopActionEntries({}, {}), []);
});

test("power profiles list dynamically with the active profile marked", () => {
    const icons = { camera: "camera", textScan: "text-scan", qrCode: "qr-code",
        record: "record", powerProfile: "power-profile", check: "check", update: "update" };
    const entries = LauncherModel.desktopActionEntries(desktopActionsSnapshot(), icons);
    const balanced = entries.find((entry) => entry.id === "action:desktop-actions.power-profile.balanced");
    assert.equal(balanced.label, "Balanced");
    assert.equal(balanced.detail, "Active");
    assert.equal(balanced.icon, "check");
    const saver = entries.find((entry) => entry.id === "action:desktop-actions.power-profile.power-saver");
    assert.equal(saver.label, "Power Saver");
    assert.equal(saver.detail, "Power Profile");
    assert.equal(saver.icon, "power-profile");
    assert.deepEqual(saver.action.command, ["power-profile", "power-saver"]);
    assert.equal(saver.action.successMessage, "Power profile set to Power Saver");
});

test("desktop actions never duplicate the direct dnd, night light, and reminders results", () => {
    const entries = LauncherModel.desktopActionEntries(desktopActionsSnapshot(), {});
    const ids = entryIds(entries);
    for (const direct of ["action:dnd", "action:night-light", "action:reminders"]) {
        assert.ok(!ids.includes(direct), `unexpected duplicate ${direct}`);
    }
    const labels = entries.map((entry) => entry.label.toLowerCase());
    for (const native of ["do not disturb", "night light", "reminder"]) {
        assert.ok(!labels.some((label) => label.includes(native)), `unexpected duplicate ${native}`);
    }
});

test("deep-opened menu ids fall back when a recording removes them", () => {
    // nativeActions() wraps the children with the parent Actions menu entry.
    const withActionsMenu = (children) => children.length === 0 ? [] : [{
        id: "action:desktop-actions",
        parent: "root",
        source: "menu",
        label: "Actions",
    }].concat(children);
    const idle = withActionsMenu(LauncherModel.desktopActionEntries(desktopActionsSnapshot(), {}));
    const recording = withActionsMenu(LauncherModel.desktopActionEntries(
        desktopActionsSnapshot({ recordingActive: true }), {}));
    const audioMenu = "action:desktop-actions.record-region";
    const actionsMenu = "action:desktop-actions";
    assert.equal(LauncherModel.resolveMenuId(idle, audioMenu, actionsMenu), audioMenu);
    assert.equal(LauncherModel.resolveMenuId(recording, audioMenu, actionsMenu), actionsMenu);
    assert.equal(LauncherModel.resolveMenuId(recording, actionsMenu, actionsMenu), actionsMenu);
});

test("resolveMenuId drops to root when the fallback is missing too", () => {
    assert.equal(LauncherModel.resolveMenuId([], "action:anything", "action:desktop-actions"), "root");
    assert.equal(LauncherModel.resolveMenuId([], "root", "action:desktop-actions"), "root");
});
