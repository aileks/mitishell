import QtQuick
import "../core"
import "../lib/BarModel.js" as BarModel

FocusScope {
    id: root

    property string popoverKey
    required property var screen
    // Accent of the selected fill and border shown while this trigger's
    // popover is open.
    property color accent: Theme.orange
    // Content that paints its own hover feedback (for example the overflow
    // button) suppresses the trigger's hover fill to avoid stacking.
    property bool contentHandlesHover: false
    default property alias content: contentItem.data
    readonly property bool active: BarModel.popoverActive(
        SurfaceCoordinator.activeKey,
        SurfaceCoordinator.originScreen,
        popoverKey,
        screen,
        enabled,
    )

    signal triggered(bool opened)

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        z: -1
        radius: Theme.radiusPill
        color: root.active ? Theme.alpha(root.accent, 0.14)
            : (root.contentHandlesHover || !(root.activeFocus || contentHover.hovered)
                ? "transparent" : Theme.hoverFill)
        border.width: root.activeFocus ? 2 : (root.active ? 1 : 0)
        border.color: root.activeFocus ? Theme.blue : root.accent
    }

    function activate() {
        const opened = SurfaceCoordinator.toggle(popoverKey, screen);
        triggered(opened);
    }

    Item {
        id: contentItem
        anchors.fill: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    HoverHandler {
        id: contentHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.activate()
    }

    Keys.onReturnPressed: function(event) {
        root.activate();
        event.accepted = true;
    }
    Keys.onSpacePressed: function(event) {
        root.activate();
        event.accepted = true;
    }
    Keys.onEscapePressed: function(event) {
        SurfaceCoordinator.close();
        event.accepted = true;
    }
}
