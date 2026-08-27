function outputEnabled(outputs, connector) {
    return outputs.includes("*") || outputs.includes(connector);
}

// Connectors that should host a bar right now. A wildcard maps to every
// live screen; a connector list intersects with the live screens, and when
// none of the configured connectors exist anymore the first live screen
// keeps the shell usable instead of every bar dying with a renamed or
// unplugged output.
function barTargets(outputs, screenNames) {
    if (outputs.indexOf("*") !== -1) {
        return screenNames.slice();
    }
    const live = screenNames.filter(function(name) {
        return outputs.indexOf(name) !== -1;
    });
    if (live.length > 0) {
        return live;
    }
    if (screenNames.length === 0) {
        return [];
    }
    const sorted = screenNames.slice().sort();
    return [sorted[0]];
}

if (typeof module !== "undefined") {
    module.exports = { outputEnabled, barTargets };
}
