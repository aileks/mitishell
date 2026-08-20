pragma Singleton

import QtQuick
import Quickshell.Services.Mpris
import "../lib/MediaModel.js" as MediaModel

QtObject {
    id: root

    property string preferredDbusName: ""
    property real displayPosition: 0

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var activePlayer: MediaModel.choosePlayer(players, preferredDbusName)
    readonly property string title: MediaModel.title(activePlayer)
    readonly property string artist: MediaModel.artist(activePlayer)
    readonly property bool available: activePlayer !== null
    readonly property bool meaningful: MediaModel.hasMetadata(activePlayer)

    function selectPlayer(dbusName) {
        preferredDbusName = dbusName;
    }

    function previous() {
        if (activePlayer !== null && activePlayer.canGoPrevious) {
            activePlayer.previous();
        }
    }

    function togglePlaying() {
        if (activePlayer === null) {
            return;
        }
        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
        } else if (activePlayer.isPlaying && activePlayer.canPause) {
            activePlayer.pause();
        } else if (!activePlayer.isPlaying && activePlayer.canPlay) {
            activePlayer.play();
        }
    }

    function next() {
        if (activePlayer !== null && activePlayer.canGoNext) {
            activePlayer.next();
        }
    }

    onActivePlayerChanged: displayPosition = activePlayer !== null
        && activePlayer.positionSupported ? activePlayer.position : 0

    property Connections playerConnections: Connections {
        target: root.activePlayer

        function onPositionChanged() {
            root.displayPosition = root.activePlayer.position;
        }

        function onTrackChanged() {
            root.displayPosition = root.activePlayer.positionSupported
                ? root.activePlayer.position : 0;
        }
    }

    property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.activePlayer !== null
            && root.activePlayer.positionSupported
            && root.activePlayer.isPlaying
        onTriggered: root.displayPosition = root.activePlayer.position
    }
}
