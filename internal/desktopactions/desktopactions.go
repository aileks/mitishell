// Package desktopactions discovers the optional commands exposed by the
// launcher's Actions menu.
package desktopactions

import (
	"context"
	"os/exec"
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
	ScreenshotCommand []string  `json:"screenshotCommand"`
	OCRCommand        []string  `json:"ocrCommand"`
	QRCommand         []string  `json:"qrCommand"`
	RecordingCommand  []string  `json:"recordingCommand"`
	RecordingActive   bool      `json:"recordingActive"`
	PowerCommand      []string  `json:"powerCommand"`
	PowerProfiles     []Profile `json:"powerProfiles"`
	FirmwareCommand   []string  `json:"firmwareCommand"`
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

	result := Snapshot{PowerProfiles: []Profile{}}
	result.ScreenshotCommand = service.command("desktop-screenshot")
	result.OCRCommand = service.command("desktop-ocr")
	result.QRCommand = service.command("desktop-qr")
	result.RecordingCommand = service.command("desktop-record")
	if len(result.RecordingCommand) > 0 {
		_, err := service.runner.Output(ctx, result.RecordingCommand[0], "status")
		result.RecordingActive = err == nil
	}

	result.PowerCommand = service.command("powerprofilesctl")
	if len(result.PowerCommand) > 0 {
		active, activeErr := service.runner.Output(ctx, result.PowerCommand[0], "get")
		profiles, profilesErr := service.runner.Output(ctx, result.PowerCommand[0], "list")
		if activeErr == nil && profilesErr == nil {
			result.PowerProfiles = parseProfiles(profiles, strings.TrimSpace(active))
		}
	}

	firmware := service.command("fwupdmgr")
	bash := service.command("bash")
	if len(firmware) > 0 && len(bash) > 0 {
		result.FirmwareCommand = terminal.Command(service.runner, []string{
			bash[0], "-lc", "fwupdmgr refresh && fwupdmgr update",
		})
	}
	return result
}

func (service Service) command(name string) []string {
	found, err := service.runner.LookPath(name)
	if err != nil {
		return []string{}
	}
	return []string{found}
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
