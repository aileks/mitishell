pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../core"
import "../lib/SearchModel.js" as SearchModel

// Shared focused-output shell for compact searchable lists. Callers own
// result construction and row rendering; this component owns focus, motion,
// search input, selection, dismissal, and bounded top placement.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData
    required property string surfaceKey
    required property color accent
    required property Component rowDelegate
    property var results: []
    property string placeholder: "Search…"
    property string emptyMessage: "No matches"
    property string warning: ""
    property bool activationEnabled: true
    property bool backEnabled: false
    property alias query: searchInput.text

    readonly property bool open: SurfaceCoordinator.activeKey === surfaceKey
        && SurfaceCoordinator.originScreen === modelData
    readonly property int resultViewportHeight: Theme.controlHeightLg * 6
        + Theme.spaceXs * 5
    readonly property int panelTopMargin: Config.bar.marginTop + Config.bar.height
        + Theme.spaceLg
    readonly property int warningHeight: warningText.visible
        ? warningText.implicitHeight + Theme.spaceMd : 0
    readonly property int panelChromeHeight: Theme.spaceLg * 2
        + Theme.controlHeight + Theme.spaceMd + warningHeight
    readonly property int availablePanelHeight: Math.max(
        0,
        height - panelTopMargin - Theme.spaceXl,
    )
    readonly property int viewportHeight: Math.max(
        0,
        Math.min(resultViewportHeight, availablePanelHeight - panelChromeHeight),
    )

    signal opened()
    // Emitted once the close fade has finished and the window is hidden, so
    // callers can hand off to screen-taking tools without the surface in the
    // way. Fires immediately under reduced motion.
    signal fullyClosed()
    signal activateRequested(var entry)
    signal backRequested()
    signal deleteRequested(var entry)

    function focusSearch() {
        searchInput.forceActiveFocus(Qt.TabFocusReason);
    }

    function select(index) {
        if (results.length === 0) {
            resultList.currentIndex = -1;
            return;
        }
        resultList.currentIndex = Math.max(0, Math.min(index, results.length - 1));
        resultList.positionViewAtIndex(resultList.currentIndex, ListView.Contain);
    }

    function moveSelection(delta) {
        const count = results.length;
        if (count === 0) {
            resultList.currentIndex = -1;
            return;
        }
        select(SearchModel.wrapIndex(
            (resultList.currentIndex < 0 ? 0 : resultList.currentIndex) + delta,
            count,
        ));
    }

    function activateIndex(index) {
        if (!activationEnabled || index < 0 || index >= results.length) return;
        activateRequested(results[index]);
    }

    screen: modelData
    visible: root.open || frame.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "mitishell-" + surfaceKey
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
            searchInput.text = "";
            root.opened();
            root.select(0);
            Qt.callLater(function() {
                searchInput.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    onVisibleChanged: if (!visible) root.fullyClosed()

    onResultsChanged: root.select(Math.max(0, resultList.currentIndex))

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
        onActivated: SurfaceCoordinator.close()
    }

    SurfaceFrame {
        id: frame

        anchors.top: parent.top
        anchors.topMargin: root.panelTopMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, Math.min(560, root.width - Theme.spaceXl * 2))
        height: Math.min(
            root.availablePanelHeight,
            root.panelChromeHeight + root.viewportHeight,
        )
        clip: true
        floating: true
        accent: root.accent
        padding: Theme.spaceLg
        opacity: root.open ? 1 : 0

        transform: Translate {
            y: root.open ? 0 : -Theme.spaceMd

            Behavior on y {
                NumberAnimation {
                    duration: Motion.duration(Motion.entrance)
                    easing.type: Motion.easingStandard
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.entrance)
                easing.type: Motion.easingStandard
            }
        }

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            spacing: Theme.spaceMd

            Rectangle {
                id: searchBox

                width: parent.width
                height: Theme.controlHeight
                color: Theme.background
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.blue : Theme.borderStrong

                IconButton {
                    id: backButton

                    visible: root.backEnabled
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.controlHeightSm
                    height: Theme.controlHeightSm
                    iconSource: Icons.chevronLeft
                    accessibleName: "Back"
                    onClicked: root.backRequested()
                }

                TextInput {
                    id: searchInput

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: backButton.visible ? backButton.right : parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spaceMd
                    anchors.rightMargin: Theme.spaceMd
                    clip: true
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    activeFocusOnTab: true
                    Accessible.name: root.placeholder

                    onAccepted: root.activateIndex(resultList.currentIndex)
                    Keys.onDownPressed: function(event) {
                        root.moveSelection(1);
                        event.accepted = true;
                    }
                    Keys.onUpPressed: function(event) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    }
                    Keys.onDeletePressed: function(event) {
                        if (resultList.currentIndex >= 0
                                && resultList.currentIndex < root.results.length) {
                            root.deleteRequested(root.results[resultList.currentIndex]);
                        }
                        event.accepted = true;
                    }
                    Keys.onPressed: function(event) {
                        if (root.backEnabled && searchInput.text === ""
                                && (event.key === Qt.Key_Backspace
                                    || (event.key === Qt.Key_Left
                                        && (event.modifiers & Qt.AltModifier)))) {
                            root.backRequested();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            root.moveSelection(6);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            root.moveSelection(-6);
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.fill: parent
                        visible: searchInput.text === ""
                        text: root.placeholder
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                width: parent.width
                height: root.viewportHeight

                ListView {
                    id: resultList

                    anchors.fill: parent
                    visible: root.results.length > 0
                    model: root.results
                    delegate: root.rowDelegate
                    clip: true
                    spacing: Theme.spaceXs
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false
                    reuseItems: true
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceXl * 2
                    visible: root.results.length === 0
                    text: root.emptyMessage
                    color: root.warning !== "" ? Theme.yellow : Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            Text {
                id: warningText

                visible: root.warning !== ""
                width: parent.width
                text: root.warning.replace(/^mitishell: /, "")
                color: Theme.yellow
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                elide: Text.ElideRight
            }
        }
    }
}
