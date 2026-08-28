import QtQuick
import "../core"

// The bluetooth widget: connected device count. The surrounding bar trigger
// owns activation; this only renders the state.
FocusScope {
    id: root

    property bool open: false

    readonly property int connectedCount: {
        let count = 0;
        for (let index = 0; index < Bluetooth.devices.length; index += 1) {
            if (Bluetooth.devices[index].connected) {
                count += 1;
            }
        }
        return count;
    }

    implicitWidth: content.implicitWidth + Theme.islandPadding
    implicitHeight: 24
    Accessible.name: root.connectedCount === 1
        ? "Bluetooth, 1 device connected"
        : "Bluetooth, " + root.connectedCount + " devices connected"
    Accessible.role: Accessible.Button

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            value: Icons.bluetooth
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connectedCount > 0
            text: root.connectedCount > 9 ? "9+" : String(root.connectedCount)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.open || root.activeFocus || hover.hovered
            ? Theme.hoverFill
            : "transparent"
        border.width: root.activeFocus ? 2 : (root.open ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : Theme.cyan
        z: -1
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
