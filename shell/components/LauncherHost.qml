pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../lib/Calculator.js" as Calculator
import "../lib/LauncherModel.js" as LauncherModel
import "../lib/SearchModel.js" as SearchModel

SearchSurface {
    id: root

    surfaceKey: "launcher"
    accent: Theme.orange
    placeholder: "Launcher"
    emptyMessage: query.charAt(0) === "=" ? "Invalid expression" : "No matching applications"
    warning: Launcher.persistenceError
    rowDelegate: launcherRow

    function rebuild() {
        const calculation = Calculator.fromQuery(query);
        if (calculation !== null) {
            results = [{
                id: "calculator",
                source: calculation.ok ? "calculator" : "calculator-error",
                label: calculation.ok ? calculation.text : calculation.error,
                detail: calculation.ok ? "Copy result" : "Calculator",
                icon: calculation.ok ? Icons.check : Icons.circleAlert,
                keywords: [],
            }];
            return;
        }

        const actions = Launcher.nativeActions();
        const entries = Launcher.applications.concat(actions);
        results = query.trim() === ""
            ? LauncherModel.blankEntries(Launcher.applications, actions, Launcher.recents)
            : SearchModel.rank(entries, query);
    }

    function activate(entry) {
        if (entry.source === "calculator") {
            Quickshell.clipboardText = entry.label;
            SurfaceCoordinator.close();
            return;
        }
        if (entry.source === "calculator-error") return;
        if (entry.source === "application") {
            Launcher.recordLaunch(entry.desktopId);
            SurfaceCoordinator.close();
            entry.desktopEntry.execute();
            return;
        }

        const action = entry.action || {};
        if (action.type === "settings") {
            Control.selectPage(action.target);
            SurfaceCoordinator.open("settings", root.modelData);
        } else if (action.type === "surface") {
            if (action.target === "reminders") Reminders.refresh();
            SurfaceCoordinator.open(action.target, root.modelData);
        } else if (action.type === "dnd") {
            Notifications.toggleDoNotDisturb();
            SurfaceCoordinator.close();
        } else if (action.type === "night-light") {
            NightLight.toggle();
            SurfaceCoordinator.close();
        }
    }

    onOpened: rebuild()
    onQueryChanged: rebuild()
    onActivateRequested: function(entry) { root.activate(entry); }

    Connections {
        target: Launcher
        function onApplicationsChanged() { root.rebuild(); }
        function onRecentsChanged() { root.rebuild(); }
        function onPersistenceErrorChanged() { root.rebuild(); }
    }

    Connections {
        target: Notifications
        function onDoNotDisturbChanged() { root.rebuild(); }
    }

    Connections {
        target: NightLight
        function onAvailableChanged() { root.rebuild(); }
        function onEnabledChanged() { root.rebuild(); }
    }

    Connections {
        target: Reminders
        function onAvailableChanged() { root.rebuild(); }
    }

    Component {
        id: launcherRow

        Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool selected: ListView.view.currentIndex === index
            readonly property bool actionable: modelData.source !== "calculator-error"

            width: ListView.view.width
            height: Theme.controlHeightLg
            color: selected ? Theme.alpha(Theme.orange, 0.18)
                : (hover.hovered && actionable ? Theme.hoverFill : "transparent")
            border.width: selected ? 1 : 0
            border.color: Theme.orange
            Accessible.name: modelData.label + ", " + modelData.detail
            Accessible.role: actionable ? Accessible.Button : Accessible.StaticText
            Accessible.onPressAction: root.activateIndex(index)

            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceMd

                Image {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconMd
                    height: Theme.iconMd
                    visible: row.modelData.source === "application"
                    source: visible
                        ? Quickshell.iconPath(row.modelData.icon, true)
                        : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                IconLabel {
                    id: actionIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.source !== "application"
                    value: row.modelData.icon
                    size: Theme.iconMd
                }

                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: Theme.spaceMd
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.label
                        color: row.actionable ? Theme.textBright : Theme.red
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: row.modelData.detail
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeCaption
                        elide: Text.ElideRight
                    }
                }
            }

            HoverHandler {
                id: hover
                enabled: row.actionable
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                enabled: row.actionable
                onTapped: root.activateIndex(row.index)
            }
            onSelectedChanged: if (selected) ListView.view.positionViewAtIndex(index, ListView.Contain)
        }
    }
}
