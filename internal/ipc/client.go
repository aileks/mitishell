package ipc

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/aileks/mitishell/internal/osd"
)

type Client struct {
	executable string
	shellPath  string
}

func NewClient(executable string, shellPath string) Client {
	return Client{executable: executable, shellPath: shellPath}
}

// ResolveShellPath locates the running shell's directory, honoring the
// development override before the installed location.
func ResolveShellPath() (string, error) {
	if override := os.Getenv("MITISHELL_QS_PATH"); override != "" {
		return filepath.Abs(override)
	}
	directory := os.Getenv("XDG_DATA_HOME")
	if directory == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve user data directory: %w", err)
		}
		directory = filepath.Join(homeDirectory, ".local", "share")
	}
	return filepath.Join(directory, "mitishell", "shell"), nil
}

func (client Client) Ping() error {
	return client.action("shell", "ping", "pong")
}

func (client Client) Reload() error {
	return client.action("shell", "reload", "reload requested")
}

// ToggleNotifications toggles the shell's do-not-disturb mode.
func (client Client) ToggleNotifications() error {
	return client.action("notifications", "dnd", "do not disturb toggled")
}

func (client Client) OpenPowerMenu() error {
	return client.action("power", "open", "power menu opened")
}

// OpenSettings opens the control center's Settings page on the focused output.
func (client Client) OpenSettings() error {
	return client.action("settings", "open", "settings opened")
}

func (client Client) ToggleEmojiPicker() error {
	return client.action("emoji", "toggle", "emoji picker toggled")
}

// Volume applies an output volume step action: up, down, or mute.
func (client Client) Volume(action string) error {
	return client.action("audio", "volume", "volume updated", action)
}

// VolumeSet applies an absolute output volume percentage.
func (client Client) VolumeSet(value int) error {
	return client.action("audio", "volumeSet", "volume updated", strconv.Itoa(value))
}

// Mic applies a microphone step action: up, down, or mute.
func (client Client) Mic(action string) error {
	return client.action("audio", "mic", "microphone updated", action)
}

// MicSet applies an absolute microphone volume percentage.
func (client Client) MicSet(value int) error {
	return client.action("audio", "micSet", "microphone updated", strconv.Itoa(value))
}

// Brightness applies a brightness step action: up or down.
func (client Client) Brightness(action string) error {
	return client.action("display", "brightness", "brightness updated", action)
}

// BrightnessSet applies an absolute brightness percentage.
func (client Client) BrightnessSet(value int) error {
	return client.action("display", "brightnessSet", "brightness updated", strconv.Itoa(value))
}

// ToggleControlCenter toggles the control center on the focused output,
// starting on the given page.
func (client Client) ToggleControlCenter(page string) error {
	return client.action("control", "toggle", "control center toggled", page)
}

func (client Client) ShowOSD(request osd.Request) error {
	progress := ""
	if request.Progress != nil {
		progress = strconv.FormatFloat(*request.Progress, 'f', -1, 64)
	}
	return client.action(
		"osd",
		"show",
		"OSD shown",
		request.Icon,
		request.Message,
		progress,
		strconv.Itoa(request.DurationMS),
	)
}

func (client Client) OpenReminders() error {
	return client.action("reminders", "open", "Reminder overlay opened")
}

func (client Client) ReminderChanged(message string) error {
	return client.action("reminders", "changed", "Reminder state refreshed", message)
}

func (client Client) action(target string, method string, acknowledgement string, args ...string) error {
	response, err := client.Call(target, method, args...)
	if err != nil {
		return err
	}
	if response != acknowledgement {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

// Call invokes a QuickShell IPC method with positional string arguments.
func (client Client) Call(target string, method string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	// The -- keeps target, method, and arguments that shadow qs subcommands
	// (such as show or up) positional.
	arguments := append([]string{"ipc", "-p", client.shellPath, "call", "--", target, method}, args...)
	command := exec.CommandContext(ctx, client.executable, arguments...)
	output, err := command.CombinedOutput()
	if ctx.Err() != nil {
		return "", fmt.Errorf("IPC %s timed out", method)
	}
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			message = err.Error()
		}
		return "", fmt.Errorf("IPC %s failed: %s", method, message)
	}
	return strings.TrimSpace(string(output)), nil
}
