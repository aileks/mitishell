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

test("duplicate instances are one logical player represented by recent activity", () => {
    const stale = player("org.mpris.MediaPlayer2.firefox.old", {
        desktopEntry: "zen-twilight",
        identity: "Mozilla zen-twilight",
        isPlaying: true,
        trackTitle: "Old stream",
    });
    const current = player("org.mpris.MediaPlayer2.firefox.current", {
        desktopEntry: "zen-twilight",
        identity: "Mozilla zen-twilight",
        isPlaying: true,
        trackTitle: "Current stream",
    });

    const choices = MediaModel.logicalPlayers(
        [stale, current],
        {
            [stale.dbusName]: 4,
            [current.dbusName]: 9,
        },
    );

    assert.equal(choices.length, 1);
    assert.equal(choices[0], current);
});

test("logical selection follows a replacement dbus instance", () => {
    const original = player("org.mpris.MediaPlayer2.firefox.old", {
        desktopEntry: "zen-twilight",
        identity: "Mozilla zen-twilight",
        isPlaying: true,
    });
    const replacement = player("org.mpris.MediaPlayer2.firefox.current", {
        desktopEntry: "zen-twilight",
        identity: "Mozilla zen-twilight",
        isPlaying: true,
    });
    const preferredKey = MediaModel.playerKey(original);

    assert.equal(
        MediaModel.choosePlayer(MediaModel.logicalPlayers([original], {}), preferredKey),
        original,
    );
    assert.equal(
        MediaModel.choosePlayer(MediaModel.logicalPlayers([replacement], {}), preferredKey),
        replacement,
    );
});

test("different player identities remain separate choices", () => {
    const firefox = player("org.mpris.MediaPlayer2.firefox", {
        desktopEntry: "zen-twilight",
        identity: "Mozilla zen-twilight",
    });
    const music = player("org.mpris.MediaPlayer2.music", {
        desktopEntry: "org.gnome.Music",
        identity: "Music",
    });

    assert.deepEqual(MediaModel.logicalPlayers([firefox, music], {}), [firefox, music]);
});

test("display text falls back from metadata to player identity", () => {
    assert.equal(MediaModel.title({ trackTitle: " Song ", identity: "Player" }), "Song");
    assert.equal(MediaModel.title({ trackTitle: "", identity: " Player " }), "Player");
    assert.equal(MediaModel.title(null), "No media");
    assert.equal(MediaModel.artist({ trackArtist: " Artist " }), "Artist");
    assert.equal(MediaModel.artist(null), "");
});

test("media is meaningful only when track metadata is present", () => {
    assert.equal(MediaModel.hasMetadata({ trackTitle: "Song", trackArtist: "" }), true);
    assert.equal(MediaModel.hasMetadata({ trackTitle: "", trackArtist: "Artist" }), true);
    assert.equal(MediaModel.hasMetadata({ trackTitle: "", trackArtist: "" }), false);
    assert.equal(MediaModel.hasMetadata(null), false);
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
