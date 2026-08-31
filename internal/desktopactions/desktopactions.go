// Package desktopactions owns the actions exposed by the launcher's Actions menu.
package desktopactions

import (
	"context"
	"fmt"
	"os/exec"
	"slices"
	"strings"
	"time"

	"github.com/aileks/mitishell/internal/terminal"
)

const snapshotTimeout = 3 * time.Second

type Profile struct {
	Name   string `json:"name"`
	Active bool   `json:"active"`
}

type Snapshot struct {
	ScreenshotModes   []string  `json:"screenshotModes"`
	OCRAvailable      bool      `json:"ocrAvailable"`
	QRAvailable       bool      `json:"qrAvailable"`
	RecordingModes    []string  `json:"recordingModes"`
	RecordingActive   bool      `json:"recordingActive"`
	PowerProfiles     []Profile `json:"powerProfiles"`
	FirmwareAvailable bool      `json:"firmwareAvailable"`
}

type Runner interface {
	LookPath(file string) (string, error)
	Output(ctx context.Context, name string, args ...string) (string, error)
}

type SystemRunner struct{}

func (SystemRunner) LookPath(file string) (string, error) { return exec.LookPath(file) }

func (SystemRunner) Output(ctx context.Context, name string, args ...string) (string, error) {
	output, err := exec.CommandContext(ctx, name, args...).CombinedOutput()
	return string(output), err
}

type Service struct {
	runner Runner
}

func NewService(runner Runner) Service { return Service{runner: runner} }

func (service Service) Snapshot(parent context.Context) Snapshot {
	ctx, cancel := context.WithTimeout(parent, snapshotTimeout)
	defer cancel()

	result := Snapshot{
		ScreenshotModes: []string{},
		RecordingModes:  []string{},
		PowerProfiles:   []Profile{},
	}
	if service.hasAll("grim", "wl-copy", "notify-send") {
		if service.hasAll("slurp", "hyprpicker") {
			result.ScreenshotModes = append(result.ScreenshotModes, "region")
		}
		if service.has("hyprctl") {
			result.ScreenshotModes = append(result.ScreenshotModes, "window", "output")
		}
		result.ScreenshotModes = append(result.ScreenshotModes, "desktop")
	}
	result.OCRAvailable = service.hasAll(
		"grim", "slurp", "hyprpicker", "tesseract", "wl-copy", "notify-send")
	result.QRAvailable = service.hasAll(
		"grim", "slurp", "hyprpicker", "zbarimg", "wl-copy", "notify-send")

	result.RecordingActive = recordingIsActive()
	if service.hasAll("gpu-screen-recorder", "notify-send") {
		if service.has("slurp") {
			result.RecordingModes = append(result.RecordingModes, "region")
		}
		if service.has("hyprctl") {
			result.RecordingModes = append(result.RecordingModes, "output")
		}
	}

	if power, err := service.runner.LookPath("powerprofilesctl"); err == nil {
		active, activeErr := service.runner.Output(ctx, power, "get")
		profiles, profilesErr := service.runner.Output(ctx, power, "list")
		if activeErr == nil && profilesErr == nil {
			result.PowerProfiles = parseProfiles(profiles, strings.TrimSpace(active))
		}
	}

	result.FirmwareAvailable = service.hasAll("fwupdmgr", "bash")
	if result.FirmwareAvailable {
		result.FirmwareAvailable = len(terminal.Command(service.runner, []string{"true"})) > 0
	}
	return result
}

func (service Service) Run(ctx context.Context, args []string) error {
	if len(args) == 2 && args[0] == "screenshot" && slices.Contains(
		[]string{"region", "window", "output", "desktop"}, args[1]) {
		tools := []string{"grim", "wl-copy", "notify-send"}
		if args[1] == "region" {
			tools = append(tools, "slurp", "hyprpicker")
		}
		if args[1] == "window" || args[1] == "output" {
			tools = append(tools, "hyprctl")
		}
		if err := service.require("screenshots", tools...); err != nil {
			return err
		}
		return takeScreenshot(ctx, args[1])
	}
	if len(args) == 1 && args[0] == "text" {
		if err := service.require("text extraction",
			"grim", "slurp", "hyprpicker", "tesseract", "wl-copy", "notify-send"); err != nil {
			return err
		}
		return extractText(ctx)
	}
	if len(args) == 1 && args[0] == "qr" {
		if err := service.require("QR scanning",
			"grim", "slurp", "hyprpicker", "zbarimg", "wl-copy", "notify-send"); err != nil {
			return err
		}
		return scanQR(ctx)
	}
	if len(args) == 2 && args[0] == "record" && args[1] == "stop" {
		return stopRecording()
	}
	if len(args) == 3 && args[0] == "record" &&
		slices.Contains([]string{"region", "output"}, args[1]) &&
		slices.Contains([]string{"none", "mic", "desktop", "desktop+mic"}, args[2]) {
		if err := service.ValidateRecording(args[1]); err != nil {
			return err
		}
		return startRecording(args[1], args[2])
	}
	if len(args) == 2 && args[0] == "power-profile" && args[1] != "" {
		if err := service.require("power profiles", "powerprofilesctl"); err != nil {
			return err
		}
		return runCommand(ctx, nil, "powerprofilesctl", "set", args[1])
	}
	if len(args) == 1 && args[0] == "firmware" {
		if err := service.require("firmware updates", "fwupdmgr", "bash"); err != nil {
			return err
		}
		return service.runFirmware(ctx)
	}
	return fmt.Errorf("invalid action")
}

func (service Service) ValidateRecording(mode string) error {
	tools := []string{"gpu-screen-recorder", "notify-send"}
	switch mode {
	case "region":
		tools = append(tools, "slurp")
	case "output":
		tools = append(tools, "hyprctl")
	default:
		return fmt.Errorf("invalid recording mode %q", mode)
	}
	return service.require("screen recording", tools...)
}

func (service Service) runFirmware(ctx context.Context) error {
	bash, err := service.runner.LookPath("bash")
	if err != nil {
		return fmt.Errorf("firmware updates unavailable: %w", err)
	}
	command := terminal.Command(service.runner, []string{
		bash, "-lc", "fwupdmgr refresh && fwupdmgr update",
	})
	if len(command) == 0 {
		return fmt.Errorf("Please install xdg-terminal-exec or a supported terminal for firmware updates")
	}
	return runCommand(ctx, nil, command[0], command[1:]...)
}

func (service Service) has(command string) bool {
	_, err := service.runner.LookPath(command)
	return err == nil
}

func (service Service) hasAll(commands ...string) bool {
	for _, command := range commands {
		if !service.has(command) {
			return false
		}
	}
	return true
}

func (service Service) require(purpose string, commands ...string) error {
	packages := map[string]string{
		"gpu-screen-recorder": "gpu-screen-recorder",
		"grim":                "grim",
		"hyprctl":             "Hyprland",
		"hyprpicker":          "hyprpicker",
		"notify-send":         "libnotify",
		"powerprofilesctl":    "power-profiles-daemon",
		"slurp":               "slurp",
		"tesseract":           "tesseract and tesseract-data-eng",
		"wl-copy":             "wl-clipboard",
		"zbarimg":             "zbar",
		"fwupdmgr":            "fwupd",
	}
	for _, command := range commands {
		if service.has(command) {
			continue
		}
		name := packages[command]
		if name == "" {
			name = command
		}
		return fmt.Errorf("Please install %s for %s", name, purpose)
	}
	return nil
}

func parseProfiles(output string, active string) []Profile {
	profiles := []Profile{}
	for _, line := range strings.Split(output, "\n") {
		name := strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(line), ":"))
		name = strings.TrimSpace(strings.TrimPrefix(name, "*"))
		if name == "" || strings.Contains(name, " ") || !strings.HasSuffix(strings.TrimSpace(line), ":") {
			continue
		}
		profiles = append(profiles, Profile{Name: name, Active: name == active})
	}
	return profiles
}
