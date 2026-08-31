package desktopactions

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type recordingState struct {
	PID       int
	StartTime string
	File      string
}

func startRecording(mode string, audio string) error {
	lock, err := lockRecording()
	if err != nil {
		return err
	}
	defer unlockRecording(lock)

	if recordingIsActive() {
		return fmt.Errorf("recording already started")
	}
	_ = os.Remove(recordingStatePath())

	directory, err := recordingDirectory()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return fmt.Errorf("create recording directory: %w", err)
	}
	path := filepath.Join(directory, time.Now().Format("2006-01-02_15-04-05")+".mp4")

	videoArgs := []string{}
	switch mode {
	case "region":
		geometry, err := selectRegion(context.Background(), "%wx%h+%x+%y")
		if errors.Is(err, errSelectionCancelled) {
			return nil
		}
		if err != nil {
			return err
		}
		videoArgs = []string{"-w", "region", "-region", geometry}
	case "output":
		output, err := focusedOutput(context.Background())
		if err != nil {
			return err
		}
		videoArgs = []string{"-w", output}
	default:
		return fmt.Errorf("invalid recording mode %q", mode)
	}

	audioArgs := []string{}
	switch audio {
	case "none":
	case "mic":
		audioArgs = []string{"-a", "default_input"}
	case "desktop":
		audioArgs = []string{"-a", "default_output"}
	case "desktop+mic":
		audioArgs = []string{"-a", "default_output|default_input"}
	default:
		return fmt.Errorf("invalid recording audio %q", audio)
	}

	recorder := strings.TrimSpace(os.Getenv("DESKTOP_RECORD_RECORDER"))
	if recorder == "" {
		recorder = "gpu-screen-recorder"
	}
	args := append(videoArgs, "-f", "60")
	args = append(args, audioArgs...)
	args = append(args, "-c", "mp4", "-o", path)
	command := exec.Command(recorder, args...)
	command.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	null, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil {
		return fmt.Errorf("open null device: %w", err)
	}
	command.Stdin = null
	command.Stdout = null
	command.Stderr = null
	if err := command.Start(); err != nil {
		null.Close()
		return fmt.Errorf("start recording: %w", err)
	}
	null.Close()

	time.Sleep(200 * time.Millisecond)
	startTime, _, alive := processDetails(command.Process.Pid)
	if !alive {
		_ = command.Wait()
		return fmt.Errorf("recording process exited before it was ready")
	}
	if err := writeRecordingState(recordingState{
		PID:       command.Process.Pid,
		StartTime: startTime,
		File:      path,
	}); err != nil {
		_ = command.Process.Signal(os.Interrupt)
		_ = command.Wait()
		return err
	}
	if err := command.Process.Release(); err != nil {
		return fmt.Errorf("release recording process: %w", err)
	}
	return notify(context.Background(), "", "Recording", "Recording started")
}

func stopRecording() error {
	lock, err := lockRecording()
	if err != nil {
		return err
	}
	defer unlockRecording(lock)

	state, err := readRecordingState()
	if err != nil || !recordingMatches(state) {
		_ = os.Remove(recordingStatePath())
		return notify(context.Background(), "", "Recording", "No active recording")
	}
	process, err := os.FindProcess(state.PID)
	if err != nil {
		return fmt.Errorf("find recording process: %w", err)
	}
	if err := process.Signal(os.Interrupt); err != nil {
		return fmt.Errorf("stop recording: %w", err)
	}
	for range 50 {
		_, _, alive := processDetails(state.PID)
		if !alive {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if _, _, alive := processDetails(state.PID); alive {
		return fmt.Errorf("recording is still finalizing")
	}
	if err := os.Remove(recordingStatePath()); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("remove recording state: %w", err)
	}
	info, err := os.Stat(state.File)
	if err != nil || info.Size() == 0 {
		return fmt.Errorf("no completed recording was written")
	}
	return notify(context.Background(), "", "Recording", "Recording saved")
}

func recordingIsActive() bool {
	state, err := readRecordingState()
	return err == nil && recordingMatches(state)
}

func recordingMatches(state recordingState) bool {
	startTime, executable, alive := processDetails(state.PID)
	if !alive || startTime != state.StartTime {
		return false
	}
	expected := strings.TrimSpace(os.Getenv("DESKTOP_RECORD_PROCESS_NAME"))
	if expected == "" {
		expected = "gpu-screen-recorder"
	}
	return filepath.Base(executable) == expected
}

func processDetails(pid int) (startTime string, executable string, alive bool) {
	if pid <= 0 || syscall.Kill(pid, 0) != nil {
		return "", "", false
	}
	stat, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "stat"))
	if err != nil {
		return "", "", false
	}
	closing := strings.LastIndexByte(string(stat), ')')
	if closing < 0 {
		return "", "", false
	}
	fields := strings.Fields(string(stat)[closing+1:])
	if len(fields) < 20 || fields[0] == "Z" {
		return "", "", false
	}
	target, err := os.Readlink(filepath.Join("/proc", strconv.Itoa(pid), "exe"))
	if err != nil {
		return "", "", false
	}
	return fields[19], target, true
}

func readRecordingState() (recordingState, error) {
	contents, err := os.ReadFile(recordingStatePath())
	if err != nil {
		return recordingState{}, err
	}
	lines := strings.Split(strings.TrimSuffix(string(contents), "\n"), "\n")
	if len(lines) != 3 {
		return recordingState{}, fmt.Errorf("invalid recording state")
	}
	pid, err := strconv.Atoi(lines[0])
	if err != nil || pid <= 0 || lines[1] == "" || lines[2] == "" {
		return recordingState{}, fmt.Errorf("invalid recording state")
	}
	return recordingState{PID: pid, StartTime: lines[1], File: lines[2]}, nil
}

func writeRecordingState(state recordingState) error {
	path := recordingStatePath()
	temporary, err := os.CreateTemp(filepath.Dir(path), ".desktop-record-*")
	if err != nil {
		return fmt.Errorf("create recording state: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set recording state permissions: %w", err)
	}
	if _, err := fmt.Fprintf(temporary, "%d\n%s\n%s\n", state.PID, state.StartTime, state.File); err != nil {
		temporary.Close()
		return fmt.Errorf("write recording state: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close recording state: %w", err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return fmt.Errorf("replace recording state: %w", err)
	}
	return nil
}

func recordingDirectory() (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if output, err := commandOutput(ctx, nil, "xdg-user-dir", "VIDEOS"); err == nil {
		if directory := strings.TrimSpace(string(output)); directory != "" {
			return filepath.Join(directory, "Recordings"), nil
		}
	}
	if directory := strings.TrimSpace(os.Getenv("XDG_VIDEOS_DIR")); directory != "" {
		return filepath.Join(directory, "Recordings"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve videos directory: %w", err)
	}
	return filepath.Join(home, "Videos", "Recordings"), nil
}

func recordingStatePath() string {
	return filepath.Join(runtimeDirectory(), "desktop-record.state")
}

func recordingLockPath() string {
	return filepath.Join(runtimeDirectory(), "desktop-record.lock")
}

func runtimeDirectory() string {
	if directory := strings.TrimSpace(os.Getenv("XDG_RUNTIME_DIR")); directory != "" {
		return directory
	}
	return filepath.Join("/run/user", strconv.Itoa(os.Getuid()))
}

func lockRecording() (*os.File, error) {
	lock, err := os.OpenFile(recordingLockPath(), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open recording lock: %w", err)
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		lock.Close()
		return nil, fmt.Errorf("lock recording: %w", err)
	}
	return lock, nil
}

func unlockRecording(lock *os.File) {
	_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	_ = lock.Close()
}
