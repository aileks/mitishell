// Clipboard history rules shared by the Clipboard service and launcher rows.

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
    module.exports = { preview, removeEntry };
}
