const test = require("node:test");
const assert = require("node:assert/strict");

const NetworkModel = require("../shell/lib/NetworkModel.js");

test("signal strength maps to bars", () => {
    assert.equal(NetworkModel.signalBars(100), 4);
    assert.equal(NetworkModel.signalBars(80), 4);
    assert.equal(NetworkModel.signalBars(79), 3);
    assert.equal(NetworkModel.signalBars(31), 2);
    assert.equal(NetworkModel.signalBars(5), 1);
    assert.equal(NetworkModel.signalBars(0), 0);
});

test("security and state labels stay readable", () => {
    assert.equal(NetworkModel.securityLabel("wpa3"), "WPA3");
    assert.equal(NetworkModel.securityLabel("enterprise"), "Enterprise");
    assert.equal(NetworkModel.securityLabel("mystery"), "Secured");
    assert.equal(NetworkModel.stateLabel("connecting"), "Connecting");
    assert.equal(NetworkModel.stateLabel("failed"), "Connection failed");
    assert.equal(NetworkModel.stateLabel("unavailable"), "Unavailable");
});

test("saved out-of-range networks stay listable", () => {
    const stations = [
        { ssid: "Home", signal: 80, security: "wpa2", inUse: true, saved: true },
        { ssid: "Cafe", signal: 40, security: "open", inUse: false, saved: false },
    ];
    const saved = [
        { id: "home", ssid: "Home" },
        { id: "old", ssid: "Gone" },
    ];

    const listed = NetworkModel.listableStations(stations, saved);

    assert.deepEqual(listed.map(station => station.ssid), ["Home", "Cafe", "Gone"]);
    assert.equal(listed[2].outOfRange, true);
    assert.equal(listed[2].saved, true);
});
