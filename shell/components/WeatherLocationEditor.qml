import QtQuick
import "../core"

Column {
    id: root

    property string draft: Config.weather.location || ""
    // The config value this editor last saw. External changes adopt the
    // new value only while no unsaved draft exists, so they can never
    // clobber text the user is entering.
    property string lastSeenLocation: Config.weather.location || ""
    readonly property string error: Settings.fieldErrors["weather.location"] || ""

    width: parent ? parent.width : 320
    spacing: Theme.spaceXs

    function apply() {
        Settings.setField("weather.location", draft.trim());
    }

    function automatic() {
        draft = "";
        Settings.setField("weather.location", "");
    }

    Text {
        text: "Location"
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        width: parent.width
        text: "Leave empty to let wttr.in detect a rough location from the network."
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSizeCaption
    }

    Rectangle {
        width: parent.width
        height: 32
        radius: Theme.radiusSmall
        color: Theme.layerInset
        border.width: locationInput.activeFocus ? 2 : 1
        border.color: locationInput.activeFocus ? Theme.blue : Theme.borderStrong

        TextInput {
            id: locationInput

            anchors.fill: parent
            anchors.leftMargin: Theme.spaceSm
            anchors.rightMargin: Theme.spaceSm
            clip: true
            text: root.draft
            color: Theme.textBright
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSizeBodySmall
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnTab: true
            Accessible.name: "Weather location"
            onTextEdited: root.draft = text
            onAccepted: root.apply()

            Text {
                anchors.fill: parent
                visible: locationInput.text === ""
                text: "Automatic location"
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeBodySmall
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Row {
        spacing: Theme.spaceSm
        ActionButton { label: "Apply"; onActivated: root.apply() }
        ActionButton { label: "Auto"; enabled: root.draft !== "" || Config.weather.location !== ""; onActivated: root.automatic() }
    }

    InlineStatus {
        width: parent.width
        visible: root.error !== ""
        message: root.error
        textSize: Theme.fontSizeCaption
    }

    Connections {
        target: Config
        function onWeatherChanged() {
            const location = Config.weather.location || "";
            if (root.draft === root.lastSeenLocation) {
                root.draft = location;
            }
            root.lastSeenLocation = location;
        }
    }
}
