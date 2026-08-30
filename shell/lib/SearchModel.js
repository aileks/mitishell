// Shared deterministic search ranking for launcher and keybinding rows.

function normalize(value) {
    return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function words(value) {
    return normalize(value).split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}

function acronym(value) {
    return words(value).map(function(word) { return word.charAt(0); }).join("");
}

function itemFields(item) {
    const keywordValues = Array.isArray(item.keywords) ? item.keywords : [];
    const flagValues = Array.isArray(item.flags) ? item.flags : [];
    return [
        item.label,
        item.shortcut,
        item.description,
        item.detail,
        item.id,
        item.submap,
    ].concat(keywordValues, flagValues)
        .map(normalize)
        .filter(Boolean);
}

function editLimit(token) {
    if (token.length <= 3) return 0;
    return token.length <= 7 ? 1 : 2;
}

function boundedDistance(left, right, limit) {
    if (Math.abs(left.length - right.length) > limit) return limit + 1;
    if (left === right) return 0;
    const previousPrevious = [];
    let previous = [];
    for (let column = 0; column <= right.length; column++) previous[column] = column;

    for (let row = 1; row <= left.length; row++) {
        const current = [row];
        let rowMinimum = current[0];
        for (let column = 1; column <= right.length; column++) {
            const substitution = previous[column - 1]
                + (left.charAt(row - 1) === right.charAt(column - 1) ? 0 : 1);
            let value = Math.min(
                previous[column] + 1,
                current[column - 1] + 1,
                substitution,
            );
            if (row > 1 && column > 1
                    && left.charAt(row - 1) === right.charAt(column - 2)
                    && left.charAt(row - 2) === right.charAt(column - 1)) {
                value = Math.min(value, previousPrevious[column - 2] + 1);
            }
            current[column] = value;
            rowMinimum = Math.min(rowMinimum, value);
        }
        if (rowMinimum > limit) return limit + 1;
        previousPrevious.splice(0, previousPrevious.length);
        for (let index = 0; index < previous.length; index++) {
            previousPrevious[index] = previous[index];
        }
        previous = current;
    }
    return previous[right.length];
}

function tokenScore(item, token) {
    const label = normalize(item.label || item.description || item.shortcut);
    const fields = itemFields(item);
    if (label === token) return 0;
    if (label.indexOf(token) === 0) return 10 + label.length - token.length;

    const labelWords = words(label);
    if (labelWords.some(function(word) { return word.indexOf(token) === 0; })) return 30;
    if (label.indexOf(token) >= 0) return 50;
    if (acronym(label).indexOf(token) === 0) return 60;

    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
        const field = fields[fieldIndex];
        if (field === token) return 70 + fieldIndex;
        if (field.indexOf(token) === 0) return 80 + fieldIndex;
        if (words(field).some(function(word) { return word.indexOf(token) === 0; })) {
            return 100 + fieldIndex;
        }
        if (field.indexOf(token) >= 0) return 120 + fieldIndex;
        if (acronym(field).indexOf(token) === 0) return 140 + fieldIndex;
    }

    const limit = editLimit(token);
    if (limit === 0) return -1;
    let best = limit + 1;
    fields.forEach(function(field) {
        words(field).forEach(function(word) {
            best = Math.min(best, boundedDistance(token, word, limit));
        });
    });
    return best <= limit ? 200 + best * 20 : -1;
}

function compareText(left, right) {
    const a = normalize(left);
    const b = normalize(right);
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

function rank(items, query) {
    const values = Array.isArray(items) ? items : [];
    const tokens = words(query);
    if (tokens.length === 0) return values.slice();

    const matches = [];
    values.forEach(function(item, index) {
        let score = 0;
        for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            const part = tokenScore(item, tokens[tokenIndex]);
            if (part < 0) return;
            score += part;
        }
        matches.push({ item, score, index });
    });
    matches.sort(function(left, right) {
        if (left.score !== right.score) return left.score - right.score;
        const labelOrder = compareText(
            left.item.label || left.item.description || left.item.shortcut,
            right.item.label || right.item.description || right.item.shortcut,
        );
        if (labelOrder !== 0) return labelOrder;
        const idOrder = compareText(left.item.id, right.item.id);
        return idOrder !== 0 ? idOrder : left.index - right.index;
    });
    return matches.map(function(match) { return match.item; });
}

if (typeof module !== "undefined") {
    module.exports = {
        acronym,
        boundedDistance,
        editLimit,
        normalize,
        rank,
        words,
    };
}
