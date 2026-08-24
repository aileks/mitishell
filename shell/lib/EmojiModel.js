const resultLimit = 1000;
const recentLimit = 24;
const smileysCategory = "Smileys & Emotion";
const skinTonePattern = /[🏻🏼🏽🏾🏿]/u;

const categories = [
    { key: "recent", label: "Recents", icon: "󰋚" },
    { key: smileysCategory, label: "Smileys", icon: "😀" },
    { key: "People & Body", label: "People", icon: "🧑" },
    { key: "Animals & Nature", label: "Animals", icon: "🐻" },
    { key: "Food & Drink", label: "Food", icon: "🍔" },
    { key: "Travel & Places", label: "Travel", icon: "🚗" },
    { key: "Activities", label: "Activities", icon: "⚽" },
    { key: "Objects", label: "Objects", icon: "💡" },
    { key: "Symbols", label: "Symbols", icon: "🔣" },
    { key: "Flags", label: "Flags", icon: "🏳️" },
];

function parseCatalog(raw) {
    try {
        const parsed = JSON.parse(String(raw || ""));
        if (!Array.isArray(parsed)) return [];
        return parsed.filter(function(entry) {
            return entry && typeof entry.e === "string" && entry.e !== ""
                && typeof entry.k === "string" && typeof entry.c === "string"
                && !skinTonePattern.test(entry.e);
        });
    } catch (error) {
        return [];
    }
}

function normalizedQuery(query) {
    return String(query || "").trim().toLowerCase();
}

function filterCatalog(catalog, query, category, recents, limit) {
    const values = Array.isArray(catalog) ? catalog : [];
    const needle = normalizedQuery(query);
    const max = Number.isFinite(Number(limit))
        ? Math.max(0, Number(limit)) : resultLimit;
    if (max === 0) return [];

    if (needle === "" && category === "recent") {
        const byEmoji = {};
        values.forEach(function(entry) { byEmoji[entry.e] = entry; });
        return (Array.isArray(recents) ? recents : [])
            .map(function(emoji) { return byEmoji[emoji]; })
            .filter(function(entry) { return entry !== undefined; })
            .slice(0, max);
    }

    const result = [];
    for (let index = 0; index < values.length; index++) {
        const entry = values[index];
        const matches = needle !== ""
            ? entry.k.toLowerCase().indexOf(needle) >= 0
            : entry.c === category;
        if (!matches) continue;
        result.push(entry);
        if (result.length >= max) break;
    }
    return result;
}

function initialCategory(recents) {
    return Array.isArray(recents) && recents.length > 0 ? "recent" : smileysCategory;
}

function addRecent(recents, emoji) {
    const updated = [String(emoji || "")];
    (Array.isArray(recents) ? recents : []).forEach(function(entry) {
        if (entry !== emoji) updated.push(entry);
    });
    return updated.filter(function(entry) { return entry !== ""; }).slice(0, recentLimit);
}

function selectLinear(current, delta, count) {
    if (count <= 0) return 0;
    return (current + delta + count) % count;
}

function selectRow(current, delta, columns, count) {
    if (count <= 0) return 0;
    return Math.max(0, Math.min(count - 1, current + delta * Math.max(1, columns)));
}

function selectPage(current, delta, columns, visibleRows, count) {
    return selectRow(current, delta * Math.max(1, visibleRows), columns, count);
}

if (typeof module !== "undefined") {
    module.exports = {
        addRecent,
        categories,
        filterCatalog,
        initialCategory,
        normalizedQuery,
        parseCatalog,
        recentLimit,
        resultLimit,
        selectLinear,
        selectPage,
        selectRow,
        skinTonePattern,
        smileysCategory,
    };
}
