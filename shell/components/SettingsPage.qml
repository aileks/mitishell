pragma ComponentBehavior: Bound

import QtQuick
import "../core"

// Persistent Mitishell preferences, hosted as the Settings surface's System page.
Flickable {
    id: root

    acceptedButtons: Qt.NoButton
    contentWidth: width
    contentHeight: settingsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: settingsColumn

        width: root.width
        spacing: Theme.spaceMd

        SurfaceHeader {
            width: parent.width
            title: "System"
            accent: Theme.blue
        }

        InlineStatus {
            width: parent.width
            visible: Config.error !== ""
            message: "Configuration invalid. Built-in defaults are in use."
            textSize: Theme.fontSizeCaption
        }

        SectionCard {
            width: parent.width
            title: "Bar"
            accent: Theme.orange

            Column {
                width: parent.width
                spacing: Theme.spaceMd

                SettingsNumberRow {
                    width: parent.width
                    label: "Height"
                    fieldKey: "bar.height"
                    value: Config.bar.height
                    from: 24
                    to: 96
                }

                SettingsNumberRow {
                    width: parent.width
                    label: "Top margin"
                    fieldKey: "bar.marginTop"
                    value: Config.bar.marginTop
                    from: 0
                    to: 64
                }

                SettingsNumberRow {
                    width: parent.width
                    label: "Side margin"
                    fieldKey: "bar.marginHorizontal"
                    value: Config.bar.marginHorizontal
                    from: 0
                    to: 64
                }

                SettingsChoiceRow {
                    width: parent.width
                    label: "System metrics"
                    fieldKey: "bar.systemMetrics"
                    value: Config.bar.systemMetrics
                    choices: [
                        { value: "separate", label: "Separate" },
                        { value: "combined", label: "Combined" },
                    ]
                }

                SettingsBarLayout {
                    width: parent.width
                }

                SettingsOutputsRow {
                    width: parent.width
                }
            }
        }

        SectionCard {
            width: parent.width
            title: "Clock & Calendar"
            accent: Theme.blue

            Column {
                width: parent.width
                spacing: Theme.spaceMd

                SettingsChoiceRow {
                    width: parent.width
                    label: "Format"
                    fieldKey: "clock.format"
                    value: Config.clock.format
                    choices: [
                        { value: "auto", label: "Locale" },
                        { value: "24h", label: "24-hour" },
                        { value: "12h", label: "12-hour" },
                        { value: "24h-seconds", label: "24-hour + seconds" },
                        { value: "12h-seconds", label: "12-hour + seconds" },
                    ]
                }

                ToggleRow {
                    width: parent.width
                    accent: Theme.blue
                    label: "Date"
                    description: "Show the date beside the clock."
                    checked: Config.clock.showDate
                    onToggled: Settings.setField(
                        "clock.showDate", checked ? "false" : "true")
                }

                ToggleRow {
                    width: parent.width
                    accent: Theme.blue
                    label: "Week numbers"
                    description: "Show ISO week numbers in the calendar."
                    checked: Config.calendar.showWeekNumbers
                    onToggled: Settings.setField(
                        "calendar.showWeekNumbers", checked ? "false" : "true")
                }

                SettingsTimezonesRow {
                    width: parent.width
                }
            }
        }

        SectionCard {
            width: parent.width
            title: "Weather"
            accent: Theme.cyan

            Column {
                width: parent.width
                spacing: Theme.spaceMd

                ToggleRow {
                    width: parent.width
                    accent: Theme.blue
                    label: "Enabled"
                    description: "Fetches forecasts from wttr.in using automatic or manual location."
                    checked: Config.weather.enabled
                    onToggled: Settings.setField(
                        "weather.enabled", checked ? "false" : "true")
                }

                SettingsChoiceRow {
                    width: parent.width
                    label: "Units"
                    fieldKey: "weather.units"
                    value: Config.weather.units
                    choices: [
                        { value: "auto", label: "Auto" },
                        { value: "celsius", label: "Celsius" },
                        { value: "fahrenheit", label: "Fahrenheit" },
                    ]
                }

                WeatherLocationEditor {
                    width: parent.width
                }
            }
        }

        SectionCard {
            width: parent.width
            title: "Motion"
            accent: Theme.blue

            Column {
                width: parent.width
                spacing: Theme.spaceMd

                ToggleRow {
                    width: parent.width
                    accent: Theme.blue
                    label: "Animations"
                    description: "Animate popovers, popups, and island changes."
                    checked: Config.motion.enabled
                    onToggled: Settings.setField(
                        "motion.enabled", checked ? "false" : "true")
                }

                ToggleRow {
                    width: parent.width
                    accent: Theme.blue
                    label: "Reduced motion"
                    description: "Shortens animations when they stay enabled."
                    checked: Config.motion.reduced
                    onToggled: Settings.setField(
                        "motion.reduced", checked ? "false" : "true")
                }
            }
        }
    }
}
