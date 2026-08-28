const sectionNames = ["left", "center", "right", "hidden"];
const essentialIds = new Set([
    "workspaces", "clock", "quickSettings", "notifications", "status", "power",
]);
const widgetSurfaceKeys = {
    media: "media",
    system: "system",
    audio: "audio",
    updates: "updates",
    clock: "calendar",
    tray: "tray",
    network: "networkQuick",
    bluetooth: "bluetoothQuick",
    quickSettings: "quickSettings",
    notifications: "notifications",
    weather: "weather",
    status: "reminderQuick",
};

function clone(layout) {
    return {
        left: (layout.left || []).slice(),
        center: (layout.center || []).slice(),
        right: (layout.right || []).slice(),
        hidden: (layout.hidden || []).slice(),
    };
}

function sectionOf(layout, id) {
    return sectionNames.find(function(section) {
        return (layout[section] || []).indexOf(id) !== -1;
    }) || "";
}

function moveTo(layout, id, targetSection, targetIndex) {
    if (sectionNames.indexOf(targetSection) === -1 || sectionOf(layout, id) === "") {
        return clone(layout);
    }
    const result = clone(layout);
    sectionNames.forEach(function(section) {
        result[section] = result[section].filter(function(candidate) { return candidate !== id; });
    });
    if (targetSection === "center" && result.center.length >= 3) {
        return clone(layout);
    }
    const index = Math.max(0, Math.min(Number(targetIndex), result[targetSection].length));
    result[targetSection].splice(index, 0, id);
    return result;
}

function moveAtDrop(layout, sourceId, targetId, after) {
    const targetSection = sectionOf(layout, targetId);
    if (sourceId === targetId || targetSection === "") return clone(layout);
    const targetIndex = layout[targetSection].indexOf(targetId) + (after ? 1 : 0);
    const sourceSection = sectionOf(layout, sourceId);
    const adjustedIndex = sourceSection === targetSection
        && layout[targetSection].indexOf(sourceId) < targetIndex
        ? targetIndex - 1 : targetIndex;
    return moveTo(layout, sourceId, targetSection, adjustedIndex);
}

function moveKeyboard(layout, id, direction) {
    const section = sectionOf(layout, id);
    if (section === "") return clone(layout);
    const index = layout[section].indexOf(id);
    if (direction === "previous-section" || direction === "next-section") {
        const sectionIndex = sectionNames.indexOf(section);
        const delta = direction === "previous-section" ? -1 : 1;
        const nextSection = sectionNames[sectionIndex + delta];
        return nextSection === undefined
            ? clone(layout) : moveTo(layout, id, nextSection, layout[nextSection].length);
    }
    const delta = direction === "previous" ? -1 : 1;
    const target = index + delta;
    if (target < 0 || target >= layout[section].length) return clone(layout);
    return moveTo(layout, id, section, target);
}

function priority(id) {
    return essentialIds.has(id) ? 100 : 10;
}

function popoverActive(activeKey, originScreen, popoverKey, screen, enabled) {
    return enabled && activeKey === popoverKey && originScreen === screen;
}

function overflowOpen(triggerActive, activeKey, originScreen, screen, overflowIds) {
    if (triggerActive) return true;
    if (originScreen !== screen) return false;
    return overflowIds.some(function(id) {
        return widgetSurfaceKeys[id] === activeKey;
    });
}

function widthFor(ids, widths, spacing) {
    if (ids.length === 0) return 0;
    return ids.reduce(function(total, id) {
        return total + Math.max(0, Number(widths[id]) || 0);
    }, 0) + spacing * (ids.length - 1);
}

// Overflow is responsive presentation state only. Returned ids retain their
// configured relative order and the input arrays are never changed.
function overflowFor(ids, widths, budget, spacing, overflowButtonWidth) {
    const configured = ids.slice();
    if (widthFor(configured, widths, spacing) <= budget) return [];

    const visible = configured.slice();
    const removals = configured.map(function(id, index) {
        return { id, index, priority: priority(id) };
    }).sort(function(left, right) {
        return left.priority - right.priority || left.index - right.index;
    });
    const target = Math.max(0, budget - overflowButtonWidth - spacing);
    for (let index = 0; index < removals.length; index += 1) {
        if (widthFor(visible, widths, spacing) <= target) break;
        if (removals[index].priority >= 100) continue;
        const removeIndex = visible.indexOf(removals[index].id);
        if (removeIndex !== -1) visible.splice(removeIndex, 1);
    }
    return configured.filter(function(id) { return visible.indexOf(id) === -1; });
}

if (typeof module !== "undefined") module.exports = {
    clone,
    sectionNames,
    sectionOf,
    moveTo,
    moveAtDrop,
    moveKeyboard,
    overflowOpen,
    popoverActive,
    overflowFor,
    priority,
    widthFor,
};
