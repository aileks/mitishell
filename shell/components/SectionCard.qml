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
    border.color: Theme.borderSubtle

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

            Rectangle {
                visible: root.accent !== "transparent"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 14
                radius: Theme.radiusPill
                color: root.accent
            }

            Text {
                id: sectionTitle

                anchors.left: parent.left
                anchors.leftMargin: root.accent !== "transparent" ? Theme.spaceSm : 0
                text: root.title
                color: Theme.textMuted
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
