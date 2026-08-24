const test = require("node:test");
const assert = require("node:assert/strict");
const model = require("../shell/lib/KeyboardLayoutModel.js");

test("layout discovery parses configured codes and main keyboard", () => {
    assert.deepEqual(model.layoutsFromOption('{"str":"us, de"}'), ["us", "de"]);
    assert.equal(model.activeKeymap('{"keyboards":[{"main":false,"active_keymap":"German"},{"main":true,"active_keymap":"English (US)"}]}'), "English (US)");
});

test("xkb descriptions resolve back to configured codes", () => {
    const rules = "! layout\n  us English (US)\n  de German\n! variant\n";
    const descriptions = model.layoutDescriptions(rules);
    assert.equal(model.codeForDescription(["us", "de"], "German", descriptions), "de");
    assert.equal(model.codeForDescription(["us"], "German", descriptions), "");
});

test("layout events preserve commas in the description", () => {
    assert.deepEqual(model.eventParts("keyboard,English (US, intl.)"), ["keyboard", "English (US, intl.)"]);
});
