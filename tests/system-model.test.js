const test = require("node:test");
const assert = require("node:assert/strict");

const SystemModel = require("../shell/lib/SystemModel.js");

test("cpu usage is calculated from consecutive aggregate samples", () => {
    const previous = SystemModel.parseCpu("cpu  100 10 50 800 20 5 5 10 0 0\n");
    const current = SystemModel.parseCpu("cpu  130 10 70 850 20 5 5 10 0 0\n");

    assert.deepEqual(previous, { idle: 820, total: 1000 });
    assert.equal(SystemModel.cpuUsage(previous, current), 50);
    assert.equal(SystemModel.cpuUsage(null, current), 0);
});

test("memory usage uses MemAvailable instead of free memory", () => {
    const memory = SystemModel.memory([
        "MemTotal:       16384000 kB",
        "MemFree:         1000000 kB",
        "MemAvailable:    4096000 kB",
    ].join("\n"));

    assert.deepEqual(memory, {
        totalBytes: 16777216000,
        usedBytes: 12582912000,
        percent: 75,
    });
});

test("load, uptime, and optional temperature are normalized", () => {
    assert.deepEqual(SystemModel.load("0.21 0.42 0.63 1/100 123"), [0.21, 0.42, 0.63]);
    assert.equal(SystemModel.uptime("90061.25 1000.00"), 90061);
    assert.equal(SystemModel.temperature("47500\n"), 47.5);
    assert.equal(SystemModel.temperature("not available"), null);
});

test("system values have concise display formats", () => {
    assert.equal(SystemModel.bytes(12582912000), "11.7 GiB");
    assert.equal(SystemModel.uptimeLabel(90061), "1d 1h");
    assert.equal(SystemModel.uptimeLabel(3660), "1h 1m");
});
