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

function visibleTarget(order, index, direction, visible) {
    for (let next = index + direction; next >= 0 && next < order.length; next += direction) {
        if (visible(order[next])) return next;
    }
    return index;
}

function moveVisible(order, index, direction, visible) {
    return move(order, index, visibleTarget(order, index, direction, visible));
}

if (typeof module !== "undefined") module.exports = {
    move,
    moveAtDrop,
    moveVisible,
    visibleTarget,
};
