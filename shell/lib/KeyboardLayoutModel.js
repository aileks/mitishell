function layoutsFromOption(text) {
    try {
        const parsed = JSON.parse(text);
        return String(parsed.str || "").split(",").map(function(value) {
            return value.trim();
        }).filter(Boolean);
    } catch (error) {
        return [];
    }
}

function activeKeymap(text) {
    try {
        const keyboards = JSON.parse(text).keyboards || [];
        const active = keyboards.find(function(keyboard) { return keyboard.main; })
            || keyboards[0];
        return active ? String(active.active_keymap || "") : "";
    } catch (error) {
        return "";
    }
}

function layoutDescriptions(text) {
    const descriptions = {};
    let inLayouts = false;
    String(text || "").split("\n").forEach(function(line) {
        if (/^!\s+layout\b/.test(line)) {
            inLayouts = true;
            return;
        }
        if (inLayouts && /^!/.test(line)) {
            inLayouts = false;
            return;
        }
        if (!inLayouts) return;
        const match = line.match(/^\s*(\S+)\s+(.+?)\s*$/);
        if (match) descriptions[match[2].toLowerCase()] = match[1];
    });
    return descriptions;
}

function codeForDescription(layouts, description, descriptions) {
    const resolved = descriptions[String(description || "").toLowerCase()] || "";
    return layouts.includes(resolved) ? resolved : "";
}

function eventParts(data) {
    const comma = String(data || "").indexOf(",");
    return comma < 0 ? [] : [data.slice(0, comma), data.slice(comma + 1)];
}

if (typeof module !== "undefined") {
    module.exports = { layoutsFromOption, activeKeymap, layoutDescriptions, codeForDescription, eventParts };
}
