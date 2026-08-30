// Small arithmetic parser for launcher queries beginning with "=".

function formatNumber(value) {
    if (!Number.isFinite(value)) return "";
    if (Object.is(value, -0)) return "0";
    return Number(value.toPrecision(12)).toString();
}

function evaluate(expression) {
    const source = String(expression || "");
    let index = 0;

    function skipSpace() {
        while (/\s/.test(source.charAt(index))) index++;
    }

    function consume(character) {
        skipSpace();
        if (source.charAt(index) !== character) return false;
        index++;
        return true;
    }

    function primary() {
        skipSpace();
        if (consume("(")) {
            const value = expressionValue();
            if (!consume(")")) throw new Error("Missing closing parenthesis");
            return value;
        }
        skipSpace();
        const start = index;
        let sawDigit = false;
        while (/\d/.test(source.charAt(index))) {
            sawDigit = true;
            index++;
        }
        if (source.charAt(index) === ".") {
            index++;
            while (/\d/.test(source.charAt(index))) {
                sawDigit = true;
                index++;
            }
        }
        if (!sawDigit) throw new Error("Expected a number");
        return Number(source.slice(start, index));
    }

    function power() {
        const base = primary();
        if (consume("^")) return Math.pow(base, unary());
        return base;
    }

    function unary() {
        if (consume("+")) return unary();
        if (consume("-")) return -unary();
        return power();
    }

    function term() {
        let value = unary();
        while (true) {
            if (consume("*")) {
                value *= unary();
            } else if (consume("/")) {
                value /= unary();
            } else if (consume("%")) {
                value %= unary();
            } else {
                return value;
            }
        }
    }

    function expressionValue() {
        let value = term();
        while (true) {
            if (consume("+")) {
                value += term();
            } else if (consume("-")) {
                value -= term();
            } else {
                return value;
            }
        }
    }

    if (source.trim() === "") return { ok: false, error: "Enter an expression" };
    try {
        const value = expressionValue();
        skipSpace();
        if (index !== source.length) throw new Error("Unexpected input");
        const text = formatNumber(value);
        if (text === "") return { ok: false, error: "Result is not finite" };
        return { ok: true, value, text };
    } catch (error) {
        return { ok: false, error: error.message || "Invalid expression" };
    }
}

function fromQuery(query) {
    const value = String(query || "");
    if (value.charAt(0) !== "=") return null;
    return evaluate(value.slice(1));
}

if (typeof module !== "undefined") {
    module.exports = { evaluate, formatNumber, fromQuery };
}
