pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "../lib/AudioModel.js" as AudioModel

QtObject {
    id: root

    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var candidateSinks: AudioModel.sinks(nodes)
    readonly property var candidateSources: AudioModel.sources(nodes)
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

    function setOutputVolume(volume) {
        if (output !== null && output.audio !== null) {
            output.audio.volume = AudioModel.clampVolume(volume);
        }
    }

    function stepOutputVolume(delta) {
        setOutputVolume(AudioModel.stepVolume(outputVolume, delta));
    }

    function toggleOutputMute() {
        if (output !== null && output.audio !== null) {
            output.audio.muted = !output.audio.muted;
        }
    }

    function setInputVolume(volume) {
        if (input !== null && input.audio !== null) {
            input.audio.volume = AudioModel.clampVolume(volume);
        }
    }

    function toggleInputMute() {
        if (input !== null && input.audio !== null) {
            input.audio.muted = !input.audio.muted;
        }
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
    }

    onCandidateSinksChanged: scheduleSnapshot()
    onCandidateSourcesChanged: scheduleSnapshot()

    property PwObjectTracker sinkTracker: PwObjectTracker {
        objects: root.candidateSinks
    }

    property PwObjectTracker sourceTracker: PwObjectTracker {
        objects: root.candidateSources
    }

    property Timer snapshotTimer: Timer {
        interval: 50
        onTriggered: root.refreshSnapshot()
    }

    Component.onCompleted: scheduleSnapshot()
}
