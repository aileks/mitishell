import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../core"

Row {
    id: root

    property var activeMenuAnchor: null

    spacing: Theme.spaceXs
    height: 24

    function showMenu(anchor) {
        SurfaceCoordinator.close();
        if (activeMenuAnchor !== null && activeMenuAnchor !== anchor
                && activeMenuAnchor.visible) {
            activeMenuAnchor.close();
        }
        if (anchor.visible) {
            anchor.close();
            activeMenuAnchor = null;
            return;
        }
        activeMenuAnchor = anchor;
        anchor.open();
    }

    Repeater {
        model: Tray.items

        delegate: FocusScope {
            id: trayItem

            required property var modelData

            width: 24
            height: 24
            activeFocusOnTab: true
            Accessible.name: Tray.label(modelData)
            Accessible.description: Tray.description(modelData)
            Accessible.role: Accessible.Button
            Accessible.onPressAction: primaryAction()

            function primaryAction() {
                if (modelData.onlyMenu && modelData.hasMenu) {
                    openMenu();
                    return;
                }
                modelData.activate();
            }

            function secondaryAction() {
                modelData.secondaryActivate();
            }

            function contextAction() {
                if (modelData.hasMenu) {
                    openMenu();
                    return;
                }
                secondaryAction();
            }

            function openMenu() {
                if (!modelData.hasMenu || trayItem.QsWindow.window === null) {
                    return;
                }
                const point = trayItem.QsWindow.window.contentItem.mapFromItem(
                    trayItem,
                    trayItem.width / 2,
                    trayItem.height,
                );
                menuAnchor.anchor.rect.x = Math.round(point.x);
                menuAnchor.anchor.rect.y = Math.round(point.y);
                root.showMenu(menuAnchor);
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: trayItem.activeFocus || hover.hovered
                    ? Theme.overlay : "transparent"
                border.width: trayItem.activeFocus ? 2 : 0
                border.color: Theme.blue

                Image {
                    id: trayIcon

                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: trayItem.modelData.icon
                    sourceSize.width: 16
                    sourceSize.height: 16
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.centerIn: parent
                    visible: trayIcon.source.toString() === ""
                        || trayIcon.status === Image.Error
                    text: "•"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 7
                    height: 7
                    radius: 4
                    visible: trayItem.modelData.status === Status.NeedsAttention
                    color: Theme.orange
                }

                HoverHandler {
                    id: hover
                }
            }

            QsMenuAnchor {
                id: menuAnchor

                menu: trayItem.modelData.menu
                anchor.window: trayItem.QsWindow.window
                anchor.edges: Edges.Top | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right
                anchor.rect.width: 1
                anchor.rect.height: 1

                onClosed: {
                    if (root.activeMenuAnchor === menuAnchor) {
                        root.activeMenuAnchor = null;
                    }
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: trayItem.primaryAction()
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: trayItem.contextAction()
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: trayItem.secondaryAction()
            }

            WheelHandler {
                onWheel: function(event) {
                    trayItem.modelData.scroll(event.angleDelta.y, false);
                    event.accepted = true;
                }
            }

            Keys.onReturnPressed: function(event) {
                trayItem.primaryAction();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                trayItem.primaryAction();
                event.accepted = true;
            }
            Keys.onMenuPressed: function(event) {
                trayItem.contextAction();
                event.accepted = true;
            }
        }
    }
}
