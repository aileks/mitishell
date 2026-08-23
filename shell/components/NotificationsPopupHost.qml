import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// The popup surface is sized to its card stack so only the cards take
// input; the rest of the screen stays live.
PanelWindow {
    id: root

    required property var modelData

    // Popups land on the focused output and pause while it is fullscreen or
    // the session is locked; history still records everything.
    readonly property bool focused: Osd.screenName === modelData.name
    readonly property bool suppressed: Notifications.sessionLocked
        || Notifications.focusedFullscreen
    readonly property var popups: focused && !suppressed ? Notifications.popups : []

    screen: modelData
    visible: popups.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "mitishell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }
    margins {
        top: Config.bar.height + Config.bar.marginTop + Theme.spaceMd
        right: Config.bar.marginHorizontal
    }

    width: stack.implicitWidth
    height: stack.implicitHeight

    Column {
        id: stack

        spacing: Theme.spaceSm

        Repeater {
            model: root.popups

            delegate: NotificationCard {
                required property var modelData

                notification: modelData
                historyMode: false
                onDismissed: Notifications.dismissPopup(modelData.id, false)
            }
        }
    }
}
