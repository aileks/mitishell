const test = require("node:test");
const assert = require("node:assert/strict");

const FontModel = require("../shell/lib/FontModel.js");

test("standard choices lead with the system default", () => {
    assert.deepEqual(
        FontModel.standardChoices(["Adwaita Sans", "DejaVu Sans"]),
        [
            { value: "", label: "System default" },
            { value: "Adwaita Sans", label: "Adwaita Sans" },
            { value: "DejaVu Sans", label: "DejaVu Sans" },
        ],
    );
});

test("mono choices lead with the Adwaita Mono default", () => {
    assert.deepEqual(
        FontModel.monoChoices(["AdwaitaMono Nerd Font"]),
        [
            { value: "", label: "Default (Adwaita Mono)" },
            { value: "AdwaitaMono Nerd Font", label: "AdwaitaMono Nerd Font" },
        ],
    );
});

test("blank query keeps every choice in order", () => {
    const choices = FontModel.standardChoices(["Adwaita Sans", "DejaVu Sans"]);
    assert.deepEqual(FontModel.filterChoices(choices, ""), choices);
    assert.deepEqual(FontModel.filterChoices(choices, "   "), choices);
});

test("query matches family names case-insensitively", () => {
    const choices = FontModel.monoChoices([
        "AdwaitaMono Nerd Font",
        "FiraCode Nerd Font",
    ]);
    assert.deepEqual(
        FontModel.filterChoices(choices, "  fira "),
        [{ value: "FiraCode Nerd Font", label: "FiraCode Nerd Font" }],
    );
});

test("query can surface the default entry", () => {
    const choices = FontModel.monoChoices(["FiraCode Nerd Font"]);
    assert.deepEqual(
        FontModel.filterChoices(choices, "default"),
        [{ value: "", label: "Default (Adwaita Mono)" }],
    );
});
