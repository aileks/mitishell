import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

// The shell's slider control: accent fill, blue focus handle. Callers own
// the range, value binding, and onMoved handling.
Controls.Slider {
    id: root

    activeFocusOnTab: true

    // Orange for runtime controls, blue for configuration.
    property color accent: Theme.orange

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 5
        radius: 3
        color: Theme.borderStrong

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.accent
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: root.activeFocus ? Theme.blue : Theme.textBright
        border.width: 2
        border.color: Theme.layerInset
    }
}
