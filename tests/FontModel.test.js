const test = require("node:test");
const assert = require("node:assert/strict");

const FontModel = require("../shell/lib/FontModel.js");

test("slot descriptors carry field, title, default label, and scope", () => {
    assert.deepEqual(FontModel.slotDescriptor("standard"), {
        fieldKey: "font.family",
        title: "Standard font",
        defaultLabel: "System default",
        nerdOnly: false,
    });
    assert.deepEqual(FontModel.slotDescriptor("mono"), {
        fieldKey: "font.monoFamily",
        title: "Monospace font",
        defaultLabel: "Default (Adwaita Mono Propo)",
        nerdOnly: true,
    });
    // Unknown and closed slots fall back to the standard descriptor
    // instead of handing back null.
    assert.equal(FontModel.slotDescriptor(""), FontModel.slotDescriptor("standard"));
    assert.equal(FontModel.slotDescriptor("nonsense"), FontModel.slotDescriptor("standard"));
});

test("standard choices lead with the system default", () => {
    assert.deepEqual(
        FontModel.choicesFor("standard", ["Adwaita Sans", "DejaVu Sans"]),
        [
            { value: "", label: "System default" },
            { value: "Adwaita Sans", label: "Adwaita Sans" },
            { value: "DejaVu Sans", label: "DejaVu Sans" },
        ],
    );
});

test("mono choices lead with the Adwaita Mono Propo default", () => {
    assert.deepEqual(
        FontModel.choicesFor("mono", ["AdwaitaMono Nerd Font"]),
        [
            { value: "", label: "Default (Adwaita Mono Propo)" },
            { value: "AdwaitaMono Nerd Font", label: "AdwaitaMono Nerd Font" },
        ],
    );
});

test("blank query keeps every choice in order", () => {
    const choices = FontModel.choicesFor("standard", ["Adwaita Sans", "DejaVu Sans"]);
    assert.deepEqual(FontModel.filterChoices(choices, ""), choices);
    assert.deepEqual(FontModel.filterChoices(choices, "   "), choices);
});

test("query matches family names case-insensitively", () => {
    const choices = FontModel.choicesFor("mono", [
        "AdwaitaMono Nerd Font",
        "FiraCode Nerd Font",
    ]);
    assert.deepEqual(
        FontModel.filterChoices(choices, "  fira "),
        [{ value: "FiraCode Nerd Font", label: "FiraCode Nerd Font" }],
    );
});

test("query can surface the default entry", () => {
    const choices = FontModel.choicesFor("mono", ["FiraCode Nerd Font"]);
    assert.deepEqual(
        FontModel.filterChoices(choices, "default"),
        [{ value: "", label: "Default (Adwaita Mono Propo)" }],
    );
});

test("font roles scale proportionally from the body size", () => {
    const shippedSizes = [12, 13, 14, 16, 18, 22];
    assert.deepEqual(
        shippedSizes.map((size) => FontModel.scaledSize(size, 10)),
        [9, 9, 10, 11, 13, 16],
    );
    assert.deepEqual(
        shippedSizes.map((size) => FontModel.scaledSize(size, 14)),
        shippedSizes,
    );
    assert.deepEqual(
        shippedSizes.map((size) => FontModel.scaledSize(size, 20)),
        [17, 19, 20, 23, 26, 31],
    );
});
