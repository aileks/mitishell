import QtQuick
import "../core"

// The bluetooth island: connected device count. The surrounding bar trigger
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

    implicitWidth: content.implicitWidth + Theme.spaceSm * 2
    implicitHeight: 24
    Accessible.name: root.connectedCount === 1
        ? "Bluetooth, 1 device connected"
        : "Bluetooth, " + root.connectedCount + " devices connected"
    Accessible.role: Accessible.Button

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "../assets/icons/bluetooth.svg"
            // Raster at twice the drawn size; the filtered downscale keeps
            // the glyph crisp at bar scale.
            sourceSize.width: 32
            sourceSize.height: 32
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
