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
        x: Theme.floatingOffset
        y: Theme.floatingOffset
        width: root.width
        height: root.height
        radius: root.cornerRadius
        color: Theme.shadow
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: root.cornerRadius
        color: root.fill
        border.width: 1
        border.color: root.accent.a > 0 ? Theme.alpha(root.accent, 0.45) : root.outline
        clip: true

        Item {
            id: content

            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
