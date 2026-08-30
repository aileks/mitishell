// Clipboard history rules shared by the Clipboard service and launcher rows.

const defaultLimit = 25;

function entryLimit(cap) {
    const limit = Number(cap);
    return Number.isInteger(limit) && limit > 0 ? limit : defaultLimit;
}

function removeEntry(entries, text) {
    const value = String(text || "");
    return (Array.isArray(entries) ? entries : []).filter(function(entry) {
        return entry !== value;
    });
}

function preview(text) {
    const lines = String(text || "").split(/\r?\n/);
    for (let index = 0; index < lines.length; index += 1) {
        const line = lines[index].trim();
        if (line !== "") return line;
    }
    return "";
}

if (typeof module !== "undefined") {
    module.exports = { entryLimit, preview, removeEntry };
}
