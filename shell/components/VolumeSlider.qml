import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"
import "../lib/AudioModel.js" as AudioModel

// The shared volume slider control: orange fill, blue focus handle, and the
// shell's 0-150 percent policy. Callers own the value binding and onMoved.
Controls.Slider {
    id: root

    from: 0
    to: AudioModel.maximumVolume
    stepSize: 0.01
    activeFocusOnTab: true

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 5
        radius: 3
        color: Theme.overlay

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.orange
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: root.activeFocus ? Theme.blue : Theme.textBright
    }
}
