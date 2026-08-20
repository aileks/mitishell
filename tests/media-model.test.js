const test = require("node:test");
const assert = require("node:assert/strict");

const MediaModel = require("../shell/lib/MediaModel.js");

test("session override selects the requested available player", () => {
    const players = [
        player("org.mpris.MediaPlayer2.first", { isPlaying: true }),
        player("org.mpris.MediaPlayer2.second"),
    ];

    assert.equal(
        MediaModel.choosePlayer(players, "org.mpris.MediaPlayer2.second").dbusName,
        "org.mpris.MediaPlayer2.second",
    );
});

test("missing override falls back to a playing controllable player", () => {
    const players = [
        player("org.mpris.MediaPlayer2.paused"),
        player("org.mpris.MediaPlayer2.playing", { isPlaying: true }),
    ];

    assert.equal(
        MediaModel.choosePlayer(players, "org.mpris.MediaPlayer2.missing").dbusName,
        "org.mpris.MediaPlayer2.playing",
    );
});

test("selection degrades predictably when no player is playing", () => {
    const passive = player("org.mpris.MediaPlayer2.passive", { canControl: false });
    const controllable = player("org.mpris.MediaPlayer2.controllable");

    assert.equal(MediaModel.choosePlayer([passive, controllable], ""), controllable);
    assert.equal(MediaModel.choosePlayer([passive], ""), passive);
    assert.equal(MediaModel.choosePlayer([], ""), null);
});

test("display text falls back from metadata to player identity", () => {
    assert.equal(MediaModel.title({ trackTitle: " Song ", identity: "Player" }), "Song");
    assert.equal(MediaModel.title({ trackTitle: "", identity: " Player " }), "Player");
    assert.equal(MediaModel.title(null), "No media");
    assert.equal(MediaModel.artist({ trackArtist: " Artist " }), "Artist");
    assert.equal(MediaModel.artist(null), "");
});

test("duration formatting handles unknown, minute, and hour values", () => {
    assert.equal(MediaModel.duration(-1), "--:--");
    assert.equal(MediaModel.duration(65), "1:05");
    assert.equal(MediaModel.duration(3665), "1:01:05");
});

function player(dbusName, overrides = {}) {
    return {
        dbusName,
        canControl: true,
        isPlaying: false,
        ...overrides,
    };
}
