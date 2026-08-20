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
        width: workspaceStrip.implicitWidth + Theme.spaceLg * 2
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.container

        WorkspaceStrip {
            id: workspaceStrip
            anchors.centerIn: parent
            screen: root.modelData
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
