function monthGrid(year, month, firstDayOfWeek) {
    const firstOfMonth = new Date(year, month, 1, 12);
    const normalizedFirstDay = firstDayOfWeek % 7;
    const offset = (firstOfMonth.getDay() - normalizedFirstDay + 7) % 7;
    const firstCell = new Date(year, month, 1 - offset, 12);
    const result = [];

    for (let index = 0; index < 42; index += 1) {
        const date = new Date(
            firstCell.getFullYear(),
            firstCell.getMonth(),
            firstCell.getDate() + index,
            12,
        );
        result.push({
            year: date.getFullYear(),
            month: date.getMonth(),
            day: date.getDate(),
            inMonth: date.getFullYear() === year && date.getMonth() === month,
        });
    }

    return result;
}

function shiftMonth(year, month, delta) {
    const date = new Date(year, month + delta, 1, 12);
    return { year: date.getFullYear(), month: date.getMonth() };
}

function moveDate(parts, days) {
    const date = new Date(parts.year, parts.month, parts.day + days, 12);
    return {
        year: date.getFullYear(),
        month: date.getMonth(),
        day: date.getDate(),
    };
}

function sameDate(left, right) {
    return left !== null && right !== null
        && left.year === right.year
        && left.month === right.month
        && left.day === right.day;
}

if (typeof module !== "undefined") {
    module.exports = { monthGrid, shiftMonth, moveDate, sameDate };
}
