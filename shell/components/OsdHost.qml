import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../lib/OsdModel.js" as OsdModel

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    required property var modelData
    readonly property bool focused: modelData !== null
        && Osd.open && Osd.screenName === modelData.name
    readonly property var iconLayout: OsdModel.iconCandidate(Osd.icon)
    readonly property bool themeIconAvailable: iconLayout.kind === "theme"
        && Quickshell.hasThemeIcon(iconLayout.value)
    readonly property string iconImageSource: {
        if (iconLayout.kind === "image") {
            return iconLayout.value;
        }
        if (iconLayout.kind === "bundled") {
            return "../assets/icons/" + iconLayout.value + ".svg";
        }
        if (themeIconAvailable) {
            return Quickshell.iconPath(iconLayout.value, true);
        }
        return "";
    }

    screen: modelData
    visible: focused || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "mitishell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    SurfaceFrame {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        width: content.implicitWidth + padding * 2
        height: content.implicitHeight + padding * 2
        padding: Theme.spaceMd
        cornerRadius: Osd.message !== "" && Osd.hasProgress
            ? Theme.radiusLarge
            : Theme.radiusPill
        fill: Theme.layerRaised
        accent: Osd.accent
        floating: true
        opacity: root.focused ? 1 : 0

        transform: Translate {
            y: root.focused ? 0 : Theme.spaceMd

            Behavior on y {
                NumberAnimation {
                    duration: Motion.duration(Motion.quick)
                    easing.type: Motion.easingStandard
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Motion.quick)
                easing.type: Motion.easingStandard
            }
        }

        Row {
            id: content

            spacing: Theme.spaceMd

            Item {
                id: iconSlot

                visible: root.iconLayout.kind !== "none"
                anchors.verticalCenter: parent.verticalCenter
                width: iconImage.visible
                    ? Theme.iconLg
                    : Math.min(180, iconFallback.implicitWidth)
                height: Theme.iconLg

                Image {
                    id: iconImage

                    visible: source.toString() !== "" && status !== Image.Error
                    anchors.centerIn: parent
                    width: Theme.iconLg
                    height: Theme.iconLg
                    source: root.iconImageSource
                    sourceSize.width: Theme.iconLg
                    sourceSize.height: Theme.iconLg
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Text {
                    id: iconFallback

                    visible: !iconImage.visible
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 180)
                    text: root.iconLayout.kind === "text"
                        ? root.iconLayout.value
                        : root.iconLayout.fallback
                    elide: Text.ElideRight
                    color: Osd.accent
                    font.family: Theme.fontMono
                    font.pixelSize: text.length > 2
                        ? Theme.fontSizeBody
                        : Theme.iconLg
                }
            }

            Column {
                id: stateContent

                visible: Osd.message !== "" || Osd.hasProgress
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(
                    messageText.visible ? messageText.width : 0,
                    progressContent.visible ? progressContent.width : 0,
                )
                spacing: Theme.spaceSm

                Text {
                    id: messageText

                    visible: Osd.message !== ""
                    width: Math.min(implicitWidth, 320)
                    text: Osd.message
                    color: Theme.textBright
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Osd.hasProgress ? Font.DemiBold : Font.Normal
                    wrapMode: Text.Wrap
                }

                Row {
                    id: progressContent

                    visible: Osd.hasProgress
                    spacing: Theme.spaceSm

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 144
                        height: 6
                        radius: 0
                        color: Theme.overlay

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: Math.round(parent.width * Osd.progress)
                            radius: 0
                            color: Osd.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: Motion.duration(Motion.quick)
                                    easing.type: Motion.easingStandard
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        width: 44
                        text: Osd.label
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }
            }
        }
    }
}
