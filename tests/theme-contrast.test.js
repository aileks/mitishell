const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const themePath = path.join(__dirname, "../shell/core/Theme.qml");
const themeSource = fs.readFileSync(themePath, "utf8");

const declarations = new Map(
    [...themeSource.matchAll(/readonly property color (\w+): ([^\n]+)/g)]
        .map((match) => [match[1], match[2].trim()]),
);

function parseHex(hex) {
    const channels = hex.match(/[0-9a-f]{2}/gi);
    assert.equal(channels?.length, 3, `invalid theme color ${hex}`);
    return channels.map((channel) => Number.parseInt(channel, 16) / 255).concat(1);
}

function resolveColor(name, resolving = new Set()) {
    assert.ok(!resolving.has(name), `cyclic theme color ${name}`);
    const expression = declarations.get(name);
    assert.ok(expression, `missing theme color ${name}`);

    const nextResolving = new Set(resolving).add(name);
    const literal = expression.match(/^"(#[0-9a-f]{6})"$/i);
    if (literal) {
        return parseHex(literal[1]);
    }

    const alpha = expression.match(/^alpha\((\w+), ([01](?:\.\d+)?)\)$/);
    if (alpha) {
        const color = resolveColor(alpha[1], nextResolving);
        return [...color.slice(0, 3), Number.parseFloat(alpha[2])];
    }

    if (/^\w+$/.test(expression)) {
        return resolveColor(expression, nextResolving);
    }

    assert.fail(`unsupported theme color expression for ${name}: ${expression}`);
}

function composite(foreground, background) {
    const alpha = foreground[3];
    return foreground.slice(0, 3).map((channel, index) =>
        channel * alpha + background[index] * (1 - alpha));
}

function relativeLuminance(color) {
    const linear = color.slice(0, 3).map((channel) => channel <= 0.04045
        ? channel / 12.92
        : ((channel + 0.055) / 1.055) ** 2.4);
    return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}

function contrast(foregroundName, backgroundName) {
    const background = resolveColor(backgroundName);
    const foreground = composite(resolveColor(foregroundName), background);
    const luminances = [relativeLuminance(foreground), relativeLuminance(background)]
        .sort((left, right) => right - left);
    return (luminances[0] + 0.05) / (luminances[1] + 0.05);
}

function assertPairs(foregrounds, backgrounds, minimum) {
    for (const foreground of foregrounds) {
        for (const background of backgrounds) {
            assert.ok(
                contrast(foreground, background) >= minimum,
                `${foreground} on ${background} must be at least ${minimum}:1`,
            );
        }
    }
}

const surfaces = ["background", "container", "surface"];

test("theme text roles meet WCAG AA on every surface", () => {
    assertPairs(["text", "textBright", "textMuted"], surfaces, 4.5);
});

test("body-safe accents meet WCAG AA on every surface", () => {
    assertPairs(["orange", "green", "yellow", "cyan", "pink"], surfaces, 4.5);
});

test("semantic accents meet the UI edge threshold on every surface", () => {
    assertPairs(
        ["orange", "green", "red", "yellow", "blue", "purple", "cyan", "pink"],
        surfaces,
        3,
    );
});

test("strong borders meet the UI edge threshold on every surface", () => {
    assertPairs(["borderStrong"], surfaces, 3);
});
