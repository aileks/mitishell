pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../lib/BarModel.js" as BarModel

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData
    property var localOrder: Config.bar.islands.slice()
    property string dragSourceId: ""
    property string dragTargetId: ""
    property bool dragAfter: false
    property point dragPointerGlobal: Qt.point(0, 0)
    property point dragPressOffset: Qt.point(0, 0)
    property size dragGhostSize: Qt.size(0, 0)
    property url dragImageSource
    property rect dragMarkerGlobalRect: Qt.rect(0, 0, 0, 0)
    property bool dragDropValid: false
    readonly property bool dragging: dragSourceId !== ""
    readonly property real availableCenterWidth: Math.max(0, 2 * Math.min(
        width / 2 - leftIsland.width - Theme.spaceLg,
        width / 2 - rightIsland.width - Theme.spaceLg,
    ))

    function islandVisible(id) {
        return id === "system" ? Config.bar.systemMetrics !== "hidden"
            : id === "keyboardLayout" ? KeyboardLayout.available
            : id === "updates" ? Updates.visible
            : id === "tray" ? Tray.available
            : id === "reminders" ? Reminders.count > 0
            : id === "bluetooth" ? Bluetooth.state === "ready"
            : id === "weather" ? Weather.visible : true;
    }

    function beginDrag(islandDelegate, pressScenePosition, scenePosition) {
        const visual = islandDelegate.dragVisual;
        if (visual === null) return;

        dragSourceId = islandDelegate.modelData;
        dragPressOffset = visual.mapFromItem(null, pressScenePosition);
        dragGhostSize = Qt.size(Math.ceil(visual.width), Math.ceil(visual.height));
        SurfaceCoordinator.close();
        updateDrag(scenePosition);

        const sourceId = dragSourceId;
        visual.grabToImage(function(result) {
            if (root.dragSourceId === sourceId) root.dragImageSource = result.url;
        }, dragGhostSize);
    }

    function updateDrag(scenePosition) {
        if (!dragging) return;
        dragPointerGlobal = contentItem.mapToGlobal(scenePosition.x, scenePosition.y);

        const rowPosition = rightContent.mapFromItem(null, scenePosition);
        if (rowPosition.x < 0 || rowPosition.x > rightContent.width
                || rowPosition.y < 0 || rowPosition.y > rightContent.height) {
            dragTargetId = "";
            dragDropValid = false;
            return;
        }

        let target = null;
        let targetId = "";
        let after = false;
        for (let index = 0; index < localOrder.length; index += 1) {
            const candidate = rightRepeater.itemAt(index);
            if (candidate === null || !candidate.visible || candidate.width <= 0) continue;
            target = candidate;
            targetId = localOrder[index];
            after = rowPosition.x >= candidate.x + candidate.width / 2;
            if (!after) break;
        }

        if (target === null) {
            dragTargetId = "";
            dragDropValid = false;
            return;
        }

        dragTargetId = targetId;
        dragAfter = after;
        const marker = target.mapToGlobal(after ? target.width : 0, 0);
        dragMarkerGlobalRect = Qt.rect(marker.x, marker.y, 3, target.height);
        dragDropValid = true;
    }

    function finishDrag(scenePosition) {
        updateDrag(scenePosition);
        if (dragDropValid) {
            const moved = BarModel.moveAtDrop(
                localOrder,
                dragSourceId,
                dragTargetId,
                dragAfter,
            );
            if (JSON.stringify(moved) !== JSON.stringify(localOrder)) {
                localOrder = moved;
                Settings.setField("bar.islands", JSON.stringify(localOrder));
            }
        }
        clearDrag();
    }

    function clearDrag() {
        dragSourceId = "";
        dragTargetId = "";
        dragAfter = false;
        dragDropValid = false;
        dragImageSource = "";
        dragGhostSize = Qt.size(0, 0);
    }

    function moveKeyboard(index, delta) {
        const moved = BarModel.moveVisible(localOrder, index, delta, islandVisible);
        if (JSON.stringify(moved) === JSON.stringify(localOrder)) return;
        localOrder = moved;
        Settings.setField("bar.islands", JSON.stringify(localOrder));
    }

    screen: modelData
    visible: modelData !== null && Config.outputEnabled(modelData.name)
    color: "transparent"
    implicitHeight: Config.bar.height
    exclusiveZone: visible ? implicitHeight : 0

    anchors {
        top: true
        left: true
        right: true
    }
    // QuickShell's generated PanelWindow metadata does not resolve the
    // margins group even though the runtime API exposes it.
    // qmllint disable unqualified unresolved-type
    margins.top: Config.bar.marginTop
    margins.left: Config.bar.marginHorizontal
    margins.right: Config.bar.marginHorizontal
    // qmllint enable unqualified unresolved-type

    NotificationMediaCache {
        screen: root.modelData
    }

    BarDragGhost {
        ghostScreen: root.modelData
        active: root.dragging
        imageSource: root.dragImageSource
        pointerGlobal: root.dragPointerGlobal
        pressOffset: root.dragPressOffset
        ghostSize: root.dragGhostSize
        markerGlobalRect: root.dragMarkerGlobalRect
        markerVisible: root.dragDropValid
    }

    Rectangle {
        id: leftIsland

        anchors.left: parent.left
        width: Math.min(Math.ceil(leftContent.implicitWidth) + Theme.spaceLg * 2, 560)
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Motion.easingStandard
            }
        }

        Row {
            id: leftContent

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceLg
            anchors.verticalCenter: parent.verticalCenter
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
        id: centerIsland

        anchors.horizontalCenter: parent.horizontalCenter
        width: visible ? Math.min(
            272,
            root.availableCenterWidth,
            Math.ceil(mediaTrigger.implicitWidth) + Theme.spaceMd * 2,
        ) : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.alpha(Theme.purple, 0.42)
        visible: Config.bar.showMedia && Media.meaningful
            && root.availableCenterWidth > 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Motion.duration(Motion.normal)
                easing.type: Motion.easingStandard
            }
        }

        BarPopoverTrigger {
            id: mediaTrigger

            // Whole-pixel placement: a half-pixel offset from centering
            // softens every glyph and icon in the row.
            x: Math.round((parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - Theme.spaceMd * 2)
            implicitWidth: mediaContent.implicitWidth
            clip: true
            popoverKey: "media"
            screen: root.modelData

            MediaIsland {
                id: mediaContent
                width: mediaTrigger.width
            }
        }

        AnchoredPopover {
            anchorItem: mediaTrigger
            open: mediaTrigger.active && Config.bar.showMedia && Media.meaningful
            contentWidth: 360
            contentHeight: Media.players.length > 1 ? 300 : 236

            MediaPopover {
                anchors.fill: parent
            }
        }
    }

    Rectangle {
        id: rightIsland

        anchors.right: parent.right
        width: rightContent.implicitWidth > 0
            ? Math.ceil(rightContent.implicitWidth) + Theme.spaceLg * 2 : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle
        visible: width > 0

        Row {
            id: rightContent

            // Whole-pixel placement: a half-pixel offset from centering
            // softens every glyph and icon in the row.
            x: Math.round((parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Theme.spaceXs

            Repeater {
                id: rightRepeater
                model: root.localOrder

                delegate: Item {
                    id: islandDelegate
                    required property string modelData
                    required property int index
                    readonly property var dragVisual: island.dragVisual

                    width: island.implicitWidth
                    height: rightContent.height
                    opacity: root.dragSourceId === modelData ? 0.24 : 1
                    Accessible.description: "Drag to reorder, or press Control Shift Left or Right"

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.duration(Motion.quick)
                            easing.type: Motion.easingStandard
                        }
                    }

                    BarIsland {
                        id: island
                        anchors.centerIn: parent
                        islandId: islandDelegate.modelData
                        screen: root.modelData
                        available: root.islandVisible(islandDelegate.modelData)
                    }

                    BarReorderGesture {
                        onDragStarted: function(pressScenePosition, scenePosition) {
                            root.beginDrag(islandDelegate, pressScenePosition, scenePosition);
                        }
                        onDragMoved: function(scenePosition) { root.updateDrag(scenePosition); }
                        onDragFinished: function(scenePosition) { root.finishDrag(scenePosition); }
                        onDragCanceled: root.clearDrag()
                    }

                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier)
                                && (event.modifiers & Qt.ShiftModifier)
                                && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                            root.moveKeyboard(islandDelegate.index, event.key === Qt.Key_Left ? -1 : 1);
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                visible: Config.error !== ""
                color: Theme.red
            }
        }
    }

    Connections {
        target: Config
        function onBarChanged() { if (!root.dragging) root.localOrder = Config.bar.islands.slice(); }
    }

    Connections {
        target: Settings
        function onFieldErrorsChanged() {
            if (Settings.fieldErrors["bar.islands"] !== undefined)
                root.localOrder = Config.bar.islands.slice();
        }
    }

}
