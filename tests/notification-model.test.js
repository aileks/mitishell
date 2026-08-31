const test = require("node:test");
const assert = require("node:assert/strict");

const NotificationModel = require("../shell/lib/NotificationModel.js");

test("popup durations follow urgency floors and sender overrides", () => {
    assert.equal(NotificationModel.popupDuration(2, 5000), 0);
    assert.equal(NotificationModel.popupDuration(0, 0), 5000);
    assert.equal(NotificationModel.popupDuration(1, 0), 8000);
    assert.equal(NotificationModel.popupDuration(1, -1), 8000);
    assert.equal(NotificationModel.popupDuration(1, 20000), 20000);
    assert.equal(NotificationModel.popupDuration(0, 1000), 5000);
    assert.equal(NotificationModel.popupDuration(1, 600000), 30000);
});

test("bodies lose markup but keep their text", () => {
    assert.equal(NotificationModel.plainBody("<b>Bold</b> and <i>italic</i>"), "Bold and italic");
    assert.equal(NotificationModel.plainBody("line one<br/>line two"), "line one\nline two");
    assert.equal(
        NotificationModel.plainBody("<a href=\"https://example.com\">link</a> &amp; more"),
        "link & more",
    );
    assert.equal(NotificationModel.plainBody(""), "");
});

test("snapshots copy drawable fields without the live object", () => {
    const snapshot = NotificationModel.snapshotOf({
        id: 7,
        appName: "Zen",
        appIcon: "zen-browser",
        desktopEntry: "app.zen_browser.zen",
        image: "file:///tmp/preview.png",
        summary: "Download <b>finished</b>",
        body: "file.tar.zst",
        urgency: 1,
        expireTimeout: 0,
        transient: false,
        hints: { "x-mitishell-reminder": true },
        actions: [{ identifier: "default", text: "" }, { identifier: "open", text: "Open" }],
    }, 1000);

    assert.equal(snapshot.recordId, "1000-7");
    assert.equal(snapshot.liveId, 7);
    assert.equal(snapshot.appName, "Zen");
    assert.equal(snapshot.appIcon, "zen-browser");
    assert.equal(snapshot.desktopEntry, "app.zen_browser.zen");
    assert.equal(snapshot.image, "file:///tmp/preview.png");
    assert.equal(snapshot.summary, "Download finished");
    assert.equal(snapshot.timeout, 8000);
    assert.equal(snapshot.timestamp, 1000);
    assert.equal(snapshot.reminder, true);
    assert.deepEqual(snapshot.actions, [
        { identifier: "default", text: "" },
        { identifier: "open", text: "Open" },
    ]);
    assert.ok(!snapshot.actions[0].invoke);
    assert.equal(snapshot.live, true);
});

test("notification images lead the compact icon fallback order", () => {
    assert.equal(NotificationModel.avatarValue({
        image: "image://notifications/8",
        appIcon: "signal-desktop",
        desktopEntry: "signal",
    }), "image://notifications/8");
    assert.equal(NotificationModel.avatarValue({
        image: "",
        appIcon: "signal-desktop",
        desktopEntry: "signal",
    }), "signal-desktop");
    assert.equal(NotificationModel.avatarValue({
        image: "",
        appIcon: "",
        desktopEntry: "signal",
    }), "signal");
    assert.equal(NotificationModel.avatarValue({}), "");
});

test("durable snapshots omit actions and restored records are history only", () => {
    const live = NotificationModel.snapshotOf({
        id: 9,
        appName: "Camera",
        appIcon: "camera",
        image: "image://notifications/9",
        summary: "Saved",
        body: "photo.png",
        urgency: 1,
        expireTimeout: 0,
        actions: [{ identifier: "open", text: "Open" }],
    }, 2000);
    live.persistedAppIcon = "file:///state/avatar.png";
    live.persistedImage = "file:///state/image.png";

    const durable = NotificationModel.durableEntry(live);
    assert.deepEqual(durable, {
        recordId: "2000-9",
        appName: "Camera",
        desktopEntry: "",
        appIcon: "file:///state/avatar.png",
        image: "file:///state/image.png",
        summary: "Saved",
        body: "photo.png",
        urgency: 1,
        reminder: false,
        timestamp: 2000,
    });
    assert.equal(durable.actions, undefined);

    const restored = NotificationModel.restoredSnapshot(durable);
    assert.equal(restored.live, false);
    assert.equal(restored.liveId, -1);
    assert.deepEqual(restored.actions, []);
    assert.equal(restored.appIcon, "file:///state/avatar.png");
    assert.equal(restored.timeout, 0);
});

test("explicit reminders bypass do not disturb without becoming critical", () => {
    assert.equal(NotificationModel.popupAllowed(true, { urgency: 1, reminder: true }), true);
    assert.equal(NotificationModel.popupAllowed(true, { urgency: 2, reminder: false }), true);
    assert.equal(NotificationModel.popupAllowed(true, { urgency: 1, reminder: false }), false);
    assert.equal(NotificationModel.popupAllowed(false, { urgency: 0, reminder: false }), true);
});

test("transient notifications are excluded from durable history", () => {
    const durable = { recordId: "1-1", transient: false };
    const transient = { recordId: "1-2", transient: true };
    const entries = NotificationModel.durableEntries([
        Object.assign({
            appName: "",
            desktopEntry: "",
            persistedAppIcon: "",
            persistedImage: "",
            summary: "saved",
            body: "",
            urgency: 1,
            timestamp: 1,
        }, durable),
        Object.assign({
            appName: "",
            desktopEntry: "",
            persistedAppIcon: "",
            persistedImage: "",
            summary: "temporary",
            body: "",
            urgency: 1,
            timestamp: 1,
        }, transient),
    ]);
    assert.deepEqual(entries.map((entry) => entry.recordId), ["1-1"]);
});

test("replacement snapshots retain their stable record identity", () => {
    const replacement = NotificationModel.snapshotOf({
        id: 3,
        summary: "Updated",
        urgency: 1,
        actions: [],
    }, 5000, "1000-3");
    assert.equal(replacement.recordId, "1000-3");
    assert.equal(replacement.liveId, 3);
    assert.equal(replacement.summary, "Updated");
});

test("time labels and unread counting", () => {
    const now = 1000000;
    assert.equal(NotificationModel.timeLabel(now - 10000, now), "now");
    assert.equal(NotificationModel.timeLabel(now - 5 * 60000, now), "5m");
    assert.equal(NotificationModel.timeLabel(now - 3 * 3600000, now), "3h");
    assert.equal(NotificationModel.timeLabel(now - 2 * 86400000, now), "2d");

    const history = [{ timestamp: 100 }, { timestamp: 500 }, { timestamp: 900 }];
    assert.equal(NotificationModel.unreadCount(history, 400), 2);
    assert.equal(NotificationModel.unreadCount(history, 1000), 0);
});

test("popup target follows the focused output when it has a bar", () => {
    const outputs = ["DP-1", "HDMI-A-1"];
    assert.equal(NotificationModel.popupTarget("DP-1", ["DP-1", "HDMI-A-1"], outputs), "DP-1");
    assert.equal(NotificationModel.popupTarget("eDP-1", ["DP-1", "HDMI-A-1"], outputs), "DP-1");
    assert.equal(NotificationModel.popupTarget("eDP-1", ["DP-1", "HDMI-A-1"], ["*"]), "eDP-1");
    assert.equal(NotificationModel.popupTarget("eDP-1", ["DP-1", "HDMI-A-1"], ["HDMI-A-1"]), "HDMI-A-1");
    assert.equal(NotificationModel.popupTarget("DP-1", [], ["*"]), "DP-1");
    assert.equal(NotificationModel.popupTarget("DP-1", [], ["HDMI-A-1"]), "");
});

test("expired popups report only past deadlines", () => {
    const deadlines = {
        "100-1": 8000,
        "100-2": 12000,
        "100-3": 5000,
    };
    assert.deepEqual(
        NotificationModel.expiredPopups(deadlines, 10000),
        ["100-1", "100-3"],
    );
    assert.deepEqual(NotificationModel.expiredPopups(deadlines, 4999), []);
    assert.deepEqual(NotificationModel.expiredPopups(deadlines, 12000), ["100-1", "100-2", "100-3"]);
    assert.deepEqual(NotificationModel.expiredPopups(undefined, 10000), []);
});
