pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../core"

FocusScope {
    id: root

    required property var screen
    property var activeItem: null
    property Item activeAnchor: root
    property bool expanded: false
    readonly property bool menuOpen: SurfaceCoordinator.activeKey === "tray"
        && SurfaceCoordinator.originScreen === screen

    implicitWidth: trayRow.implicitWidth
    implicitHeight: 24
    activeFocusOnTab: true

    function showMenu(item, anchor) {
        if (!item.hasMenu) {
            return;
        }

        if (menuOpen && activeItem === item) {
            SurfaceCoordinator.close();
            return;
        }

        activeItem = item;
        activeAnchor = anchor;
        SurfaceCoordinator.open("tray", screen);
    }

    function closeMenu() {
        if (menuOpen) {
            SurfaceCoordinator.close();
        }
    }

    function forgetItem(item) {
        if (activeItem !== item) {
            return;
        }

        closeMenu();
        activeItem = null;
        activeAnchor = root;
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        FocusScope {
            width: 24
            height: 24
            activeFocusOnTab: true
            Accessible.name: root.expanded ? "Collapse system tray" : "Expand system tray"
            Accessible.role: Accessible.Button
            Accessible.onPressAction: root.expanded = !root.expanded

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: parent.activeFocus || chevronHover.hovered ? Theme.hoverFill : "transparent"
                border.width: parent.activeFocus ? 2 : 0
                border.color: Theme.blue
                Text {
                    anchors.centerIn: parent
                    text: root.expanded ? "‹" : "›"
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeTitle
                }
                HoverHandler { id: chevronHover }
            }
            TapHandler { onTapped: root.expanded = !root.expanded }
            Keys.onReturnPressed: function(event) { root.expanded = !root.expanded; event.accepted = true; }
            Keys.onSpacePressed: function(event) { root.expanded = !root.expanded; event.accepted = true; }
        }

        Item {
            width: root.expanded ? trayIcons.implicitWidth : 0
            height: 24
            clip: true
            Behavior on width { NumberAnimation { duration: Motion.duration(Motion.normal); easing.type: Motion.easingStandard } }

            Row {
                id: trayIcons
                spacing: Theme.spaceXs

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
            Component.onDestruction: root.forgetItem(modelData)

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
                root.showMenu(modelData, trayItem);
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
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.expanded
        onActivated: {
            root.closeMenu();
            root.expanded = false;
        }
    }

    Connections {
        target: root.activeItem
        ignoreUnknownSignals: true

        function onHasMenuChanged() {
            if (root.activeItem !== null && !root.activeItem.hasMenu) {
                root.forgetItem(root.activeItem);
            }
        }
    }

    AnchoredPopover {
        id: trayPopover

        anchorItem: root.activeAnchor
        open: root.menuOpen && root.activeItem !== null && root.activeItem.hasMenu
        contentWidth: trayMenu.implicitWidth + Theme.spaceLg * 2
        contentHeight: trayMenu.implicitHeight + Theme.spaceLg * 2

        TrayMenu {
            id: trayMenu

            anchors.fill: parent
            menu: root.activeItem === null ? null : root.activeItem.menu
            opened: trayPopover.open
            onDismissRequested: root.closeMenu()
        }
    }
}
