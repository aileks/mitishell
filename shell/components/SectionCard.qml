import QtQuick
import "../core"

// Tonal content group used inside popovers and centered surfaces.
Rectangle {
    id: root

    property string title: ""
    property color accent: "transparent"
    property int padding: Theme.spaceMd
    default property alias content: body.data

    implicitHeight: column.implicitHeight + padding * 2
    radius: Theme.radiusMedium
    color: Theme.layerRaised
    border.width: 1
    border.color: root.accent.a > 0 ? Theme.alpha(root.accent, 0.38) : Theme.borderSubtle

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Theme.spaceSm

        Item {
            visible: root.title !== ""
            width: parent.width
            implicitHeight: sectionTitle.implicitHeight

            Text {
                id: sectionTitle

                anchors.left: parent.left
                text: root.title
                color: root.accent.a > 0 ? root.accent : Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }
        }

        Column {
            id: body

            width: parent.width
            spacing: Theme.spaceSm
        }
    }
}
