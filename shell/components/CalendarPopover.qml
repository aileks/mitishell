pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../lib/CalendarModel.js" as CalendarModel
import "../lib/ClockModel.js" as ClockModel

FocusScope {
    id: root

    property var displayedMonth: ({
        "year": Clock.now.getFullYear(),
        "month": Clock.now.getMonth()
    })
    property var cursorDate: Clock.today
    readonly property var weekNumbers: Config.calendar.showWeekNumbers
        ? ClockModel.rowWeekNumbers(CalendarModel.monthGrid(
            displayedMonth.year,
            displayedMonth.month,
            Clock.locale.firstDayOfWeek,
        )) : []
    readonly property int gutterWidth: Config.calendar.showWeekNumbers ? 24 : 0

    implicitWidth: 288 + (gutterWidth > 0 ? gutterWidth + Theme.spaceSm : 0)
    implicitHeight: content.implicitHeight

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
        const dates = CalendarModel.monthGrid(
            displayedMonth.year,
            displayedMonth.month,
            Clock.locale.firstDayOfWeek,
        );
        for (let index = 0; index < 42; index += 1) {
            if (CalendarModel.sameDate(dates[index], cursorDate)) {
                const item = dayRepeater.itemAt(index);
                if (item === null) return;
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
            easing.type: Motion.easingStandard
        }
        NumberAnimation {
            target: monthGrid
            property: "opacity"
            to: 1
            duration: Motion.duration(Motion.normal)
            easing.type: Motion.easingStandard
        }
    }

    Column {
        id: content

        width: root.width
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
                HoverHandler { id: previousHover; cursorShape: Qt.PointingHandCursor }
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
                font.pixelSize: Theme.fontSizeHeading
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
                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
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
            id: calendarGridRow

            width: parent.width
            height: calendarColumn.implicitHeight
            spacing: Theme.spaceSm

            Column {
                id: weekNumberColumn

                visible: root.gutterWidth > 0
                width: root.gutterWidth
                spacing: 1

                Item {
                    width: root.gutterWidth
                    height: visible ? 27 : 0
                    visible: root.gutterWidth > 0
                }

                Repeater {
                    model: root.weekNumbers

                    delegate: Text {
                        required property var modelData

                        width: root.gutterWidth
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }
            }

            Column {
                id: calendarColumn

                width: 286
                spacing: Theme.spaceSm

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
                            font.pixelSize: Theme.fontSizeCaption
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
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: dayCell.today ? Font.DemiBold : Font.Normal
                            }

                            HoverHandler { id: dayHover; cursorShape: Qt.PointingHandCursor }
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
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.DemiBold
            }
            HoverHandler { id: todayHover; cursorShape: Qt.PointingHandCursor }
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

        ToggleRow {
            width: parent.width
            accent: Theme.blue
            label: "Week numbers"
            description: "Show ISO week numbers beside the month grid."
            checked: Config.calendar.showWeekNumbers
            onToggled: Settings.setField(
                "calendar.showWeekNumbers", checked ? "false" : "true")
        }

        Column {
            visible: Array.isArray(Config.clock.timezones)
                && Config.clock.timezones.length > 0
            width: parent.width
            spacing: Theme.spaceXs

            Text {
                text: "Elsewhere"
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Font.DemiBold
            }

            Repeater {
                model: Array.isArray(Config.clock.timezones)
                    ? Config.clock.timezones : []

                delegate: Row {
                    id: zoneRow

                    required property var modelData
                    readonly property int dayDelta: ClockModel.zoneDayDelta(Clock.now, modelData)

                    width: root.width
                    height: 26
                    spacing: Theme.spaceSm
                    Accessible.name: ClockModel.zoneLabel(modelData) + " "
                        + ClockModel.zoneClock(Clock.now, modelData)
                    Accessible.role: Accessible.StaticText

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - parent.spacing * 2 - 64 - 28
                        elide: Text.ElideRight
                        text: ClockModel.zoneLabel(zoneRow.modelData)
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSizeBody
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: zoneRow.dayDelta !== 0
                        text: zoneRow.dayDelta > 0 ? "+1" : "-1"
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        horizontalAlignment: Text.AlignRight
                        text: ClockModel.zoneClock(Clock.now, zoneRow.modelData)
                        color: Theme.textBright
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }
            }
        }
    }
}
