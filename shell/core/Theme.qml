pragma Singleton

import QtQuick

QtObject {
    // Cinder Grove's palette is fixed. Surfaces derive depth through these
    // roles and alpha variants instead of introducing more colors.

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

    readonly property color layerBase: background
    readonly property color layerRaised: container
    readonly property color layerInset: surface
    // Subtle borders separate decorative layers. Strong borders identify
    // controls and other meaningful UI edges at WCAG's 3:1 threshold.
    readonly property color borderSubtle: alpha(overlay, 0.48)
    readonly property color borderStrong: alpha(textMuted, 0.68)
    readonly property color scrim: alpha(background, 0.72)
    readonly property color shadow: alpha(background, 0.78)
    readonly property color hoverFill: alpha(overlay, 0.42)
    readonly property color pressedFill: alpha(overlay, 0.68)

    readonly property int radiusSmall: 0
    readonly property int radiusMedium: 0
    readonly property int radiusLarge: 0
    readonly property int radiusPill: 0

    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24

    readonly property int controlHeightSm: 28
    readonly property int controlHeight: 36
    readonly property int controlHeightLg: 44
    readonly property int iconSm: 16
    readonly property int iconMd: 20
    readonly property int iconLg: 28
    readonly property int floatingOffset: 5

    readonly property string fontSans: "Adwaita Sans"
    readonly property string fontMono: "Adwaita Mono"
    readonly property int fontSizeCaption: 12
    readonly property int fontSizeBodySmall: 13
    readonly property int fontSizeBody: 14
    readonly property int fontSizeTitle: 16
    readonly property int fontSizeHeading: 18
    readonly property int fontSizeDisplay: 22

    function alpha(colorValue, opacity) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, opacity);
    }
}
