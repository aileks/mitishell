import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../core"

FocusScope {
    id: root

    required property bool opened
    property var activeItem: null
    property var submenuStack: []

    readonly property bool showingMenu: activeItem !== null
    readonly property var currentChildren: submenuStack.length > 0
        ? submenuStack[submenuStack.length - 1].opener.children
        : rootMenu.children
    readonly property string currentTitle: submenuStack.length > 0
        ? submenuStack[submenuStack.length - 1].title
        : (activeItem === null ? "System tray" : Tray.label(activeItem))

    onOpenedChanged: {
        if (!opened) {
            resetMenu();
        }
    }

    Component {
        id: submenuOpenerComponent

        QsMenuOpener {}
    }

    QsMenuOpener {
        id: rootMenu
        menu: root.activeItem === null ? null : root.activeItem.menu
    }

    function resetMenu() {
        const openers = submenuStack;
        submenuStack = [];
        activeItem = null;
        for (let index = openers.length - 1; index >= 0; index--) {
            openers[index].opener.destroy();
        }
    }

    function showMenu(item) {
        resetMenu();
        activeItem = item;
        Qt.callLater(function() {
            entryList.forceActiveFocus(Qt.TabFocusReason);
        });
    }

    function enterSubmenu(entry) {
        const opener = submenuOpenerComponent.createObject(root, { menu: entry });
        if (opener === null) {
            return;
        }

        const nextStack = submenuStack.slice();
        nextStack.push({ opener: opener, title: entry.text || currentTitle });
        submenuStack = nextStack;
        entryList.positionViewAtBeginning();
    }

    function leaveMenuLevel() {
        if (submenuStack.length === 0) {
            resetMenu();
            return;
        }

        const nextStack = submenuStack.slice();
        const current = nextStack.pop();
        submenuStack = nextStack;
        current.opener.destroy();
        entryList.positionViewAtBeginning();
    }

    function activateItem(item) {
        if (item.onlyMenu && item.hasMenu) {
            showMenu(item);
            return;
        }

        item.activate();
        SurfaceCoordinator.close();
    }

    function openItemMenu(item) {
        if (item.hasMenu) {
            showMenu(item);
            return;
        }

        item.secondaryActivate();
        SurfaceCoordinator.close();
    }

    function activateMenuEntry(entry) {
        if (!entry.enabled) {
            return;
        }
        if (entry.hasChildren) {
            enterSubmenu(entry);
            return;
        }

        entry.triggered();
        SurfaceCoordinator.close();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceMd

        Row {
            width: parent.width
            height: 24
            spacing: Theme.spaceSm

            Rectangle {
                visible: root.showingMenu
                width: visible ? 24 : 0
                height: 24
                radius: Theme.radiusSmall
                color: backHover.hovered || activeFocus ? Theme.overlay : "transparent"
                activeFocusOnTab: visible
                Accessible.name: root.submenuStack.length > 0 ? "Back" : "All tray items"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: root.leaveMenuLevel()

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: 18
                }

                HoverHandler {
                    id: backHover
                }

                TapHandler {
                    onTapped: root.leaveMenuLevel()
                }

                Keys.onReturnPressed: function(event) {
                    root.leaveMenuLevel();
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.leaveMenuLevel();
                    event.accepted = true;
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (root.showingMenu ? 32 : 0)
                text: root.showingMenu ? root.currentTitle : "System tray"
                color: Theme.textBright
                elide: Text.ElideRight
                font.family: Theme.fontSans
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        ListView {
            id: entryList

            width: parent.width
            height: parent.height - 24 - parent.spacing
            clip: true
            spacing: Theme.spaceXs
            model: root.showingMenu ? root.currentChildren : Tray.items
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            activeFocusOnTab: true

            delegate: Loader {
                id: entryLoader

                required property var modelData
                width: entryList.width
                sourceComponent: root.showingMenu ? menuEntryComponent : trayItemComponent

                Binding {
                    target: entryLoader.item
                    property: "modelObject"
                    value: entryLoader.modelData
                    when: entryLoader.item !== null
                }
            }
        }
    }

    Component {
        id: trayItemComponent

        Rectangle {
            id: trayRow

            property var modelObject: null

            width: entryList.width
            height: 48
            radius: Theme.radiusMedium
            color: activeFocus || trayHover.hovered ? Theme.overlay : "transparent"
            border.width: activeFocus ? 2 : 0
            border.color: Theme.blue
            activeFocusOnTab: true
            Accessible.name: modelObject === null ? "" : Tray.label(modelObject)
            Accessible.description: modelObject === null ? "" : Tray.description(modelObject)
            Accessible.role: Accessible.Button
            Accessible.onPressAction: {
                if (modelObject !== null) {
                    root.activateItem(modelObject);
                }
            }

            Image {
                id: itemIcon

                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                source: trayRow.modelObject === null ? "" : trayRow.modelObject.icon
                sourceSize.width: 24
                sourceSize.height: 24
                fillMode: Image.PreserveAspectFit
            }

            Rectangle {
                anchors.right: itemIcon.right
                anchors.bottom: itemIcon.bottom
                width: 7
                height: 7
                radius: 4
                visible: trayRow.modelObject !== null
                    && trayRow.modelObject.status === Status.NeedsAttention
                color: Theme.orange
            }

            Column {
                anchors.left: itemIcon.right
                anchors.right: menuButton.left
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: trayRow.modelObject === null ? "" : Tray.label(trayRow.modelObject)
                    color: Theme.textBright
                    elide: Text.ElideRight
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: trayRow.modelObject === null ? "" : Tray.description(trayRow.modelObject)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                }
            }

            Rectangle {
                id: menuButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 48 : 0
                height: 28
                visible: trayRow.modelObject !== null && trayRow.modelObject.hasMenu
                    && !trayRow.modelObject.onlyMenu
                radius: Theme.radiusSmall
                color: menuHover.hovered || activeFocus ? Theme.container : "transparent"
                activeFocusOnTab: visible
                Accessible.name: "Open " + (trayRow.modelObject === null
                    ? "tray item" : Tray.label(trayRow.modelObject)) + " menu"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: root.openItemMenu(trayRow.modelObject)

                Text {
                    anchors.centerIn: parent
                    text: "menu"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                }

                HoverHandler {
                    id: menuHover
                }

                TapHandler {
                    onTapped: root.openItemMenu(trayRow.modelObject)
                }

                Keys.onReturnPressed: function(event) {
                    root.openItemMenu(trayRow.modelObject);
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.openItemMenu(trayRow.modelObject);
                    event.accepted = true;
                }
            }

            HoverHandler {
                id: trayHover
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.activateItem(trayRow.modelObject)
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: root.openItemMenu(trayRow.modelObject)
            }

            WheelHandler {
                onWheel: function(event) {
                    if (trayRow.modelObject !== null) {
                        trayRow.modelObject.scroll(event.angleDelta.y, false);
                        event.accepted = true;
                    }
                }
            }

            Keys.onReturnPressed: function(event) {
                root.activateItem(trayRow.modelObject);
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                root.activateItem(trayRow.modelObject);
                event.accepted = true;
            }
            Keys.onMenuPressed: function(event) {
                root.openItemMenu(trayRow.modelObject);
                event.accepted = true;
            }
        }
    }

    Component {
        id: menuEntryComponent

        Rectangle {
            id: menuRow

            property var modelObject: null

            width: entryList.width
            height: modelObject !== null && modelObject.isSeparator ? 9 : 34
            radius: Theme.radiusSmall
            color: !isEntry || !modelObject.enabled
                ? "transparent" : (activeFocus || entryHover.hovered ? Theme.overlay : "transparent")
            activeFocusOnTab: isEntry && modelObject.enabled
            opacity: modelObject !== null && modelObject.enabled ? 1 : 0.45
            readonly property bool isEntry: modelObject !== null && !modelObject.isSeparator
            Accessible.name: isEntry ? modelObject.text : ""
            Accessible.role: isEntry ? Accessible.MenuItem : Accessible.NoRole
            Accessible.onPressAction: {
                if (isEntry) {
                    root.activateMenuEntry(modelObject);
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                visible: !menuRow.isEntry
                color: Theme.overlay
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                visible: menuRow.isEntry && menuRow.modelObject.buttonType !== QsMenuButtonType.None
                radius: menuRow.modelObject !== null
                    && menuRow.modelObject.buttonType === QsMenuButtonType.RadioButton ? 7 : 3
                color: menuRow.modelObject !== null
                    && menuRow.modelObject.checkState === Qt.Checked ? Theme.orange : "transparent"
                border.width: 1
                border.color: Theme.textMuted
            }

            Image {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                visible: menuRow.isEntry && source.toString() !== ""
                source: menuRow.isEntry ? menuRow.modelObject.icon : ""
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 52
                anchors.right: submenuMarker.left
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                visible: menuRow.isEntry
                text: menuRow.isEntry ? menuRow.modelObject.text : ""
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.fontSans
                font.pixelSize: 11
            }

            Text {
                id: submenuMarker

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                visible: menuRow.isEntry && menuRow.modelObject.hasChildren
                text: "›"
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 16
            }

            HoverHandler {
                id: entryHover
                enabled: menuRow.isEntry && menuRow.modelObject.enabled
            }

            TapHandler {
                enabled: menuRow.isEntry && menuRow.modelObject.enabled
                onTapped: root.activateMenuEntry(menuRow.modelObject)
            }

            Keys.onReturnPressed: function(event) {
                root.activateMenuEntry(menuRow.modelObject);
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                root.activateMenuEntry(menuRow.modelObject);
                event.accepted = true;
            }
        }
    }
}
