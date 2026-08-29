pragma ComponentBehavior: Bound

import QtQuick
import "../core"

Item {
    id: root

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.description: "Right click to change time format"

    // Nerd variants carry tall ascenders for icon glyphs, so center on the
    // digits' cap height instead of the font's em box; keeps every chosen
    // family visually level with the neighboring islands.
    FontMetrics {
        id: metrics

        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeBodySmall
    }

    // qmltypes miss FontMetrics.capHeight, so quiet the false positive:
    // qmllint disable missing-property
    readonly property real capOffset: Math.round(
        metrics.height / 2 - (metrics.ascent - metrics.capHeight / 2))
    // qmllint enable missing-property

    Row {
        id: content

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        spacing: Theme.spaceSm

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.capOffset
            text: Qt.formatTime(Clock.now, Clock.timeFormat)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBodySmall
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.capOffset
            visible: Config.clock.showDate
            text: Qt.formatDate(Clock.now, "MMM d")
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBodySmall
            renderType: Text.NativeRendering
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: Clock.cycleFormat()
    }
}
