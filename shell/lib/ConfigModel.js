function outputEnabled(outputs, connector) {
    return outputs.includes("*") || outputs.includes(connector);
}

if (typeof module !== "undefined") {
    module.exports = { outputEnabled };
}
