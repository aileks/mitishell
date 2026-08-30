const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "../shell/components/MediaIsland.qml"),
    "utf8",
);

test("media metadata reserves the standard horizontal island padding", () => {
    assert.match(
        source,
        /implicitWidth:\s*metadataViewport\.implicitWidth\s*\+\s*Theme\.islandPadding/,
    );
    assert.match(source, /anchors\.leftMargin:\s*Theme\.spaceSm/);
    assert.match(source, /anchors\.rightMargin:\s*Theme\.spaceSm/);
});
