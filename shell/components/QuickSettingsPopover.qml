import QtQuick
import "../core"

Item {
    id: root

    required property var screen
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: Theme.spaceMd

        Text {
            text: "Quick Settings"
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Font.DemiBold
        }

        QuickControls {
            width: parent.width
            showVolume: false
        }

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            ActionButton {
                width: (parent.width - parent.spacing) / 2
                label: Reminders.count > 0
                    ? "Reminders " + Reminders.count : "New reminder"
                accent: Theme.pink
                onActivated: {
                    Reminders.refresh();
                    SurfaceCoordinator.open("reminders", root.screen);
                }
            }

            ActionButton {
                width: (parent.width - parent.spacing) / 2
                label: "Open Settings"
                onActivated: {
                    Control.selectPage("overview");
                    SurfaceCoordinator.open("settings", root.screen);
                }
            }
        }
    }
}
