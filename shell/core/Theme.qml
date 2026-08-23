pragma Singleton

import QtQuick

QtObject {
    // Accent colors map to categories: orange is the shell's identity and
    // runtime controls, blue is configuration and technical detail (plus
    // focus rings), red is destructive or failed, yellow is stale or
    // warning. Green, purple, cyan, and pink are unassigned.

    readonly property color background: "#131210"
    readonly property color container: "#1B1916"
    readonly property color surface: "#23201C"
    readonly property color overlay: "#58534C"

    readonly property color text: "#BBB3A9"
    readonly property color textBright: "#DDD5CA"
    readonly property color textMuted: "#9A938A"

    readonly property color orange: "#E17A3F"
    readonly property color green: "#879B5C"
    readonly property color red: "#B34A45"
    readonly property color yellow: "#D9A441"
    readonly property color blue: "#6785A1"
    readonly property color purple: "#9B7AA0"
    readonly property color cyan: "#6F9B99"
    readonly property color pink: "#B67B86"

    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 14
    readonly property int radiusPill: 999

    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24

    readonly property string fontSans: "Adwaita Sans"
    readonly property string fontMono: "Adwaita Mono"
    readonly property int fontSizeCaption: 12
    readonly property int fontSizeBody: 14
    readonly property int fontSizeHeading: 18
    readonly property int fontSizeDisplay: 22
}
