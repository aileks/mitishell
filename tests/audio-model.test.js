const test = require("node:test");
const assert = require("node:assert/strict");

const AudioModel = require("../shell/lib/AudioModel.js");

test("volume policy clamps output and input to 150 percent", () => {
    assert.equal(AudioModel.clampVolume(-0.1), 0);
    assert.equal(AudioModel.clampVolume(0.74), 0.74);
    assert.equal(AudioModel.clampVolume(2), 1.5);
    assert.equal(AudioModel.percent(1.499), 150);
});

test("volume steps remain inside the policy boundary", () => {
    assert.equal(AudioModel.stepVolume(1.49, 0.02), 1.5);
    assert.equal(AudioModel.stepVolume(0.01, -0.02), 0);
});

test("physical sinks and sources exclude streams", () => {
    const nodes = [
        { name: "speakers", isSink: true, isStream: false },
        { name: "music", isSink: true, isStream: true },
        { name: "microphone", isSink: false, isStream: false },
        { name: "capture", isSink: false, isStream: true },
    ];

    assert.deepEqual(AudioModel.sinks(nodes).map(node => node.name), ["speakers"]);
    assert.deepEqual(AudioModel.sources(nodes).map(node => node.name), ["microphone"]);
});

test("device labels prefer descriptions and remain useful", () => {
    assert.equal(
        AudioModel.deviceLabel({ description: "Built-in Audio", nickname: "Card", name: "node" }),
        "Built-in Audio",
    );
    assert.equal(AudioModel.deviceLabel({ nickname: "USB Mic", name: "node" }), "USB Mic");
    assert.equal(AudioModel.deviceLabel({ name: "alsa_output.pci" }), "alsa_output.pci");
    assert.equal(AudioModel.deviceLabel(null), "Unavailable");
});

test("bounded steps cap at 100 percent for keybinds", () => {
    assert.equal(AudioModel.stepVolumeWithin(0.98, 0.05, 1), 1);
    assert.equal(AudioModel.stepVolumeWithin(0.02, -0.05, 1), 0);
    assert.equal(AudioModel.stepVolumeWithin(1.4, 0.05, 1), 1);
});

test("playback streams exclude capture streams, devices, and the shell", () => {
    const nodes = [
        { name: "spotify", isStream: true, isSink: true },
        { name: "firefox", isStream: true, isSink: true },
        { name: "firefox-mic", isStream: true, isSink: false },
        { name: "speakers", isStream: false, isSink: true },
        { name: "microphone", isStream: false, isSink: false },
        { name: "quickshell", isStream: true, isSink: true },
        null,
    ];

    assert.deepEqual(
        AudioModel.playbackStreams(nodes).map(node => node.name),
        ["spotify", "firefox"],
    );
});

test("stream labels prefer the application name and degrade usefully", () => {
    assert.equal(
        AudioModel.streamLabel({ properties: { "application.name": "Firefox" }, description: "Raw", name: "node" }),
        "Firefox",
    );
    assert.equal(AudioModel.streamLabel({ description: "ALSA playback", name: "node" }), "ALSA playback");
    assert.equal(
        AudioModel.streamLabel({ properties: { "media.name": "Event sink" }, name: "node" }),
        "Event sink",
    );
    assert.equal(AudioModel.streamLabel({ name: "playback.pcm" }), "playback.pcm");
    assert.equal(AudioModel.streamLabel(null), "Unknown application");
});
