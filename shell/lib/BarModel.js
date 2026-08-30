const sectionNames = ["left", "center", "right", "hidden"];
const essentialIds = new Set([
    "workspaces", "clock", "quickSettings", "notifications", "status", "power",
]);
// Raw Qt key codes so node tests can check them without Qt.
const keyDirections = {
    0x01000012: "previous",         // Qt.Key_Left
    0x01000013: "next",             // Qt.Key_Right
    0x01000014: "previous-section", // Qt.Key_Up
    0x01000015: "next-section",     // Qt.Key_Down
};
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

function moveDirection(key) {
    return keyDirections[key] || "";
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

function essentialWidthFor(ids, widths, spacing, overflowButtonWidth) {
    const essentials = ids.filter(function(id) { return priority(id) >= 100; });
    const base = widthFor(essentials, widths, spacing);
    // Once low-priority widgets hide, the overflow button joins the row.
    return essentials.length === ids.length ? base : base + spacing + overflowButtonWidth;
}

// Left and right rows share the space beside the center row. A crowded side
// may use the other side's unused space, but never past that side's
// essential widgets, so overflow hides low-priority widgets instead of
// letting rows overlap.
function overflowBudgets(leftIds, rightIds, widths, totalSides, spacing, overflowButtonWidth) {
    const share = totalSides / 2;
    const leftNeed = widthFor(leftIds, widths, spacing);
    const rightNeed = widthFor(rightIds, widths, spacing);
    const leftFloor = essentialWidthFor(leftIds, widths, spacing, overflowButtonWidth);
    const rightFloor = essentialWidthFor(rightIds, widths, spacing, overflowButtonWidth);
    if (leftFloor + rightFloor > totalSides) {
        // Essentials alone overfill the bar; overlap is unavoidable, so keep
        // the even split rather than hide essential access.
        return { left: share, right: share };
    }
    if (leftNeed > share && rightNeed > share) {
        return { left: share, right: share };
    }
    const left = Math.min(Math.max(share, leftNeed), totalSides - rightFloor);
    const right = Math.min(Math.max(share, rightNeed), totalSides - left);
    return { left, right };
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

// Picks the drop target pill under a pointer. Only rects whose vertical
// band contains y are considered; the nearest center wins and after is
// true when the pointer sits in the right half. Returns null for gaps.
function dropTargetAt(rects, x, y) {
    let best = null;
    let bestDistance = Number.POSITIVE_INFINITY;
    (Array.isArray(rects) ? rects : []).forEach(function(rect) {
        if (!rect || rect.height <= 0 || rect.width <= 0) return;
        const centerY = rect.y + rect.height / 2;
        if (Math.abs(y - centerY) > rect.height / 2) return;
        const centerX = rect.x + rect.width / 2;
        const distance = Math.abs(x - centerX);
        if (distance < bestDistance) {
            bestDistance = distance;
            best = { id: rect.id, after: x >= centerX };
        }
    });
    return best;
}

if (typeof module !== "undefined") module.exports = {
    clone,
    sectionNames,
    sectionOf,
    moveTo,
    moveAtDrop,
    moveKeyboard,
    moveDirection,
    dropTargetAt,
    overflowOpen,
    popoverActive,
    overflowFor,
    overflowBudgets,
    priority,
    widthFor,
};
