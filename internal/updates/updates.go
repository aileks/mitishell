// Package updates inspects pending pacman and AUR updates. It never installs
// anything; it only returns the argv a user may explicitly launch.
package updates

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const maxPackageNames = 50

var ErrNoUpdates = errors.New("no updates")

type Source struct {
	Count    int      `json:"count"`
	Packages []string `json:"packages"`
	Error    string   `json:"error,omitempty"`
}

type Result struct {
	Supported     bool     `json:"supported"`
	System        Source   `json:"system"`
	Aur           Source   `json:"aur"`
	Helper        string   `json:"helper"`
	UpdateCommand []string `json:"updateCommand"`
}

type Runner interface {
	LookPath(file string) (string, error)
	Output(ctx context.Context, name string, args ...string) (string, error)
}

type SystemRunner struct{}

func (SystemRunner) LookPath(file string) (string, error) { return exec.LookPath(file) }

func (SystemRunner) Output(ctx context.Context, name string, args ...string) (string, error) {
	output, err := exec.CommandContext(ctx, name, args...).Output()
	if err == nil {
		return string(output), nil
	}
	var exitError *exec.ExitError
	if errors.As(err, &exitError) {
		if name == "checkupdates" && exitError.ExitCode() == 2 && len(output) == 0 {
			return "", ErrNoUpdates
		}
		if len(output) > 0 {
			return string(output), nil
		}
	}
	return string(output), fmt.Errorf("run %s: %w", name, err)
}

type Service struct {
	runner Runner
	env    func(string) string
}

func NewService(runner Runner) Service { return Service{runner: runner, env: os.Getenv} }

func (service Service) Snapshot(ctx context.Context) Result {
	result := Result{
		System: Source{Packages: []string{}},
		Aur:    Source{Packages: []string{}},
	}
	if _, err := service.runner.LookPath("checkupdates"); err != nil {
		return result
	}
	result.Supported = true

	output, err := service.runner.Output(ctx, "checkupdates")
	if err != nil && !errors.Is(err, ErrNoUpdates) {
		result.System.Error = err.Error()
	} else {
		result.System = packageSource(output)
	}

	for _, helper := range []string{"paru", "yay"} {
		if _, err := service.runner.LookPath(helper); err != nil {
			continue
		}
		result.Helper = helper
		output, outputErr := service.runner.Output(ctx, helper, "-Qua")
		if outputErr != nil {
			result.Aur.Error = outputErr.Error()
		} else {
			result.Aur = packageSource(output)
		}
		break
	}

	result.UpdateCommand = service.updateCommand(result.Helper)
	return result
}

func (service Service) updateCommand(helper string) []string {
	update := []string{"sudo", "pacman", "-Syu"}
	if helper != "" {
		update = []string{helper, "-Syu"}
	}
	if terminal, err := service.runner.LookPath("xdg-terminal-exec"); err == nil {
		return append([]string{terminal, "--"}, update...)
	}
	if fields := strings.Fields(service.env("TERMINAL")); len(fields) > 0 {
		return terminalCommand(fields, update)
	}
	for _, terminal := range []string{"foot", "alacritty", "kitty", "ghostty"} {
		if found, err := service.runner.LookPath(terminal); err == nil {
			return terminalCommand([]string{found}, update)
		}
	}
	return nil
}

func terminalCommand(terminal []string, update []string) []string {
	command := append([]string(nil), terminal...)
	name := filepath.Base(terminal[0])
	if name == "alacritty" || name == "ghostty" {
		command = append(command, "-e")
	}
	return append(command, update...)
}

func packageSource(output string) Source {
	result := Source{Packages: []string{}}
	for _, line := range strings.Split(strings.TrimSpace(output), "\n") {
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		result.Count++
		if len(result.Packages) < maxPackageNames {
			result.Packages = append(result.Packages, fields[0])
		}
	}
	return result
}
