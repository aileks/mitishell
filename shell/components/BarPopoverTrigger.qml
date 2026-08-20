import QtQuick
import "../core"

FocusScope {
    id: root

    required property string popoverKey
    required property var screen
    default property alias content: contentItem.data
    readonly property bool active: SurfaceCoordinator.activeKey === popoverKey
        && SurfaceCoordinator.originScreen === screen

    signal triggered(bool opened)

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight
    activeFocusOnTab: true

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
