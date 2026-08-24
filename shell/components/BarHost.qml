import QtQuick
import Quickshell
import "../core"
import "../lib/BarModel.js" as BarModel

PanelWindow {
    id: root

    required property var modelData
    property var localOrder: Config.bar.islands.slice()
    property int dragFrom: -1
    property int dragTo: -1
    property real dragOffset: 0
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
            : id === "weather" ? Weather.visible : true;
    }

    function nextVisible(index) {
        return BarModel.nextVisible(localOrder, index, islandVisible);
    }

    function updateDragTarget() {
        const dragged = rightRepeater.itemAt(dragFrom);
        if (dragged === null) return;
        const center = dragged.x + dragged.width / 2 + dragOffset;
        let target = dragFrom;
        for (let index = 0; index < localOrder.length; index += 1) {
            const candidate = rightRepeater.itemAt(index);
            if (candidate !== null && candidate.visible
                    && center > candidate.x + candidate.width / 2) target = index;
        }
        dragTo = target;
    }

    function finishDrag() {
        if (dragFrom >= 0 && dragTo >= 0 && dragFrom !== dragTo) {
            localOrder = BarModel.move(localOrder, dragFrom, dragTo);
            Settings.setField("bar.islands", JSON.stringify(localOrder));
        }
        dragFrom = -1;
        dragTo = -1;
        dragOffset = 0;
    }

    function moveKeyboard(index, delta) {
        const moved = BarModel.moveVisible(localOrder, index, delta, islandVisible);
        if (JSON.stringify(moved) === JSON.stringify(localOrder)) return;
        localOrder = moved;
        Settings.setField("bar.islands", JSON.stringify(localOrder));
    }

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

    NotificationMediaCache {
        screen: root.modelData
    }

    Rectangle {
        id: leftIsland

        anchors.left: parent.left
        width: Math.min(leftContent.implicitWidth + Theme.spaceLg * 2, 560)
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
            mediaTrigger.implicitWidth + Theme.spaceLg * 2,
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

            anchors.centerIn: parent
            width: Math.max(0, parent.width - Theme.spaceLg * 2)
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
            ? rightContent.implicitWidth + Theme.spaceLg * 2 : 0
        height: parent.height
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle
        visible: width > 0

        Row {
            id: rightContent

            anchors.centerIn: parent
            height: parent.height
            spacing: Theme.spaceMd

            Repeater {
                id: rightRepeater
                model: root.localOrder

                delegate: Item {
                    id: islandDelegate
                    required property string modelData
                    required property int index
                    property bool armed: false
                    readonly property real siblingShift: {
                        if (root.dragFrom < root.dragTo && index > root.dragFrom && index <= root.dragTo)
                            return -(rightRepeater.itemAt(root.dragFrom)?.width || 0) - rightContent.spacing;
                        if (root.dragFrom > root.dragTo && index >= root.dragTo && index < root.dragFrom)
                            return (rightRepeater.itemAt(root.dragFrom)?.width || 0) + rightContent.spacing;
                        return 0;
                    }

                    width: island.implicitWidth
                    height: rightContent.height
                    z: root.dragFrom === index ? 10 : 0
                    scale: root.dragFrom === index ? 1.08 : 1
                    Accessible.description: "Hold and drag, or press Control Shift Left or Right, to reorder"

                    transform: Translate {
                        x: root.dragFrom === islandDelegate.index ? root.dragOffset : islandDelegate.siblingShift
                        Behavior on x { NumberAnimation { duration: Motion.duration(Motion.quick); easing.type: Motion.easingStandard } }
                    }
                    Behavior on scale { NumberAnimation { duration: Motion.duration(Motion.quick); easing.type: Motion.easingStandard } }

                    BarIsland {
                        id: island
                        anchors.centerIn: parent
                        islandId: islandDelegate.modelData
                        screen: root.modelData
                        separatorAfter: BarModel.separatorAfter(
                            islandDelegate.modelData,
                            root.nextVisible(islandDelegate.index),
                        )
                    }

                    TapHandler {
                        id: holdHandler
                        longPressThreshold: 0.35
                        onLongPressed: {
                            islandDelegate.armed = true;
                            root.dragFrom = islandDelegate.index;
                            root.dragTo = islandDelegate.index;
                        }
                        onPressedChanged: {
                            if (!pressed && islandDelegate.armed) {
                                islandDelegate.armed = false;
                                root.finishDrag();
                            }
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        enabled: islandDelegate.armed
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onTranslationChanged: {
                            root.dragOffset = activeTranslation.x;
                            root.updateDragTarget();
                        }
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
        function onBarChanged() { if (root.dragFrom < 0) root.localOrder = Config.bar.islands.slice(); }
    }

    Connections {
        target: Settings
        function onFieldErrorsChanged() {
            if (Settings.fieldErrors["bar.islands"] !== undefined)
                root.localOrder = Config.bar.islands.slice();
        }
    }

}
