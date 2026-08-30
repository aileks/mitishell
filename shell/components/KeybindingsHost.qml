pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/KeybindingModel.js" as KeybindingModel
import "../lib/SearchModel.js" as SearchModel

SearchSurface {
    id: root

    surfaceKey: "keybinds"
    accent: Theme.blue
    placeholder: "Search keybinds..."
    activationEnabled: false
    emptyMessage: !Keybindings.loaded && Keybindings.busy
        ? "Loading keybinds…"
        : (!Keybindings.loaded && Keybindings.error !== ""
            ? "Keybinds unavailable" : "No matching keybinds")
    warning: Keybindings.stale ? Keybindings.error : ""
    rowDelegate: keybindRow

    function rebuild() {
        if (query.trim() === "") {
            results = KeybindingModel.groupBindings(Keybindings.bindings);
        } else {
            results = SearchModel.rank(Keybindings.bindings, query).map(function(entry) {
                const copy = Object.assign({}, entry);
                copy.groupLabel = "";
                return copy;
            });
        }
    }

    function badgesFor(entry) {
        const badges = entry.flags.slice();
        if (entry.submap !== "") badges.unshift(entry.submap);
        return badges;
    }

    onOpened: {
        rebuild();
        Keybindings.refresh();
    }
    onQueryChanged: rebuild()

    Connections {
        target: Keybindings
        function onBindingsChanged() { root.rebuild(); }
        function onLoadedChanged() { root.rebuild(); }
        function onBusyChanged() { root.rebuild(); }
        function onErrorChanged() { root.rebuild(); }
        function onStaleChanged() { root.rebuild(); }
    }

    Component {
        id: keybindRow

        Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool selected: ListView.view.currentIndex === index
            readonly property int headerHeight: modelData.groupLabel !== "" ? 22 : 0

            width: ListView.view.width
            height: Theme.controlHeightLg + headerHeight
            Accessible.name: modelData.shortcut + ", " + modelData.description
            Accessible.role: Accessible.StaticText

            Text {
                visible: row.modelData.groupLabel !== ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: row.headerHeight / 2
                text: row.modelData.groupLabel
                color: Theme.blue
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.controlHeightLg
                color: row.selected ? Theme.alpha(Theme.blue, 0.16) : "transparent"
                border.width: row.selected ? 1 : 0
                border.color: Theme.blue

                Text {
                    id: shortcutLabel

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceMd
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190
                    text: row.modelData.shortcut
                    color: Theme.textBright
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBodySmall
                    elide: Text.ElideRight
                }

                Column {
                    anchors.left: shortcutLabel.right
                    anchors.leftMargin: Theme.spaceMd
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceMd
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.description
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                        elide: Text.ElideRight
                    }

                    Row {
                        width: parent.width
                        height: visible ? 16 : 0
                        visible: badgeRepeater.count > 0
                        spacing: Theme.spaceXs
                        clip: true

                        Repeater {
                            id: badgeRepeater

                            model: root.badgesFor(row.modelData)

                            delegate: Rectangle {
                                id: badge

                                required property string modelData

                                width: badgeLabel.implicitWidth + Theme.spaceSm
                                height: 16
                                color: Theme.alpha(Theme.blue, 0.16)
                                border.width: 1
                                border.color: Theme.alpha(Theme.blue, 0.52)

                                Text {
                                    id: badgeLabel

                                    anchors.centerIn: parent
                                    text: badge.modelData
                                    color: Theme.blue
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeCaption
                                }
                            }
                        }
                    }
                }
            }

            onSelectedChanged: if (selected) ListView.view.positionViewAtIndex(index, ListView.Contain)
        }
    }
}
