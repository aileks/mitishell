const separatorsAfter = ["system", "audio", "clock"];

function move(order, from, to) {
    const result = order.slice();
    if (from < 0 || to < 0 || from >= result.length || to >= result.length || from === to) return result;
    const moved = result.splice(from, 1)[0];
    result.splice(to, 0, moved);
    return result;
}

function moveAtDrop(order, sourceId, targetId, after) {
    if (sourceId === targetId || !order.includes(sourceId) || !order.includes(targetId))
        return order.slice();

    const result = order.filter(id => id !== sourceId);
    const targetIndex = result.indexOf(targetId);
    result.splice(targetIndex + (after ? 1 : 0), 0, sourceId);
    return result;
}

function nextVisible(order, index, visible) {
    for (let next = index + 1; next < order.length; next += 1) {
        if (visible(order[next])) return order[next];
    }
    return "";
}

function visibleTarget(order, index, direction, visible) {
    for (let next = index + direction; next >= 0 && next < order.length; next += direction) {
        if (visible(order[next])) return next;
    }
    return index;
}

function moveVisible(order, index, direction, visible) {
    return move(order, index, visibleTarget(order, index, direction, visible));
}

function separatorAfter(id, nextId) {
    if (nextId === "") return false;
    return separatorsAfter.includes(id) || nextId === "weather";
}

function render(order, visible) {
    const result = [];
    for (let index = 0; index < order.length; index += 1) {
        const id = order[index];
        if (!visible(id)) continue;
        result.push({ id, separatorAfter: separatorAfter(id, nextVisible(order, index, visible)) });
    }
    return result;
}

if (typeof module !== "undefined") module.exports = {
    move,
    moveAtDrop,
    moveVisible,
    nextVisible,
    render,
    separatorAfter,
    visibleTarget,
};
