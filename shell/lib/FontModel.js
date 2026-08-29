// FontModel builds the Settings font picker's choice list: a default
// entry plus one entry per installed family, searchable by name. Pure
// functions so node --test can run without QML.

function standardChoices(families) {
    return withDefault(families, "System default");
}

function monoChoices(nerdFamilies) {
    return withDefault(nerdFamilies, "Default (Adwaita Mono)");
}

function filterChoices(choices, query) {
    const values = Array.isArray(choices) ? choices : [];
    const needle = String(query || "").trim().toLowerCase();
    if (needle === "") return values.slice();
    return values.filter(function(choice) {
        return choice.label.toLowerCase().indexOf(needle) >= 0;
    });
}

function withDefault(families, defaultLabel) {
    const choices = [{ value: "", label: defaultLabel }];
    const values = Array.isArray(families) ? families : [];
    for (let index = 0; index < values.length; index++) {
        choices.push({ value: values[index], label: values[index] });
    }
    return choices;
}

if (typeof module !== "undefined") {
    module.exports = { filterChoices, monoChoices, standardChoices };
}
