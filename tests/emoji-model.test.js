const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const EmojiModel = require("../shell/lib/EmojiModel.js");

const catalog = [
    { e: "😀", k: "grinning face happy smile", c: "Smileys & Emotion" },
    { e: "😃", k: "grinning face joy", c: "Smileys & Emotion" },
    { e: "👋", k: "waving hand goodbye", c: "People & Body" },
    { e: "🐻", k: "bear animal", c: "Animals & Nature" },
];

test("catalog parsing keeps valid base entries and drops skin tones", () => {
    const parsed = EmojiModel.parseCatalog(JSON.stringify([
        catalog[0],
        { e: "🇺🇸", k: "flag: United States", c: "Flags" },
        { e: "👋🏽", k: "waving hand", c: "People & Body" },
        { e: "", k: "missing", c: "Symbols" },
        null,
    ]));
    assert.deepEqual(parsed, [
        catalog[0],
        { e: "🇺🇸", k: "flag: United States", c: "Flags" },
    ]);
    assert.deepEqual(EmojiModel.parseCatalog("not json"), []);
});

test("bundled catalog preserves every base emoji and country flag", () => {
    const source = fs.readFileSync(
        path.join(__dirname, "../shell/assets/emoji/catalog.json"),
        "utf8",
    );
    const parsed = EmojiModel.parseCatalog(source);

    assert.equal(parsed.length, 1870);
    assert.ok(parsed.filter((entry) => entry.c === "Flags").length >= 250);
    assert.ok(parsed.some((entry) => entry.e === "🇺🇸"));
});

test("blank search filters the selected category", () => {
    assert.deepEqual(
        EmojiModel.filterCatalog(catalog, "", "Smileys & Emotion", [], 1000),
        catalog.slice(0, 2),
    );
});

test("search ignores category and preserves catalog order", () => {
    assert.deepEqual(
        EmojiModel.filterCatalog(catalog, "  GRINNING ", "Animals & Nature", [], 1000),
        catalog.slice(0, 2),
    );
    assert.deepEqual(
        EmojiModel.filterCatalog(catalog, "hand", "Animals & Nature", [], 1000),
        [catalog[2]],
    );
});

test("search result limit is enforced", () => {
    assert.deepEqual(
        EmojiModel.filterCatalog(catalog, "face", "recent", [], 1),
        [catalog[0]],
    );
});

test("recents preserve their order and skip missing catalog entries", () => {
    assert.deepEqual(
        EmojiModel.filterCatalog(catalog, "", "recent", ["🐻", "missing", "😀"], 1000),
        [catalog[3], catalog[0]],
    );
});

test("initial category prefers populated recents", () => {
    assert.equal(EmojiModel.initialCategory([]), EmojiModel.smileysCategory);
    assert.equal(EmojiModel.initialCategory(["😀"]), "recent");
});

test("recent updates are unique and bounded", () => {
    const entries = Array.from({ length: 30 }, (_, index) => `emoji-${index}`);
    const updated = EmojiModel.addRecent(entries, "emoji-4");
    assert.equal(updated[0], "emoji-4");
    assert.equal(updated.length, 24);
    assert.equal(updated.filter((entry) => entry === "emoji-4").length, 1);
});

test("grid navigation wraps horizontally and clamps rows and pages", () => {
    assert.equal(EmojiModel.selectLinear(0, -1, 10), 9);
    assert.equal(EmojiModel.selectLinear(9, 1, 10), 0);
    assert.equal(EmojiModel.selectRow(2, 1, 4, 10), 6);
    assert.equal(EmojiModel.selectRow(8, 1, 4, 10), 9);
    assert.equal(EmojiModel.selectRow(1, -1, 4, 10), 0);
    assert.equal(EmojiModel.selectPage(1, 1, 4, 2, 10), 9);
});

test("category contract includes recents and all source groups", () => {
    assert.deepEqual(
        EmojiModel.categories.map((category) => category.key),
        [
            "recent", "Smileys & Emotion", "People & Body", "Animals & Nature",
            "Food & Drink", "Travel & Places", "Activities", "Objects", "Symbols", "Flags",
        ],
    );
});
