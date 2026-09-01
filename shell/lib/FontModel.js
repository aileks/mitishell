// FontModel describes the font slots, builds searchable family choices,
// and scales text roles from each slot's body size. Pure functions so
// node --test can run without QML.

const slotDescriptors = {
    standard: {
        fieldKey: "font.family",
        title: "Standard font",
        defaultLabel: "System default",
        nerdOnly: false,
    },
    mono: {
        fieldKey: "font.monoFamily",
        title: "Monospace font",
        defaultLabel: "Default (Adwaita Mono Propo)",
        nerdOnly: true,
    },
};

// Resolves a picker slot ("standard" or "mono"). The standard descriptor
// doubles as the closed-state fallback so bindings stay null-safe.
function slotDescriptor(slot) {
    return slotDescriptors[slot] || slotDescriptors.standard;
}

function choicesFor(slot, families) {
    return withDefault(families, slotDescriptor(slot).defaultLabel);
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

function scaledSize(shippedRoleSize, bodySize) {
    return Math.round(shippedRoleSize * bodySize / 14);
}

if (typeof module !== "undefined") {
    module.exports = { choicesFor, filterChoices, scaledSize, slotDescriptor };
}
