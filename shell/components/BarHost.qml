import QtQuick
import Quickshell
import "../core"

PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    visible: Config.outputEnabled(modelData.name)
    color: "transparent"
    implicitHeight: Config.bar.height
    exclusiveZone: visible ? implicitHeight + Config.bar.marginTop : 0

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Config.bar.marginTop
        left: Config.bar.marginHorizontal
        right: Config.bar.marginHorizontal
    }

    Rectangle {
        anchors.left: parent.left
        width: Math.min(leftContent.implicitWidth + Theme.spaceLg * 2, 560)
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: leftContent

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Theme.spaceLg * 2)
            spacing: Theme.spaceMd

            WorkspaceStrip {
                id: workspaceStrip
                screen: root.modelData
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.overlay
                visible: Config.bar.showWindowTitle
            }

            WindowTitle {
                anchors.verticalCenter: parent.verticalCenter
                screen: root.modelData
                width: Math.min(implicitWidth, 280)
                visible: Config.bar.showWindowTitle
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 112
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Config.error === "" ? Theme.green : Theme.red
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 180
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container

        Text {
            anchors.centerIn: parent
            text: Config.error === "" ? "ready" : "config error"
            color: Config.error === "" ? Theme.text : Theme.red
            font.family: Theme.fontMono
            font.pixelSize: 12
        }
    }
}
