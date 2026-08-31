// Clipboard history rules shared by the Clipboard service and launcher rows.

function removeEntry(entries, id) {
    const value = String(id || "");
    return (Array.isArray(entries) ? entries : []).filter(function(entry) {
        return String(entry.id || "") !== value;
    });
}

function preview(entry) {
    if (!entry || entry.kind === "image") return "Image";
    const lines = String(entry.text || "").split(/\r?\n/);
    for (let index = 0; index < lines.length; index += 1) {
        const line = lines[index].trim();
        if (line !== "") return line;
    }
    return "";
}

function detail(entry) {
    if (!entry || entry.kind !== "image") return "Copy";
    const dimensions = Number(entry.width || 0) > 0 && Number(entry.height || 0) > 0
        ? entry.width + " × " + entry.height + " " : "";
    const format = String(entry.mimeType || "image").replace("image/", "").toUpperCase();
    return dimensions + format;
}

function keywords(entry) {
    if (!entry) return [];
    if (entry.kind === "image") {
        return ["image", String(entry.mimeType || ""), detail(entry)];
    }
    return [String(entry.text || "")];
}

if (typeof module !== "undefined") {
    module.exports = { detail, keywords, preview, removeEntry };
}
