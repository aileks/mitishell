pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"
import "../lib/EmojiModel.js" as EmojiModel

PanelWindow {
    id: root

    required property var modelData

    readonly property bool open: SurfaceCoordinator.activeKey === "emoji"
        && SurfaceCoordinator.originScreen === modelData
    property string query: ""
    property string category: EmojiModel.smileysCategory
    property var results: []
    property int selectedIndex: 0
    readonly property int cellSize: 50
    readonly property int columns: Math.max(1, Math.floor(resultGrid.width / cellSize))

    function rebuild() {
        results = Emoji.entries(query, category);
        selectedIndex = results.length === 0
            ? 0 : Math.max(0, Math.min(selectedIndex, results.length - 1));
        Qt.callLater(function() {
            if (results.length > 0) {
                resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            }
        });
    }

    function setQuery(nextQuery) {
        query = String(nextQuery || "");
        selectedIndex = 0;
        rebuild();
    }

    function selectCategory(nextCategory) {
        category = nextCategory;
        query = "";
        selectedIndex = 0;
        rebuild();
        keyLayer.forceActiveFocus(Qt.TabFocusReason);
    }

    function selectLinear(delta) {
        selectedIndex = EmojiModel.selectLinear(selectedIndex, delta, results.length);
        resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function selectRow(delta) {
        selectedIndex = EmojiModel.selectRow(
            selectedIndex, delta, columns, results.length);
        resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function selectPage(delta) {
        const visibleRows = Math.max(1, Math.floor(resultGrid.height / cellSize));
        selectedIndex = EmojiModel.selectPage(
            selectedIndex, delta, columns, visibleRows, results.length);
        resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function activate(index) {
        if (index < 0 || index >= results.length) return;
        const selected = results[index].e;
        Quickshell.clipboardText = selected;
        Emoji.addRecent(selected);
        SurfaceCoordinator.close();
    }

    function dismiss() {
        if (query !== "") {
            setQuery("");
            keyLayer.forceActiveFocus(Qt.TabFocusReason);
        } else {
            SurfaceCoordinator.close();
        }
    }

    function focusCategory(index) {
        const candidate = categoryRepeater.itemAt(index);
        if (candidate !== null) candidate.forceActiveFocus(Qt.TabFocusReason);
    }

    screen: modelData
    visible: root.open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-emoji"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open
        ? (focusPrime.running ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property Timer focusPrime: Timer {
        interval: 75
        running: root.open
    }

    onOpenChanged: {
        if (open) {
            query = "";
            category = Emoji.initialCategory();
            selectedIndex = 0;
            rebuild();
            Qt.callLater(function() {
                keyLayer.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    Connections {
        target: Emoji
        function onCatalogChanged() { root.rebuild(); }
        function onRecentsChanged() { root.rebuild(); }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: SurfaceCoordinator.close()
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: SurfaceCoordinator.close()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.dismiss()
    }

    SurfaceFrame {
        id: card

        anchors.centerIn: parent
        width: Math.min(600, root.width - Theme.spaceXl * 2)
        height: Math.min(600, root.height - Theme.spaceXl * 2)
        floating: true
        accent: Theme.orange
        padding: Theme.spaceLg
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

        MouseArea { anchors.fill: parent }

        FocusScope {
            id: keyLayer

            anchors.fill: parent
            focus: true
            Keys.priority: Keys.AfterItem
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left) {
                    root.selectLinear(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.selectLinear(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.selectRow(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.selectRow(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.selectPage(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    root.selectPage(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activate(root.selectedIndex);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace) {
                    root.setQuery(root.query.slice(0, -1));
                    event.accepted = true;
                } else if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                        && event.text && event.text.length > 0
                        && event.text.charCodeAt(0) >= 32
                        && event.text.charCodeAt(0) !== 127) {
                    root.setQuery(root.query + event.text);
                    event.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                spacing: Theme.spaceMd

                Item {
                    width: parent.width
                    height: Theme.controlHeight

                    Text {
                        anchors.left: parent.left
                        anchors.right: clearButton.visible ? clearButton.left : parent.right
                        anchors.rightMargin: clearButton.visible ? Theme.spaceMd : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query !== "" ? root.query : "Search emojis…"
                        color: root.query !== "" ? Theme.textBright : Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeHeading
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        id: clearButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.query === "" && root.category === "recent"
                            && Emoji.recents.length > 0
                        label: "Clear recents"
                        destructive: true
                        onActivated: {
                            Emoji.clearRecents();
                            keyLayer.forceActiveFocus(Qt.TabFocusReason);
                        }
                    }
                }

                Row {
                    id: categoryStrip

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spaceXs

                    Repeater {
                        id: categoryRepeater
                        model: Emoji.categories

                        delegate: Rectangle {
                            id: categoryButton

                            required property var modelData
                            required property int index

                            width: 40
                            height: 36
                            radius: Theme.radiusMedium
                            color: root.query === "" && root.category === modelData.key
                                ? Theme.alpha(Theme.orange, 0.2)
                                : (activeFocus || hover.hovered ? Theme.hoverFill : "transparent")
                            border.width: activeFocus ? 2
                                : (root.query === "" && root.category === modelData.key ? 1 : 0)
                            border.color: activeFocus ? Theme.blue : Theme.orange
                            activeFocusOnTab: true
                            Accessible.name: modelData.label
                            Accessible.role: Accessible.Button
                            Accessible.onPressAction: root.selectCategory(modelData.key)

                            Text {
                                anchors.centerIn: parent
                                text: categoryButton.modelData.icon
                                color: Theme.textBright
                                font.family: categoryButton.index === 0
                                    ? Theme.fontMono : Theme.fontSans
                                font.pixelSize: Theme.fontSizeDisplay
                            }

                            HoverHandler { id: hover }
                            TapHandler {
                                onTapped: root.selectCategory(categoryButton.modelData.key)
                            }
                            Keys.onReturnPressed: function(event) {
                                root.selectCategory(categoryButton.modelData.key);
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: function(event) {
                                root.selectCategory(categoryButton.modelData.key);
                                event.accepted = true;
                            }
                            Keys.onLeftPressed: function(event) {
                                root.focusCategory(Math.max(0, categoryButton.index - 1));
                                event.accepted = true;
                            }
                            Keys.onRightPressed: function(event) {
                                root.focusCategory(Math.min(
                                    Emoji.categories.length - 1, categoryButton.index + 1));
                                event.accepted = true;
                            }
                            Keys.onDownPressed: function(event) {
                                keyLayer.forceActiveFocus(Qt.TabFocusReason);
                                event.accepted = true;
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - Theme.controlHeight - categoryStrip.height
                        - 2 * parent.spacing

                    GridView {
                        id: resultGrid

                        anchors.fill: parent
                        model: root.results
                        clip: true
                        cellWidth: root.cellSize
                        cellHeight: root.cellSize
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: emojiCell

                            required property var modelData
                            required property int index

                            width: root.cellSize
                            height: root.cellSize
                            radius: Theme.radiusMedium
                            color: index === root.selectedIndex
                                ? Theme.alpha(Theme.orange, 0.2) : "transparent"
                            border.width: index === root.selectedIndex ? 1 : 0
                            border.color: keyLayer.activeFocus ? Theme.blue : Theme.orange
                            Accessible.name: modelData.k
                            Accessible.role: Accessible.Button

                            Text {
                                anchors.centerIn: parent
                                text: emojiCell.modelData.e
                                font.family: Theme.fontSans
                                font.pixelSize: 28
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (containsMouse) root.selectedIndex = emojiCell.index;
                                }
                                onClicked: root.activate(emojiCell.index)
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Theme.spaceSm
                        visible: root.results.length === 0

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Emoji.catalogError !== "" ? "󰅚" : "󰈉"
                            color: Emoji.catalogError !== "" ? Theme.red : Theme.orange
                            font.family: Theme.fontMono
                            font.pixelSize: 32
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Emoji.catalogError !== "" ? Emoji.catalogError
                                : (root.query !== ""
                                    ? "No matches for “" + root.query + "”"
                                    : (root.category === "recent"
                                        ? "No recent emojis" : "No emojis in this category"))
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeTitle
                            wrapMode: Text.Wrap
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: root.category === "recent"
                            && Emoji.persistenceError !== ""
                        text: Emoji.persistenceError.replace(/^mitishell: /, "")
                        color: Theme.yellow
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
