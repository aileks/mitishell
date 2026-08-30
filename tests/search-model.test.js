const test = require("node:test");
const assert = require("node:assert/strict");

const SearchModel = require("../shell/lib/SearchModel.js");

const entries = [
    { id: "app:firefox", label: "Firefox", detail: "Web Browser", keywords: ["internet"] },
    { id: "app:files", label: "Files", detail: "File Manager", keywords: ["nautilus"] },
    { id: "action:night-light", label: "Night Light", detail: "Mitishell action", keywords: ["temperature"] },
    { id: "bind:terminal", shortcut: "SUPER + RETURN", description: "Open Terminal", submap: "", flags: [] },
];

test("normalization, words, and acronyms are stable", () => {
    assert.equal(SearchModel.normalize("  Night   LIGHT "), "night light");
    assert.deepEqual(SearchModel.words("SUPER + Shift+K"), ["super", "shift", "k"]);
    assert.equal(SearchModel.acronym("Night Light Toggle"), "nlt");
});

test("exact and prefix matches rank before metadata matches", () => {
    assert.deepEqual(
        SearchModel.rank(entries, "fi").map((entry) => entry.id),
        ["app:files", "app:firefox"],
    );
    assert.equal(SearchModel.rank(entries, "web")[0].id, "app:firefox");
    assert.equal(SearchModel.rank(entries, "nl")[0].id, "action:night-light");
});

test("every query term must match", () => {
    assert.deepEqual(
        SearchModel.rank(entries, "fire web").map((entry) => entry.id),
        ["app:firefox"],
    );
    assert.deepEqual(SearchModel.rank(entries, "fire terminal"), []);
});

test("bounded typo matching is strict for short terms", () => {
    assert.equal(SearchModel.editLimit("abc"), 0);
    assert.equal(SearchModel.editLimit("firefx"), 1);
    assert.equal(SearchModel.editLimit("applicaton"), 2);
    assert.deepEqual(SearchModel.rank(entries, "fierfox").map((entry) => entry.id), ["app:firefox"]);
    assert.deepEqual(SearchModel.rank(entries, "fre"), []);
});

test("distance supports adjacent transposition and respects its bound", () => {
    assert.equal(SearchModel.boundedDistance("fierfox", "firefox", 1), 1);
    assert.equal(SearchModel.boundedDistance("browser", "browsers", 1), 1);
    assert.equal(SearchModel.boundedDistance("night", "signal", 1), 2);
});

test("keybinding fields participate in search", () => {
    assert.deepEqual(
        SearchModel.rank(entries, "super return").map((entry) => entry.id),
        ["bind:terminal"],
    );
});
