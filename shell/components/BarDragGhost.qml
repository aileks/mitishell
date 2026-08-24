pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root

    required property var ghostScreen
    property bool active: false
    property url imageSource
    property point pointerGlobal: Qt.point(0, 0)
    property point pressOffset: Qt.point(0, 0)
    property size ghostSize: Qt.size(0, 0)
    property rect markerGlobalRect: Qt.rect(0, 0, 0, 0)
    property bool markerVisible: false

    readonly property point pointerLocal: contentItem.mapFromGlobal(
        pointerGlobal.x,
        pointerGlobal.y,
    )
    readonly property point markerLocal: contentItem.mapFromGlobal(
        markerGlobalRect.x,
        markerGlobalRect.y,
    )

    screen: ghostScreen
    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    WlrLayershell.namespace: "mitishell-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    SurfaceFrame {
        x: Math.round(root.pointerLocal.x - root.pressOffset.x - Theme.spaceXs)
        y: Math.round(root.pointerLocal.y - root.pressOffset.y - Theme.spaceXs)
        width: root.ghostSize.width + Theme.spaceXs * 2
        height: root.ghostSize.height + Theme.spaceXs * 2
        fill: Theme.layerRaised
        accent: Theme.orange
        cornerRadius: Theme.radiusMedium
        floating: true
        padding: Theme.spaceXs
        opacity: root.active && root.imageSource.toString() !== "" ? 0.96 : 0

        Image {
            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.Pad
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }
    }

    Rectangle {
        x: Math.round(root.markerLocal.x - width / 2)
        y: Math.round(root.markerLocal.y)
        width: 3
        height: root.markerGlobalRect.height
        radius: width / 2
        color: Theme.orange
        visible: root.active && root.markerVisible
    }
}
