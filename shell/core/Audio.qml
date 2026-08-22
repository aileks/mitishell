pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "../lib/AudioModel.js" as AudioModel

QtObject {
    id: root

    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var candidateSinks: AudioModel.sinks(nodes)
    readonly property var candidateSources: AudioModel.sources(nodes)
    readonly property var candidateStreams: AudioModel.playbackStreams(nodes)
    readonly property var output: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    readonly property real outputVolume: output !== null && output.audio !== null
        ? AudioModel.clampVolume(output.audio.volume) : 0
    readonly property real inputVolume: input !== null && input.audio !== null
        ? AudioModel.clampVolume(input.audio.volume) : 0
    readonly property bool outputMuted: output !== null && output.audio !== null
        ? output.audio.muted : false
    readonly property bool inputMuted: input !== null && input.audio !== null
        ? input.audio.muted : false
    readonly property bool ready: Pipewire.ready

    property var sinks: []
    property var sources: []
    property var streams: []

    function setOutputVolume(volume) {
        if (output !== null && output.audio !== null) {
            output.audio.volume = AudioModel.clampVolume(volume);
        }
    }

    function stepOutputVolume(delta) {
        setOutputVolume(AudioModel.stepVolume(outputVolume, delta));
    }

    function setOutputMuted(muted) {
        if (output !== null && output.audio !== null) {
            output.audio.muted = muted;
        }
    }

    function toggleOutputMute() {
        if (muteToggleAllowed() && output !== null && output.audio !== null) {
            output.audio.muted = !output.audio.muted;
        }
    }

    function setInputVolume(volume) {
        if (input !== null && input.audio !== null) {
            input.audio.volume = AudioModel.clampVolume(volume);
        }
    }

    function setInputMuted(muted) {
        if (input !== null && input.audio !== null) {
            input.audio.muted = muted;
        }
    }

    function toggleInputMute() {
        if (muteToggleAllowed() && input !== null && input.audio !== null) {
            input.audio.muted = !input.audio.muted;
        }
    }

    // Mute keys bounce on some hardware: toggles within 250 ms count as one
    // so a single press cannot flip mute state back and forth.
    property real lastMuteToggleMs: 0

    function muteToggleAllowed() {
        const now = Date.now();
        if (now - lastMuteToggleMs < 250) {
            return false;
        }
        lastMuteToggleMs = now;
        return true;
    }

    function selectSink(node) {
        if (node !== null) {
            Pipewire.preferredDefaultAudioSink = node;
        }
    }

    function selectSource(node) {
        if (node !== null) {
            Pipewire.preferredDefaultAudioSource = node;
        }
    }

    function setStreamVolume(node, volume) {
        if (node !== null && node.audio !== null) {
            node.audio.volume = AudioModel.clampVolume(volume);
        }
    }

    function setStreamMuted(node, muted) {
        if (node !== null && node.audio !== null) {
            node.audio.muted = muted;
        }
    }

    function scheduleSnapshot() {
        snapshotTimer.restart();
    }

    function refreshSnapshot() {
        sinks = candidateSinks.filter(function(node) {
            return node !== null && node.audio !== null;
        });
        sources = candidateSources.filter(function(node) {
            return node !== null && node.audio !== null && node.name !== "quickshell";
        });
        // Streams appear mid-session, and their audio object can bind after
        // the snapshot runs; rows guard a null audio instead of the snapshot
        // dropping the stream before it is interactive.
        streams = candidateStreams.slice();
    }

    onCandidateSinksChanged: scheduleSnapshot()
    onCandidateSourcesChanged: scheduleSnapshot()
    onCandidateStreamsChanged: scheduleSnapshot()

    property PwObjectTracker sinkTracker: PwObjectTracker {
        objects: root.candidateSinks
    }

    property PwObjectTracker sourceTracker: PwObjectTracker {
        objects: root.candidateSources
    }

    property PwObjectTracker streamTracker: PwObjectTracker {
        objects: root.candidateStreams
    }

    property Timer snapshotTimer: Timer {
        interval: 50
        onTriggered: root.refreshSnapshot()
    }

    Component.onCompleted: scheduleSnapshot()
}
