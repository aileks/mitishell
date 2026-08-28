pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/NetworkModel.js" as NetworkModel

// Wi-Fi signal strength as ascending bars.
Row {
    id: root

    property int strength: 0

    readonly property int bars: NetworkModel.signalBars(strength)

    spacing: 2

    Repeater {
        model: 4

        delegate: Item {
            id: bar

            required property int index

            width: 3
            height: 13

            // Bars share a baseline and grow upward like a signal meter.
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 4 + bar.index * 3
                radius: 0
                color: bar.index < root.bars ? Theme.blue : Theme.overlay

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.duration(Motion.quick)
                    }
                }
            }
        }
    }
}
