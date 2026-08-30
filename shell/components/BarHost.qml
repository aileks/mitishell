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
    property var localLayout: BarModel.clone(Config.bar.layout)
    property var overflowIds: []
    property string dragSourceId: ""
    property string dragTargetId: ""
    property string dragTargetSection: ""
    property bool dragAfter: false
    property point dragPointerGlobal: Qt.point(0, 0)
    property point dragPressOffset: Qt.point(0, 0)
    property size dragGhostSize: Qt.size(0, 0)
    property url dragImageSource
    property rect dragMarkerGlobalRect: Qt.rect(0, 0, 0, 0)
    property bool dragDropValid: false
    readonly property bool dragging: dragSourceId !== ""

    function saveLayout(next) {
        if (JSON.stringify(next) === JSON.stringify(localLayout)) return;
        localLayout = next;
        Settings.setField("bar.layout", JSON.stringify(next));
        overflowTimer.restart();
    }

    function keyboardMove(id, direction) {
        saveLayout(BarModel.moveKeyboard(localLayout, id, direction));
    }

    function beginDrag(delegateItem, pressScenePosition, scenePosition) {
        const visual = delegateItem.dragVisual;
        if (visual === null) return;
        dragSourceId = delegateItem.modelData;
        dragPressOffset = visual.mapFromItem(null, pressScenePosition);
        dragGhostSize = Qt.size(Math.ceil(visual.width), Math.ceil(visual.height));
        SurfaceCoordinator.close();
        updateDrag(scenePosition);
        const sourceId = dragSourceId;
        visual.grabToImage(function(result) {
            if (root.dragSourceId === sourceId) root.dragImageSource = result.url;
        }, dragGhostSize);
    }

    function sectionEntries() {
        return [
            { name: "left", row: leftRow, repeater: leftRepeater },
            { name: "center", row: centerRow, repeater: centerRepeater },
            { name: "right", row: rightRow, repeater: rightRepeater },
        ];
    }

    function updateDrag(scenePosition) {
        if (!dragging) return;
        dragPointerGlobal = contentItem.mapToGlobal(scenePosition.x, scenePosition.y);
        const entries = sectionEntries();
        const third = width / 3;
        let chosen = scenePosition.x < third ? entries[0]
            : (scenePosition.x > third * 2 ? entries[2] : entries[1]);
        let bestDistance = Number.POSITIVE_INFINITY;
        let target = null;
        for (let sectionIndex = 0; sectionIndex < entries.length; sectionIndex += 1) {
            const entry = entries[sectionIndex];
            for (let index = 0; index < entry.repeater.count; index += 1) {
                const candidate = entry.repeater.itemAt(index);
                if (candidate === null || !candidate.visible || candidate.width <= 0) continue;
                const center = candidate.mapToItem(null, candidate.width / 2, candidate.height / 2);
                const distance = Math.abs(scenePosition.x - center.x);
                if (distance < bestDistance) {
                    bestDistance = distance;
                    target = candidate;
                    chosen = entry;
                }
            }
        }

        dragTargetSection = chosen.name;
        dragTargetId = target === null ? "" : target.modelData;
        dragAfter = target !== null
            && scenePosition.x >= target.mapToItem(null, target.width / 2, 0).x;
        const markerPoint = target !== null
            ? target.mapToGlobal(dragAfter ? target.width : 0, 0)
            : chosen.row.mapToGlobal(chosen.name === "right" ? chosen.row.width : 0, 0);
        dragMarkerGlobalRect = Qt.rect(
            markerPoint.x,
            markerPoint.y,
            3,
            target !== null ? target.height : chosen.row.height,
        );
        dragDropValid = dragTargetSection !== ""
            && !(dragTargetSection === "center"
                && BarModel.sectionOf(localLayout, dragSourceId) !== "center"
                && localLayout.center.length >= 3);
    }

    function finishDrag(scenePosition) {
        updateDrag(scenePosition);
        if (dragDropValid) {
            const next = dragTargetId === ""
                ? BarModel.moveTo(localLayout, dragSourceId, dragTargetSection,
                    localLayout[dragTargetSection].length)
                : BarModel.moveAtDrop(localLayout, dragSourceId, dragTargetId, dragAfter);
            saveLayout(next);
        }
        clearDrag();
    }

    function clearDrag() {
        dragSourceId = "";
        dragTargetId = "";
        dragTargetSection = "";
        dragDropValid = false;
        dragImageSource = "";
        dragGhostSize = Qt.size(0, 0);
    }

    function collectWidths(repeater, ids, target) {
        for (let index = 0; index < repeater.count; index += 1) {
            const item = repeater.itemAt(index);
            if (item !== null && item.widgetAvailable) target[ids[index]] = item.widgetWidth;
        }
    }

    function recomputeOverflow() {
        const widths = {};
        collectWidths(leftRepeater, localLayout.left, widths);
        collectWidths(rightRepeater, localLayout.right, widths);
        const left = localLayout.left.filter(function(id) { return widths[id] !== undefined; });
        const right = localLayout.right.filter(function(id) { return widths[id] !== undefined; });
        const totalSides = Math.max(0,
            width - Math.min(centerRow.implicitWidth, 420) - Theme.spaceXl * 4);
        const budgets = BarModel.overflowBudgets(
            left, right, widths, totalSides, Theme.spaceXs, 28);
        overflowIds = BarModel.overflowFor(left, widths, budgets.left, Theme.spaceXs, 28)
            .concat(BarModel.overflowFor(right, widths, budgets.right, Theme.spaceXs, 28));
    }

    screen: modelData
    visible: modelData !== null && Config.outputEnabled(modelData.name)
    color: "transparent"
    implicitHeight: Config.bar.height
    exclusiveZone: visible ? implicitHeight : 0
    anchors { top: true; left: true; right: true }
    // qmllint disable unqualified unresolved-type
    margins.top: Config.bar.marginTop
    margins.left: Config.bar.marginHorizontal
    margins.right: Config.bar.marginHorizontal
    // qmllint enable unqualified unresolved-type

    NotificationMediaCache { screen: root.modelData }

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
        id: barSurface
        anchors.fill: parent
        radius: Theme.radiusPill
        color: Theme.layerRaised
        border.width: 1
        border.color: Theme.borderSubtle

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            Repeater {
                id: leftRepeater
                model: root.localLayout.left
                delegate: widgetDelegate
            }
        }

        Row {
            id: centerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            Repeater {
                id: centerRepeater
                model: root.localLayout.center
                delegate: widgetDelegate
            }
        }

        Row {
            id: rightRow
            anchors.right: overflowButton.left
            anchors.rightMargin: overflowButton.visible ? Theme.spaceXs : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            Repeater {
                id: rightRepeater
                model: root.localLayout.right
                delegate: widgetDelegate
            }
        }

        Item {
            id: overflowButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            visible: root.overflowIds.length > 0
            width: visible ? trigger.implicitWidth : 0
            height: 28

            BarPopoverTrigger {
                id: trigger
                anchors.verticalCenter: parent.verticalCenter
                popoverKey: "barOverflow"
                screen: root.modelData
                accent: Theme.orange
                Accessible.name: "More bar items"

                // Same island height as the power widget, with a tighter
                // horizontal pad: barIconSize glyph centered.
                Item {
                    implicitWidth: Theme.barIconSize + Theme.spaceMd
                    implicitHeight: 24

                    IconLabel {
                        anchors.centerIn: parent
                        value: Icons.ellipsis
                    }
                }
            }

            AnchoredPopover {
                anchorItem: trigger
                open: BarModel.overflowOpen(
                    trigger.active,
                    SurfaceCoordinator.activeKey,
                    SurfaceCoordinator.originScreen,
                    root.modelData,
                    root.overflowIds,
                )
                focusGrabEnabled: trigger.active
                contentWidth: Math.max(
                    240,
                    Math.min(440, overflowFlow.implicitWidth + Theme.spaceLg * 2),
                )
                contentHeight: overflowFlow.implicitHeight + Theme.spaceLg * 2

                Flow {
                    id: overflowFlow
                    anchors.fill: parent
                    spacing: Theme.spaceSm

                    Repeater {
                        model: root.overflowIds
                        delegate: Item {
                            required property string modelData
                            width: overflowWidget.implicitWidth
                            height: 28

                            BarWidget {
                                id: overflowWidget
                                anchors.centerIn: parent
                                widgetId: parent.modelData
                                screen: root.modelData
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: widgetDelegate
        Item {
            id: delegateItem
            required property string modelData
            readonly property var dragVisual: widget.dragVisual
            readonly property real widgetWidth: widget.implicitWidth
            readonly property bool widgetAvailable: widget.available
            width: widget.implicitWidth
            height: 28
            visible: widget.available && root.overflowIds.indexOf(modelData) === -1
            enabled: visible
            opacity: root.dragSourceId === modelData ? 0.24 : 1
            Accessible.description: "Drag to rearrange. Control Shift arrows move this bar item."

            BarWidget {
                id: widget
                anchors.centerIn: parent
                widgetId: delegateItem.modelData
                screen: root.modelData
            }

            BarReorderGesture {
                onDragStarted: function(pressScenePosition, scenePosition) {
                    root.beginDrag(delegateItem, pressScenePosition, scenePosition);
                }
                onDragMoved: function(scenePosition) { root.updateDrag(scenePosition); }
                onDragFinished: function(scenePosition) { root.finishDrag(scenePosition); }
                onDragCanceled: root.clearDrag()
            }

            Keys.onPressed: function(event) {
                if (!(event.modifiers & Qt.ControlModifier)
                        || !(event.modifiers & Qt.ShiftModifier)) return;
                const direction = BarModel.moveDirection(event.key);
                if (direction === "") return;
                root.keyboardMove(modelData, direction);
                event.accepted = true;
            }

            onWidgetWidthChanged: overflowTimer.restart()
            onWidgetAvailableChanged: overflowTimer.restart()
        }
    }

    Timer { id: overflowTimer; interval: 0; onTriggered: root.recomputeOverflow() }
    onWidthChanged: overflowTimer.restart()
    Component.onCompleted: overflowTimer.restart()

    Connections {
        target: Config
        function onBarChanged() {
            if (!root.dragging) root.localLayout = BarModel.clone(Config.bar.layout);
            overflowTimer.restart();
        }
    }

    Connections {
        target: Settings
        function onFieldErrorsChanged() {
            if (Settings.fieldErrors["bar.layout"] !== undefined) {
                root.localLayout = BarModel.clone(Config.bar.layout);
            }
        }
    }
}
