pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string title: ""
    property string artist: ""
    property color titleColor: "white"
    property color artistColor: "gray"
    property color accentColor: "white"
    property string fontFamily: "sans-serif"
    property int titleFontSize: 14
    property int artistFontSize: 12
    property int horizontalPadding: 8
    property int itemSpacing: 4
    property bool animationsEnabled: true
    property bool reducedMotion: false
    property int initialPauseDuration: 1200
    property int endPauseDuration: 900
    property int returnDuration: 180

    readonly property alias viewport: metadataViewport
    readonly property real contentImplicitWidth: metadataViewport.contentImplicitWidth

    implicitWidth: metadataViewport.implicitWidth + horizontalPadding * 2
    implicitHeight: 30

    OverflowRow {
        id: metadataViewport
        objectName: "mediaMetadataViewport"

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        animationsEnabled: root.animationsEnabled
        reducedMotion: root.reducedMotion
        initialPauseDuration: root.initialPauseDuration
        endPauseDuration: root.endPauseDuration
        returnDuration: root.returnDuration
        fallback: Text {
            objectName: "staticMetadata"
            anchors.verticalCenter: parent.verticalCenter
            width: metadataViewport.width
            text: root.title + (root.artist !== "" ? " • " + root.artist : "")
            elide: Text.ElideRight
            color: root.titleColor
            font.family: root.fontFamily
            font.pixelSize: root.titleFontSize
            font.weight: Font.DemiBold
        }

        spacing: root.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.titleColor
            font.family: root.fontFamily
            font.pixelSize: root.titleFontSize
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.artist !== ""
            text: "•"
            color: root.accentColor
            font.family: root.fontFamily
            font.pixelSize: root.artistFontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.artist !== ""
            text: root.artist
            color: root.artistColor
            font.family: root.fontFamily
            font.pixelSize: root.artistFontSize
        }
    }
}
