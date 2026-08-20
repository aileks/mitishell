import QtQuick
import "../core"
import "../lib/CalendarModel.js" as CalendarModel

FocusScope {
    id: root

    property var displayedMonth: ({
        "year": Clock.now.getFullYear(),
        "month": Clock.now.getMonth()
    })
    property var cursorDate: Clock.today

    focus: true

    function showMonth(delta) {
        const shifted = CalendarModel.shiftMonth(
            displayedMonth.year,
            displayedMonth.month,
            delta,
        );
        showSpecificMonth(shifted.year, shifted.month, delta);
    }

    function showSpecificMonth(year, month, direction) {
        displayedMonth = { "year": year, "month": month };
        monthGrid.opacity = 0;
        monthGrid.x = direction * 24;
        monthTransition.restart();
    }

    function moveCursor(days) {
        const next = CalendarModel.moveDate(cursorDate, days);
        const monthDelta = next.year === displayedMonth.year
            ? next.month - displayedMonth.month
            : (next.year - displayedMonth.year) * 12
                + next.month - displayedMonth.month;
        cursorDate = next;
        if (monthDelta !== 0) {
            showSpecificMonth(next.year, next.month, monthDelta > 0 ? 1 : -1);
        }
        Qt.callLater(focusCursor);
    }

    function returnToday() {
        const today = Clock.today;
        const direction = today.year * 12 + today.month
            >= displayedMonth.year * 12 + displayedMonth.month ? 1 : -1;
        cursorDate = today;
        showSpecificMonth(today.year, today.month, direction);
        Qt.callLater(focusCursor);
    }

    function focusCursor() {
        for (let index = 0; index < 42; index += 1) {
            const item = dayRepeater.itemAt(index);
            if (item !== null && CalendarModel.sameDate(item.modelData, cursorDate)) {
                item.forceActiveFocus(Qt.TabFocusReason);
                return;
            }
        }
    }

    function dayLabel(index) {
        const first = Clock.locale.firstDayOfWeek % 7;
        const day = (first + index) % 7;
        return Qt.formatDate(new Date(2026, 0, 4 + day, 12), "ddd");
    }

    ParallelAnimation {
        id: monthTransition

        NumberAnimation {
            target: monthGrid
            property: "x"
            to: 0
            duration: Motion.duration(Motion.normal)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: monthGrid
            property: "opacity"
            to: 1
            duration: Motion.duration(Motion.normal)
            easing.type: Easing.OutCubic
        }
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        Row {
            width: parent.width
            height: 32

            Rectangle {
                width: 32
                height: 32
                radius: Theme.radiusPill
                color: activeFocus || previousHover.hovered ? Theme.overlay : "transparent"
                activeFocusOnTab: true
                Accessible.name: "Previous month"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: root.showMonth(-1)

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: 20
                }
                HoverHandler { id: previousHover }
                TapHandler { onTapped: root.showMonth(-1) }
                Keys.onReturnPressed: function(event) {
                    root.showMonth(-1);
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.showMonth(-1);
                    event.accepted = true;
                }
            }

            Text {
                width: parent.width - 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(
                    new Date(root.displayedMonth.year, root.displayedMonth.month, 1, 12),
                    "MMMM yyyy",
                )
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: 32
                height: 32
                radius: Theme.radiusPill
                color: activeFocus || nextHover.hovered ? Theme.overlay : "transparent"
                activeFocusOnTab: true
                Accessible.name: "Next month"
                Accessible.role: Accessible.Button
                Accessible.onPressAction: root.showMonth(1)

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: 20
                }
                HoverHandler { id: nextHover }
                TapHandler { onTapped: root.showMonth(1) }
                Keys.onReturnPressed: function(event) {
                    root.showMonth(1);
                    event.accepted = true;
                }
                Keys.onSpacePressed: function(event) {
                    root.showMonth(1);
                    event.accepted = true;
                }
            }
        }

        Row {
            width: parent.width
            height: 20

            Repeater {
                model: 7

                delegate: Text {
                    required property int index
                    width: 40
                    text: root.dayLabel(index)
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }

        Grid {
            id: monthGrid

            width: parent.width
            height: 197
            columns: 7
            columnSpacing: 1
            rowSpacing: 1

            Repeater {
                id: dayRepeater

                model: CalendarModel.monthGrid(
                    root.displayedMonth.year,
                    root.displayedMonth.month,
                    Clock.locale.firstDayOfWeek,
                )

                delegate: Rectangle {
                    id: dayCell

                    required property var modelData
                    readonly property bool today: CalendarModel.sameDate(modelData, Clock.today)
                    readonly property bool cursor: CalendarModel.sameDate(modelData, root.cursorDate)

                    width: 40
                    height: 32
                    radius: Theme.radiusSmall
                    color: cursor ? Theme.orange
                        : (activeFocus || dayHover.hovered ? Theme.overlay : "transparent")
                    border.width: today && !cursor ? 1 : (activeFocus ? 2 : 0)
                    border.color: activeFocus ? Theme.blue : Theme.orange
                    activeFocusOnTab: true
                    Accessible.name: Qt.formatDate(
                        new Date(modelData.year, modelData.month, modelData.day, 12),
                        Locale.LongFormat,
                    )
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: activate()

                    function activate() {
                        root.cursorDate = modelData;
                        if (!modelData.inMonth) {
                            const direction = modelData.year * 12 + modelData.month
                                > root.displayedMonth.year * 12 + root.displayedMonth.month ? 1 : -1;
                            root.showSpecificMonth(modelData.year, modelData.month, direction);
                            Qt.callLater(root.focusCursor);
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            root.cursorDate = modelData;
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        color: dayCell.cursor ? Theme.background
                            : (dayCell.modelData.inMonth ? Theme.text : Theme.textMuted)
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: dayCell.today ? Font.DemiBold : Font.Normal
                    }

                    HoverHandler { id: dayHover }
                    TapHandler { onTapped: dayCell.activate() }

                    Keys.onLeftPressed: function(event) {
                        root.moveCursor(-1);
                        event.accepted = true;
                    }
                    Keys.onRightPressed: function(event) {
                        root.moveCursor(1);
                        event.accepted = true;
                    }
                    Keys.onUpPressed: function(event) {
                        root.moveCursor(-7);
                        event.accepted = true;
                    }
                    Keys.onDownPressed: function(event) {
                        root.moveCursor(7);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: function(event) {
                        dayCell.activate();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: function(event) {
                        dayCell.activate();
                        event.accepted = true;
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_PageUp) {
                            root.showMonth(-1);
                        } else if (event.key === Qt.Key_PageDown) {
                            root.showMonth(1);
                        } else if (event.key === Qt.Key_Home) {
                            root.returnToday();
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 34
            radius: Theme.radiusMedium
            color: activeFocus || todayHover.hovered ? Theme.overlay : Theme.container
            border.width: activeFocus ? 2 : 0
            border.color: Theme.blue
            activeFocusOnTab: true
            Accessible.name: "Go to today"
            Accessible.role: Accessible.Button
            Accessible.onPressAction: root.returnToday()

            Text {
                anchors.centerIn: parent
                text: "Today"
                color: Theme.textBright
                font.family: Theme.fontSans
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            HoverHandler { id: todayHover }
            TapHandler { onTapped: root.returnToday() }
            Keys.onReturnPressed: function(event) {
                root.returnToday();
                event.accepted = true;
            }
            Keys.onSpacePressed: function(event) {
                root.returnToday();
                event.accepted = true;
            }
        }
    }
}
