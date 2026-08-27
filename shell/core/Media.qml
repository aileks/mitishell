pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../lib/MediaModel.js" as MediaModel

QtObject {
    id: root

    property string preferredPlayerKey: ""
    property real displayPosition: 0
    property real trackLength: 0
    property int activitySequence: 0
    property var activityByDbusName: ({})

    readonly property var rawPlayers: Mpris.players ? Mpris.players.values : []
    readonly property var players: MediaModel.logicalPlayers(rawPlayers, activityByDbusName)
    readonly property var activePlayer: MediaModel.choosePlayer(players, preferredPlayerKey)
    readonly property string title: MediaModel.title(activePlayer)
    readonly property string artist: MediaModel.artist(activePlayer)
    readonly property bool available: activePlayer !== null
    readonly property bool meaningful: MediaModel.hasMetadata(activePlayer)

    function selectPlayer(player) {
        preferredPlayerKey = MediaModel.playerKey(player);
    }

    function noteActivity(player) {
        if (player === null || player === undefined || player.dbusName === "") {
            return;
        }
        activitySequence += 1;
        const updated = Object.assign({}, activityByDbusName);
        updated[player.dbusName] = activitySequence;
        activityByDbusName = updated;
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

    // Some MPRIS players swap metadata without re-emitting a Length property
    // change, so the total is re-read alongside the position instead of
    // bound to the player property.
    function syncPlaybackClock() {
        const player = activePlayer;
        displayPosition = player !== null && player.positionSupported
            ? player.position : 0;
        trackLength = player !== null && player.lengthSupported
            ? player.length : 0;
    }

    onActivePlayerChanged: syncPlaybackClock()

    property Connections playerConnections: Connections {
        target: root.activePlayer

        function onPositionChanged() {
            root.syncPlaybackClock();
        }

        function onTrackChanged() {
            root.syncPlaybackClock();
        }
    }

    property Instantiator activityWatchers: Instantiator {
        model: Mpris.players

        delegate: QtObject {
            id: activityWatcher

            required property var modelData

            Component.onCompleted: root.noteActivity(activityWatcher.modelData)

            property Connections activityConnections: Connections {
                target: activityWatcher.modelData

                function onMetadataChanged() {
                    root.noteActivity(activityWatcher.modelData);
                }

                function onPlaybackStateChanged() {
                    root.noteActivity(activityWatcher.modelData);
                }

                function onPostTrackChanged() {
                    root.noteActivity(activityWatcher.modelData);
                }
            }
        }
    }

    property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.activePlayer !== null
            && root.activePlayer.positionSupported
            && root.activePlayer.isPlaying
        onTriggered: root.syncPlaybackClock()
    }
}
