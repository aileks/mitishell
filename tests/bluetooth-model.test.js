const test = require("node:test");
const assert = require("node:assert/strict");

const BluetoothModel = require("../shell/lib/BluetoothModel.js");

test("device status reflects pairing state", () => {
    assert.equal(BluetoothModel.deviceStatus({ connected: true, paired: true }), "Connected");
    assert.equal(BluetoothModel.deviceStatus({ connected: false, paired: true }), "Paired");
    assert.equal(BluetoothModel.deviceStatus({ connected: false, paired: false, inRange: true }), "Discovered");
    assert.equal(BluetoothModel.deviceStatus({ connected: false, paired: false }), "Known");
});

test("device actions follow state", () => {
    assert.deepEqual(
        BluetoothModel.deviceActions({ connected: true, paired: true, trusted: true }),
        ["disconnect", "untrust", "forget"],
    );
    assert.deepEqual(
        BluetoothModel.deviceActions({ connected: false, paired: true, trusted: false }),
        ["connect", "trust", "forget"],
    );
    assert.deepEqual(
        BluetoothModel.deviceActions({ connected: false, paired: false }),
        ["pair"],
    );
});

test("device action labels map to backend verbs", () => {
    assert.equal(BluetoothModel.actionVerb("forget"), "remove");
    assert.equal(BluetoothModel.actionVerb("disconnect"), "disconnect");
});

test("pairing action reports useful progress", () => {
    assert.equal(BluetoothModel.actionProgressLabel("pair"), "Pairing…");
});

test("pairing prompts read clearly", () => {
    assert.equal(
        BluetoothModel.pairPromptLabel({ kind: "confirm", passkey: "123456", device: "WH-1000XM5" }),
        "Confirm the passkey 123456 on WH-1000XM5",
    );
    assert.equal(
        BluetoothModel.pairPromptLabel({ kind: "authorize", device: "Mouse" }),
        "Allow Mouse to connect",
    );
    assert.equal(
        BluetoothModel.pairPromptLabel({ kind: "display-passkey", passkey: "654321", device: "Keyboard" }),
        "Type 654321 on Keyboard",
    );
    assert.equal(BluetoothModel.requestIsDisplayOnly({ kind: "display-pin" }), true);
    assert.equal(BluetoothModel.requestWantsText({ kind: "passkey" }), true);
});
