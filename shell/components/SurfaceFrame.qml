import QtQuick
import "../core"

// Shared shell surface. Floating frames receive a restrained tonal shadow;
// callers still own geometry and content.
Item {
    id: root

    property color fill: Theme.layerInset
    property color outline: Theme.borderSubtle
    property color accent: "transparent"
    property int cornerRadius: Theme.radiusLarge
    property bool floating: false
    property int padding: Theme.spaceLg
    property alias contentItem: content
    default property alias content: content.data

    Rectangle {
        visible: root.floating
        anchors.fill: frame
        anchors.topMargin: Theme.floatingOffset
        radius: root.cornerRadius
        color: Theme.shadow
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: root.cornerRadius
        color: root.fill
        border.width: 1
        border.color: root.outline
        clip: true

        Rectangle {
            visible: root.accent !== "transparent"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: root.accent
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
