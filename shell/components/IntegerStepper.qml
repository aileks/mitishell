pragma ComponentBehavior: Bound

import QtQuick

// A bounded integer stepper with optimistic local state. The caller owns
// persistence and reports completion through markSaved or markFailed.
Item {
    id: root

    required property string label
    required property int value
    required property int from
    required property int to
    required property int controlHeight
    required property int spacing
    required property string labelFontFamily
    required property int labelFontSize
    required property string valueFontFamily
    required property int valueFontSize
    required property string buttonFontFamily
    required property int buttonFontSize
    required property color textColor
    required property color valueColor
    required property color pendingColor
    required property color buttonColor
    required property color hoverColor
    required property color pressedColor
    required property color borderColor
    required property color focusColor

    property int draftValue: value
    property bool pending: false

    readonly property bool canDecrement: draftValue > from
    readonly property bool canIncrement: draftValue < to

    signal valueQueued(int value)

    implicitHeight: controlHeight

    function step(delta) {
        const next = Math.max(root.from, Math.min(root.to, root.draftValue + delta));
        if (next === root.draftValue) return;
        root.draftValue = next;
        root.pending = true;
        root.valueQueued(next);
    }

    function decrement() {
        step(-1);
    }

    function increment() {
        step(1);
    }

    function markSaved(savedValue) {
        if (savedValue === root.draftValue) root.pending = false;
    }

    function markFailed(savedValue) {
        if (savedValue !== root.draftValue) return;
        root.pending = false;
        root.draftValue = root.value;
    }

    onValueChanged: {
        if (!pending) draftValue = value;
    }

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.textColor
        font.family: root.labelFontFamily
        font.pixelSize: root.labelFontSize
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        FocusScope {
            id: decrementButton

            objectName: "decrementButton"
            width: root.controlHeight
            height: root.controlHeight
            enabled: root.canDecrement
            activeFocusOnTab: enabled
            Accessible.name: "Decrease " + root.label.toLowerCase()
            Accessible.role: Accessible.Button
            Accessible.onPressAction: activate()

            function activate() {
                if (enabled) root.decrement();
            }

            Rectangle {
                anchors.fill: parent
                color: decrementPress.pressed ? root.pressedColor
                    : (decrementButton.activeFocus || decrementHover.hovered
                        ? root.hoverColor : root.buttonColor)
                border.width: decrementButton.activeFocus ? 2 : 1
                border.color: decrementButton.activeFocus ? root.focusColor : root.borderColor
                opacity: decrementButton.enabled ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    color: root.valueColor
                    font.family: root.buttonFontFamily
                    font.pixelSize: root.buttonFontSize
                }

                HoverHandler {
                    id: decrementHover
                    cursorShape: Qt.PointingHandCursor
                }
            }

            TapHandler {
                id: decrementPress
                enabled: decrementButton.enabled
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: decrementButton.activate()
            }

            Keys.onReturnPressed: function(event) {
                decrementButton.activate();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                decrementButton.activate();
                event.accepted = true;
            }
        }

        Text {
            width: root.controlHeight
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: String(root.draftValue)
            color: root.pending ? root.pendingColor : root.valueColor
            font.family: root.valueFontFamily
            font.pixelSize: root.valueFontSize
        }

        FocusScope {
            id: incrementButton

            objectName: "incrementButton"
            width: root.controlHeight
            height: root.controlHeight
            enabled: root.canIncrement
            activeFocusOnTab: enabled
            Accessible.name: "Increase " + root.label.toLowerCase()
            Accessible.role: Accessible.Button
            Accessible.onPressAction: activate()

            function activate() {
                if (enabled) root.increment();
            }

            Rectangle {
                anchors.fill: parent
                color: incrementPress.pressed ? root.pressedColor
                    : (incrementButton.activeFocus || incrementHover.hovered
                        ? root.hoverColor : root.buttonColor)
                border.width: incrementButton.activeFocus ? 2 : 1
                border.color: incrementButton.activeFocus ? root.focusColor : root.borderColor
                opacity: incrementButton.enabled ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: root.valueColor
                    font.family: root.buttonFontFamily
                    font.pixelSize: root.buttonFontSize
                }

                HoverHandler {
                    id: incrementHover
                    cursorShape: Qt.PointingHandCursor
                }
            }

            TapHandler {
                id: incrementPress
                enabled: incrementButton.enabled
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: incrementButton.activate()
            }

            Keys.onReturnPressed: function(event) {
                incrementButton.activate();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                incrementButton.activate();
                event.accepted = true;
            }
        }
    }
}
