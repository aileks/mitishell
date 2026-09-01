package desktopactions

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func writeStateForProcess(t *testing.T, pid int, startTime string) {
	t.Helper()
	if err := writeRecordingState(recordingState{
		PID:       pid,
		StartTime: startTime,
		File:      "/tmp/recording.mp4",
	}); err != nil {
		t.Fatalf("writeRecordingState() error = %v", err)
	}
}

func TestRecordingStateRoundTrip(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	state := recordingState{PID: 1234, StartTime: "5678", File: "/tmp/recording.mp4"}
	if err := writeRecordingState(state); err != nil {
		t.Fatalf("writeRecordingState() error = %v", err)
	}
	loaded, err := readRecordingState()
	if err != nil || loaded != state {
		t.Fatalf("readRecordingState() = %#v, %v; want %#v", loaded, err, state)
	}
}

func TestRecordingIsActiveMatchesLiveProcess(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	executable, err := os.Executable()
	if err != nil {
		t.Fatalf("resolve test binary: %v", err)
	}
	t.Setenv("DESKTOP_RECORD_PROCESS_NAME", filepath.Base(executable))
	startTime, _, alive := processDetails(os.Getpid())
	if !alive || startTime == "" {
		t.Fatalf("processDetails(self) alive = %v, startTime = %q", alive, startTime)
	}

	writeStateForProcess(t, os.Getpid(), startTime)
	if !recordingIsActive() {
		t.Fatal("recordingIsActive() = false for a matching live process")
	}

	t.Setenv("DESKTOP_RECORD_PROCESS_NAME", "gpu-screen-recorder")
	if recordingIsActive() {
		t.Fatal("recordingIsActive() = true for a mismatched process name")
	}

	t.Setenv("DESKTOP_RECORD_PROCESS_NAME", filepath.Base(executable))
	writeStateForProcess(t, os.Getpid(), "1")
	if recordingIsActive() {
		t.Fatal("recordingIsActive() = true for a reused PID start time")
	}
}

func TestRecordingIsActiveIgnoresDeadProcess(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	t.Setenv("DESKTOP_RECORD_PROCESS_NAME", "gpu-screen-recorder")
	finished := exec.Command("true")
	if err := finished.Run(); err != nil {
		t.Fatalf("run stub process: %v", err)
	}
	writeStateForProcess(t, finished.Process.Pid, "1")
	if recordingIsActive() {
		t.Fatal("recordingIsActive() = true for a dead PID")
	}
}

func TestStopRecordingReportsMissingOutput(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	sleep, err := exec.LookPath("sleep")
	if err != nil {
		t.Skipf("sleep unavailable: %v", err)
	}
	recorder := exec.Command(sleep, "30")
	if err := recorder.Start(); err != nil {
		t.Fatalf("start recorder stub: %v", err)
	}
	defer func() { _ = recorder.Wait() }()
	startTime, executable, alive := processDetails(recorder.Process.Pid)
	if !alive {
		t.Fatal("recorder stub did not stay alive")
	}
	t.Setenv("DESKTOP_RECORD_PROCESS_NAME", filepath.Base(executable))
	if err := writeRecordingState(recordingState{
		PID:       recorder.Process.Pid,
		StartTime: startTime,
		File:      filepath.Join(t.TempDir(), "recording.mp4"),
	}); err != nil {
		t.Fatalf("writeRecordingState() error = %v", err)
	}

	err = stopRecording()
	if err == nil || err.Error() != "no completed recording was written" {
		t.Fatalf("stopRecording() error = %v, want missing-output failure", err)
	}
	if _, statErr := os.Stat(recordingStatePath()); !errors.Is(statErr, os.ErrNotExist) {
		t.Fatalf("state file still present after stop: %v", statErr)
	}
}
