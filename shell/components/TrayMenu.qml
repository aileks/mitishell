import QtQuick
import QtQuick.Effects
import Quickshell
import "../core"

FocusScope {
    id: root

    required property var menu
    required property bool opened
    property var submenuStack: []

    signal dismissRequested()

    readonly property var currentChildren: submenuStack.length === 0
        ? rootMenu.children
        : submenuStack[submenuStack.length - 1].opener.children
    readonly property var currentEntries: currentChildren === null
        ? [] : currentChildren.values
    readonly property string currentTitle: submenuStack.length === 0
        ? "" : submenuStack[submenuStack.length - 1].title
    readonly property int headerHeight: submenuStack.length === 0 ? 0 : 34
    readonly property int entryHeight: 32
    readonly property int separatorHeight: 7
    readonly property int listSpacing: 2
    readonly property int rowsHeight: calculateRowsHeight()
    readonly property int naturalWidth: calculateWidth()
    readonly property int naturalHeight: headerHeight
        + (headerHeight === 0 ? 0 : Theme.spaceXs)
        + Math.max(34, rowsHeight)

    implicitWidth: Math.max(188, Math.min(288, naturalWidth))
    implicitHeight: Math.min(368, naturalHeight)

    onMenuChanged: {
        resetSubmenus();
        if (opened) {
            Qt.callLater(focusFirstEntry);
        }
    }

    onOpenedChanged: {
        if (opened) {
            Qt.callLater(focusFirstEntry);
        } else {
            resetSubmenus();
        }
    }

    onCurrentEntriesChanged: {
        if (opened) {
            Qt.callLater(focusFirstEntry);
        }
    }

    Component {
        id: submenuOpenerComponent

        QsMenuOpener {}
    }

    QsMenuOpener {
        id: rootMenu
        menu: root.menu
    }

    FontMetrics {
        id: menuFontMetrics
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    function calculateRowsHeight() {
        let height = 0;
        for (let index = 0; index < currentEntries.length; index++) {
            height += currentEntries[index].isSeparator
                ? separatorHeight : entryHeight;
        }
        if (currentEntries.length > 1) {
            height += (currentEntries.length - 1) * listSpacing;
        }
        return height;
    }

    function calculateWidth() {
        let labelWidth = submenuStack.length === 0
            ? 0 : menuFontMetrics.advanceWidth(currentTitle) + 8;
        let hasSubmenu = false;
        for (let index = 0; index < currentEntries.length; index++) {
            const entry = currentEntries[index];
            if (entry.isSeparator) {
                continue;
            }
            labelWidth = Math.max(labelWidth, menuFontMetrics.advanceWidth(entry.text));
            hasSubmenu = hasSubmenu || entry.hasChildren;
        }

        return Math.ceil(34 + labelWidth + Theme.spaceSm + (hasSubmenu ? 18 : 0));
    }

    function accentFor(index) {
        const accents = [
            Theme.orange,
            Theme.blue,
            Theme.green,
        ];
        return accents[index % accents.length];
    }

    function translucent(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }

    function isSelectable(index) {
        if (index < 0 || index >= currentEntries.length) {
            return false;
        }
        const entry = currentEntries[index];
        return !entry.isSeparator && entry.enabled;
    }

    function selectableIndex(start, step) {
        for (let index = start; index >= 0 && index < currentEntries.length; index += step) {
            if (isSelectable(index)) {
                return index;
            }
        }
        return -1;
    }

    function focusIndex(index) {
        if (!isSelectable(index)) {
            return;
        }
        entryList.currentIndex = index;
        entryList.positionViewAtIndex(index, ListView.Contain);
        Qt.callLater(function() {
            if (entryList.currentItem !== null) {
                entryList.currentItem.forceActiveFocus(Qt.TabFocusReason);
            }
        });
    }

    function focusFirstEntry() {
        focusIndex(selectableIndex(0, 1));
    }

    function focusLastEntry() {
        focusIndex(selectableIndex(currentEntries.length - 1, -1));
    }

    function moveSelection(step) {
        const start = entryList.currentIndex < 0
            ? (step > 0 ? 0 : currentEntries.length - 1)
            : entryList.currentIndex + step;
        focusIndex(selectableIndex(start, step));
    }

    function resetSubmenus() {
        const openers = submenuStack;
        submenuStack = [];
        for (let index = openers.length - 1; index >= 0; index--) {
            openers[index].opener.destroy();
        }
        entryList.currentIndex = -1;
        entryList.positionViewAtBeginning();
    }

    function enterSubmenu(entry) {
        const opener = submenuOpenerComponent.createObject(root, { menu: entry });
        if (opener === null) {
            return;
        }

        const nextStack = submenuStack.slice();
        nextStack.push({ opener: opener, title: entry.text || "Menu" });
        submenuStack = nextStack;
        entryList.positionViewAtBeginning();
        Qt.callLater(focusFirstEntry);
    }

    function leaveSubmenu() {
        if (submenuStack.length === 0) {
            return;
        }

        const nextStack = submenuStack.slice();
        const current = nextStack.pop();
        submenuStack = nextStack;
        current.opener.destroy();
        entryList.positionViewAtBeginning();
        Qt.callLater(focusFirstEntry);
    }

    function activateEntry(entry) {
        if (entry === null || entry.isSeparator || !entry.enabled) {
            return;
        }
        if (entry.hasChildren) {
            enterSubmenu(entry);
            return;
        }

        entry.triggered();
        dismissRequested();
    }

    function activateCurrent() {
        if (isSelectable(entryList.currentIndex)) {
            activateEntry(currentEntries[entryList.currentIndex]);
        }
    }

    Keys.onPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Up:
            root.moveSelection(-1);
            break;
        case Qt.Key_Down:
            root.moveSelection(1);
            break;
        case Qt.Key_Home:
            root.focusFirstEntry();
            break;
        case Qt.Key_End:
            root.focusLastEntry();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.activateCurrent();
            break;
        case Qt.Key_Right:
            if (root.isSelectable(entryList.currentIndex)
                    && root.currentEntries[entryList.currentIndex].hasChildren) {
                root.activateCurrent();
            }
            break;
        case Qt.Key_Left:
        case Qt.Key_Backspace:
            root.leaveSubmenu();
            break;
        case Qt.Key_Escape:
            root.dismissRequested();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Column {
        anchors.fill: parent
        spacing: root.headerHeight === 0 ? 0 : Theme.spaceXs

        Rectangle {
            id: backRow

            width: parent.width
            height: root.headerHeight
            visible: root.headerHeight > 0
            radius: Theme.radiusSmall
            color: activeFocus || backHover.hovered ? Theme.overlay : "transparent"
            activeFocusOnTab: visible
            Accessible.name: "Back"
            Accessible.description: root.currentTitle
            Accessible.role: Accessible.Button
            Accessible.onPressAction: root.leaveSubmenu()

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentTitle
                color: Theme.textBright
                elide: Text.ElideRight
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: backHover
            }

            TapHandler {
                onTapped: root.leaveSubmenu()
            }

            Keys.onReturnPressed: function(event) {
                root.leaveSubmenu();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                root.leaveSubmenu();
                event.accepted = true;
            }
        }

        Item {
            width: parent.width
            height: parent.height - root.headerHeight
                - (root.headerHeight === 0 ? 0 : parent.spacing)

            ListView {
                id: entryList

                anchors.fill: parent
                anchors.rightMargin: scrollTrack.visible ? Theme.spaceSm : 0
                clip: true
                spacing: root.listSpacing
                model: root.currentChildren
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1

                delegate: Rectangle {
                    id: menuRow

                    required property var modelData
                    required property int index
                    readonly property bool isEntry: !modelData.isSeparator
                    readonly property bool checked: modelData.checkState === Qt.Checked
                    readonly property bool partiallyChecked: modelData.checkState === Qt.PartiallyChecked
                    readonly property color accent: root.accentFor(index)

                    width: entryList.width
                    height: modelData.isSeparator
                        ? root.separatorHeight : root.entryHeight
                    radius: Theme.radiusSmall
                    color: !isEntry || !modelData.enabled
                        ? "transparent"
                        : (activeFocus || entryHover.hovered
                            ? Theme.overlay : "transparent")
                    opacity: modelData.enabled ? 1 : 0.45
                    activeFocusOnTab: isEntry && modelData.enabled
                    Accessible.name: isEntry ? modelData.text : ""
                    Accessible.role: isEntry ? Accessible.MenuItem : Accessible.NoRole
                    Accessible.onPressAction: {
                        if (isEntry) {
                            root.activateEntry(modelData);
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            entryList.currentIndex = index;
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
                        id: indicator

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        visible: menuRow.isEntry
                            && menuRow.modelData.buttonType !== QsMenuButtonType.None
                        radius: menuRow.modelData.buttonType === QsMenuButtonType.RadioButton
                            ? 7 : 3
                        color: menuRow.modelData.buttonType === QsMenuButtonType.CheckBox
                                && (menuRow.checked || menuRow.partiallyChecked)
                            ? menuRow.accent : "transparent"
                        border.width: 1
                        border.color: menuRow.checked || menuRow.partiallyChecked
                            ? menuRow.accent : Theme.textMuted

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            visible: menuRow.modelData.buttonType === QsMenuButtonType.RadioButton
                                && menuRow.checked
                            color: menuRow.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: menuRow.modelData.buttonType === QsMenuButtonType.CheckBox
                                && menuRow.checked
                            text: "✓"
                            color: Theme.background
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 7
                            height: 2
                            visible: menuRow.modelData.buttonType === QsMenuButtonType.CheckBox
                                && menuRow.partiallyChecked
                            color: Theme.background
                        }
                    }

                    Image {
                        id: entryIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        visible: menuRow.isEntry
                            && menuRow.modelData.buttonType === QsMenuButtonType.None
                            && source.toString() !== ""
                        source: menuRow.isEntry ? menuRow.modelData.icon : ""
                        sourceSize.width: 16
                        sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            colorization: 1
                            colorizationColor: menuRow.accent
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.right: submenuMarker.left
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        visible: menuRow.isEntry
                        text: menuRow.isEntry ? menuRow.modelData.text : ""
                        color: menuRow.activeFocus || entryHover.hovered
                            ? Theme.textBright : Theme.text
                        elide: Text.ElideRight
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                    }

                    Text {
                        id: submenuMarker

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        visible: menuRow.isEntry && menuRow.modelData.hasChildren
                        text: "›"
                        color: menuRow.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeHeading
                    }

                    HoverHandler {
                        id: entryHover
                        enabled: menuRow.isEntry && menuRow.modelData.enabled

                        onHoveredChanged: {
                            if (hovered) {
                                entryList.currentIndex = menuRow.index;
                            }
                        }
                    }

                    TapHandler {
                        enabled: menuRow.isEntry && menuRow.modelData.enabled
                        onTapped: root.activateEntry(menuRow.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.currentEntries.length === 0
                    text: "No actions available"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Rectangle {
                id: scrollTrack

                anchors.top: parent.top
                anchors.right: parent.right
                width: 3
                height: parent.height
                radius: 2
                visible: entryList.contentHeight > entryList.height
                color: Theme.container

                Rectangle {
                    width: parent.width
                    height: Math.max(20, entryList.visibleArea.heightRatio * parent.height)
                    y: entryList.visibleArea.yPosition * parent.height
                    radius: 2
                    color: Theme.overlay
                }
            }
        }
    }
}
