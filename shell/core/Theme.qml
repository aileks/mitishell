pragma Singleton

import QtQuick
import "../lib/FontModel.js" as FontModel

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

    // Horizontal padding inside a bar widget, on both sides of its content.
    readonly property int islandPadding: spaceSm * 2

    readonly property int controlHeightSm: 28
    readonly property int controlHeight: 36
    readonly property int controlHeightLg: 44
    readonly property int iconSm: 16
    readonly property int iconMd: 20
    readonly property int iconLg: 28
    readonly property int barIconSize: Math.max(
        12,
        Math.min(iconLg, Math.round(Config.bar.height * 4 / 9)),
    )
    readonly property int floatingOffset: 5

    // The standard slot follows the system UI font until a family is
    // chosen. The mono slot keeps the shipped AdwaitaMono Nerd Font Propo:
    // its proportional Nerd glyphs suit UI text and data alike.
    readonly property string monoDefault: "AdwaitaMono Nerd Font Propo"
    // qmltypes miss the Qt Quick Application.font extension, so quiet the
    // false positive:
    // qmllint disable missing-property
    readonly property string systemFont: Qt.application.font.family
    // qmllint enable missing-property
    readonly property string fontSans: Config.font.family !== ""
        ? Config.font.family : systemFont
    readonly property string fontMono: Config.font.monoFamily !== ""
        ? Config.font.monoFamily : monoDefault
    readonly property int fontSizeCaption: FontModel.scaledSize(12, Config.font.size)
    readonly property int fontSizeBodySmall: FontModel.scaledSize(13, Config.font.size)
    readonly property int fontSizeBody: FontModel.scaledSize(14, Config.font.size)
    readonly property int fontSizeTitle: FontModel.scaledSize(16, Config.font.size)
    readonly property int fontSizeHeading: FontModel.scaledSize(18, Config.font.size)
    readonly property int fontSizeDisplay: FontModel.scaledSize(22, Config.font.size)

    readonly property int fontSizeMonoCaption: FontModel.scaledSize(12, Config.font.monoSize)
    readonly property int fontSizeMonoBodySmall: FontModel.scaledSize(13, Config.font.monoSize)
    readonly property int fontSizeMonoBody: FontModel.scaledSize(14, Config.font.monoSize)
    readonly property int fontSizeMonoTitle: FontModel.scaledSize(16, Config.font.monoSize)
    readonly property int fontSizeMonoHeading: FontModel.scaledSize(18, Config.font.monoSize)
    readonly property int fontSizeMonoDisplay: FontModel.scaledSize(22, Config.font.monoSize)

    function alpha(colorValue, opacity) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, opacity);
    }
}
