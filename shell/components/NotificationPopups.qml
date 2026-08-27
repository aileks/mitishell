pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"

// Toast popups anchored under the bar's bell island, right-aligned with it.
// Passive by design: no keyboard focus and no grab, so the rest of the
// screen stays live while cards come and go. The popup inherits its screen
// from the parent bar window; only that bar's island shows toasts.
PopupWindow {
    id: root

    required property Item anchorItem
    readonly property var anchorWindow: anchorItem.QsWindow.window
    readonly property var ownerScreen: anchorWindow === null || anchorWindow === undefined
        ? null
        : anchorWindow.screen

    // The stack pauses while the session is locked or the focused output is
    // fullscreen, and steps aside while the history popover is open on this
    // screen; history still records everything.
    readonly property bool suppressed: Notifications.sessionLocked
        || Notifications.focusedFullscreen
        || (SurfaceCoordinator.activeKey === "notifications"
            && SurfaceCoordinator.originScreen === ownerScreen)
    readonly property var popups: ownerScreen !== null
        && Notifications.popupScreenName === ownerScreen.name
        && !suppressed ? Notifications.popups : []

    visible: popups.length > 0
    color: "transparent"
    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    // The stack grows and shrinks as cards expire; keep the anchor pinned
    // to the island instead of letting the compositor re-slide it.
    // qmllint disable unresolved-type
    onImplicitHeightChanged: root.anchor.updateAnchor()
    // qmllint enable unresolved-type

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

            // The stack hugs the output's right edge, wherever the bell
            // island sits in the configured order; only the vertical anchor
            // follows the island.
            const localY = root.anchorItem.height + Theme.spaceSm;
            const point = root.anchorWindow.contentItem.mapFromItem(
                root.anchorItem,
                0,
                localY,
            );
            // qmllint disable unresolved-type
            root.anchor.rect.x = Math.round(
                root.anchorWindow.width - root.implicitWidth - Theme.spaceSm,
            );
            root.anchor.rect.y = Math.round(point.y);
            // qmllint enable unresolved-type
        }
    }

    Column {
        id: stack

        spacing: Theme.spaceSm

        Repeater {
            model: root.popups

            delegate: NotificationCard {
                required property var modelData

                notification: modelData
                historyMode: false
                onDismissed: function(expired) {
                    Notifications.dismissPopup(modelData.recordId, expired);
                }
            }
        }
    }
}
