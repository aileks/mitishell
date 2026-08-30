const test = require("node:test");
const assert = require("node:assert/strict");

const Calculator = require("../shell/lib/Calculator.js");

test("calculator applies arithmetic precedence and parentheses", () => {
    assert.equal(Calculator.evaluate("2 + 3 * 4").text, "14");
    assert.equal(Calculator.evaluate("(2 + 3) * 4").text, "20");
    assert.equal(Calculator.evaluate("10 % 4").text, "2");
});

test("powers are right associative and accept unary exponents", () => {
    assert.equal(Calculator.evaluate("2^3^2").text, "512");
    assert.equal(Calculator.evaluate("2^-2").text, "0.25");
    assert.equal(Calculator.evaluate("-2^2").text, "-4");
});

test("decimal artifacts are formatted to twelve significant digits", () => {
    assert.equal(Calculator.evaluate("0.1 + 0.2").text, "0.3");
    assert.equal(Calculator.formatNumber(1 / 3), "0.333333333333");
});

test("launcher calculator requires an equals prefix", () => {
    assert.equal(Calculator.fromQuery("2+2"), null);
    assert.equal(Calculator.fromQuery("=2+2").text, "4");
});

test("malformed and non-finite expressions are rejected", () => {
    for (const expression of ["", "2 +", "(2+3", "2 nope", "1/0", "0%0"]) {
        assert.equal(Calculator.evaluate(expression).ok, false, expression);
    }
});
