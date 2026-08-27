const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const componentsDirectory = path.join(__dirname, "..", "shell", "components");

test("every component is registered in its QML module", () => {
    const componentFiles = fs.readdirSync(componentsDirectory)
        .filter(file => file.endsWith(".qml"))
        .sort();
    const registeredFiles = new Set(
        fs.readFileSync(path.join(componentsDirectory, "qmldir"), "utf8")
            .split("\n")
            .map(line => line.trim().split(/\s+/)[2])
            .filter(Boolean),
    );

    const missingFiles = componentFiles.filter(file => !registeredFiles.has(file));
    assert.deepEqual(missingFiles, []);
});
