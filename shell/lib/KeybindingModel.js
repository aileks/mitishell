const modifierBits = [
    { bit: 64, label: "SUPER" },
    { bit: 4, label: "CTRL" },
    { bit: 8, label: "ALT" },
    { bit: 1, label: "SHIFT" },
    { bit: 2, label: "CAPS" },
    { bit: 16, label: "MOD2" },
    { bit: 32, label: "MOD3" },
    { bit: 128, label: "MOD5" },
];

function modifiersForMask(maskValue) {
    let remaining = Number(maskValue || 0) >>> 0;
    const modifiers = [];
    modifierBits.forEach(function(modifier) {
        if ((remaining & modifier.bit) !== 0) {
            modifiers.push(modifier.label);
            remaining &= ~modifier.bit;
        }
    });
    if (remaining !== 0) modifiers.push("0x" + remaining.toString(16).toUpperCase());
    return modifiers;
}

function flagsFor(record) {
    const flags = [];
    if (record.mouse === true) flags.push("Mouse");
    if (record.locked === true) flags.push("Locked");
    if (record.release === true) flags.push("Release");
    if (record.repeat === true) flags.push("Repeat");
    if (record.longPress === true) flags.push("Long press");
    if (record.non_consuming === true) flags.push("Non-consuming");
    if (record.auto_consuming === true) flags.push("Auto-consuming");
    if (record.catch_all === true) flags.push("Catch all");
    if (record.submap_universal === true || record.submap_universal === "true") {
        flags.push("Universal");
    }
    return flags;
}

function bindingKey(record) {
    const key = String(record.key || "").trim();
    if (key !== "") return key;
    const keycode = Number(record.keycode || 0);
    return keycode > 0 ? "code:" + keycode : "Unknown";
}

function bindingDescription(record) {
    const description = String(record.description || "").trim();
    if (description === "Application launcher") return "Launcher";
    return description || "Undescribed binding";
}

function parseBindings(raw) {
    try {
        const parsed = JSON.parse(String(raw || ""));
        if (!Array.isArray(parsed)) return { ok: false, entries: [], error: "Invalid binding list" };
        const entries = parsed.map(function(record, index) {
            const modifiers = modifiersForMask(record.modmask);
            const key = bindingKey(record);
            const description = bindingDescription(record);
            const shortcut = modifiers.concat([key]).join(" + ");
            const submap = String(record.submap || "");
            return {
                id: "bind:" + index,
                sourceIndex: index,
                modifiers,
                key,
                shortcut,
                label: description,
                description,
                submap,
                flags: flagsFor(record),
                groupLabel: "",
            };
        });
        return { ok: true, entries, error: "" };
    } catch (error) {
        return { ok: false, entries: [], error: "Binding data could not be read" };
    }
}

function groupBindings(entries) {
    const values = Array.isArray(entries) ? entries : [];
    const names = [""];
    values.forEach(function(entry) {
        if (entry.submap !== "" && names.indexOf(entry.submap) < 0) names.push(entry.submap);
    });
    const result = [];
    names.forEach(function(name) {
        let first = true;
        values.forEach(function(entry) {
            if (entry.submap !== name) return;
            const copy = Object.assign({}, entry);
            copy.groupLabel = first ? (name === "" ? "Global" : name) : "";
            result.push(copy);
            first = false;
        });
    });
    return result;
}

if (typeof module !== "undefined") {
    module.exports = {
        bindingDescription,
        bindingKey,
        flagsFor,
        groupBindings,
        modifiersForMask,
        parseBindings,
    };
}
