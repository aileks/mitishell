import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"

PopupWindow {
    id: root

    required property Item anchorItem
    property bool open: false
    property int contentWidth: 320
    property int contentHeight: 240
    default property alias content: card.content

    readonly property var anchorWindow: anchorItem.QsWindow.window

    visible: open || card.opacity > 0
    color: "transparent"
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    onOpenChanged: {
        if (open) {
            Qt.callLater(function() {
                card.contentItem.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: SurfaceCoordinator.close()
    }

    HyprlandFocusGrab {
        active: root.open
        windows: root.anchorWindow === null ? [root] : [root, root.anchorWindow]
        onCleared: SurfaceCoordinator.close()
    }

    anchor {
        window: root.anchorWindow
        // qmllint disable missing-type
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        // qmllint enable missing-type
        rect.width: 1
        rect.height: 1

        onAnchoring: {
            if (root.anchorWindow === null) {
                return;
            }

            const localX = root.anchorItem.width / 2 - root.implicitWidth / 2;
            const localY = root.anchorItem.height + Theme.spaceSm;
            const point = root.anchorWindow.contentItem.mapFromItem(
                root.anchorItem,
                localX,
                localY,
            );
            // qmllint disable unresolved-type
            root.anchor.rect.x = Math.round(Math.max(
                Theme.spaceSm,
                Math.min(point.x, root.anchorWindow.width - root.implicitWidth - Theme.spaceSm),
            ));
            root.anchor.rect.y = Math.round(point.y);
            // qmllint enable unresolved-type
        }
    }

    SurfaceFrame {
        id: card

        anchors.fill: parent
        floating: true
        padding: Theme.spaceLg
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

    }
}
