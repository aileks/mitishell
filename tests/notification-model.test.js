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
        summary: "Download <b>finished</b>",
        body: "file.tar.zst",
        urgency: 1,
        expireTimeout: 0,
        transient: false,
        actions: [{ identifier: "default", text: "" }, { identifier: "open", text: "Open" }],
    }, 1000);

    assert.equal(snapshot.id, 7);
    assert.equal(snapshot.appName, "Zen");
    assert.equal(snapshot.summary, "Download finished");
    assert.equal(snapshot.timeout, 8000);
    assert.equal(snapshot.timestamp, 1000);
    assert.deepEqual(snapshot.actions, [
        { identifier: "default", text: "" },
        { identifier: "open", text: "Open" },
    ]);
    assert.ok(!snapshot.actions[0].invoke);
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
