// Package nightlight controls a user-managed hyprsunset instance through
// Hyprland IPC. It never starts or supervises the outside process.
package nightlight

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const (
	commandTimeout           = 2 * time.Second
	EnabledTemperatureKelvin = 4800
)

var ErrUnavailable = errors.New("hyprsunset unavailable")

type Action string

const (
	On     Action = "on"
	Off    Action = "off"
	Toggle Action = "toggle"
)

type Snapshot struct {
	Available         bool   `json:"available"`
	Enabled           bool   `json:"enabled"`
	TemperatureKelvin int    `json:"temperatureKelvin"`
	Error             string `json:"error,omitempty"`
}

type Runner interface {
	LookPath(file string) (string, error)
	Output(ctx context.Context, name string, args ...string) (string, error)
}

type SystemRunner struct{}

func (SystemRunner) LookPath(file string) (string, error) { return exec.LookPath(file) }

func (SystemRunner) Output(ctx context.Context, name string, args ...string) (string, error) {
	output, err := exec.CommandContext(ctx, name, args...).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			message = err.Error()
		}
		return "", errors.New(message)
	}
	return strings.TrimSpace(string(output)), nil
}

type Service struct {
	runner Runner
}

func NewService(runner Runner) Service {
	return Service{runner: runner}
}

func (service Service) Snapshot(ctx context.Context) Snapshot {
	hyprctl, err := service.runner.LookPath("hyprctl")
	if err != nil {
		return unavailable(fmt.Errorf("%w: hyprctl not found", ErrUnavailable))
	}

	identity, err := service.output(ctx, hyprctl, "hyprsunset", "identity", "get")
	if err != nil {
		return unavailable(err)
	}
	enabled, err := parseIdentity(identity)
	if err != nil {
		return unavailable(err)
	}
	temperature, err := service.output(ctx, hyprctl, "hyprsunset", "temperature")
	if err != nil {
		return unavailable(err)
	}
	temperatureKelvin, err := parseTemperature(temperature)
	if err != nil {
		return unavailable(err)
	}
	return Snapshot{
		Available:         true,
		Enabled:           enabled,
		TemperatureKelvin: temperatureKelvin,
	}
}

func (service Service) Apply(ctx context.Context, action Action) (Snapshot, error) {
	if action != On && action != Off && action != Toggle {
		return Snapshot{}, fmt.Errorf("invalid night-light action %q", action)
	}

	current := service.Snapshot(ctx)
	if !current.Available {
		return current, errors.New(current.Error)
	}
	wantEnabled := action == On || (action == Toggle && !current.Enabled)
	needsTemperatureCorrection := wantEnabled &&
		current.TemperatureKelvin != EnabledTemperatureKelvin
	if current.Enabled == wantEnabled && !needsTemperatureCorrection {
		return current, nil
	}

	hyprctl, err := service.runner.LookPath("hyprctl")
	if err != nil {
		result := unavailable(fmt.Errorf("%w: hyprctl not found", ErrUnavailable))
		return result, errors.New(result.Error)
	}
	if wantEnabled {
		if _, err := service.output(
			ctx,
			hyprctl,
			"hyprsunset",
			"temperature",
			strconv.Itoa(EnabledTemperatureKelvin),
		); err != nil {
			result := unavailable(err)
			return result, errors.New(result.Error)
		}
	}
	if current.Enabled != wantEnabled {
		identity := "true"
		if wantEnabled {
			identity = "false"
		}
		if _, err := service.output(ctx, hyprctl, "hyprsunset", "identity", identity); err != nil {
			result := unavailable(err)
			return result, errors.New(result.Error)
		}
	}

	updated := service.Snapshot(ctx)
	if !updated.Available {
		return updated, errors.New(updated.Error)
	}
	return updated, nil
}

func (service Service) output(ctx context.Context, name string, args ...string) (string, error) {
	commandContext, cancel := context.WithTimeout(ctx, commandTimeout)
	defer cancel()
	output, err := service.runner.Output(commandContext, name, args...)
	if commandContext.Err() != nil {
		return "", fmt.Errorf("%w: IPC timed out", ErrUnavailable)
	}
	if err != nil {
		if strings.Contains(err.Error(), ".hyprsunset.sock") ||
			strings.Contains(strings.ToLower(err.Error()), "couldn't connect") {
			return "", fmt.Errorf("%w: hyprsunset is not running", ErrUnavailable)
		}
		return "", fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	return strings.TrimSpace(output), nil
}

func parseIdentity(output string) (bool, error) {
	switch strings.TrimSpace(output) {
	case "false":
		return true, nil
	case "true":
		return false, nil
	default:
		return false, fmt.Errorf("%w: invalid identity state %q", ErrUnavailable, output)
	}
}

func parseTemperature(output string) (int, error) {
	temperature, err := strconv.Atoi(strings.TrimSpace(output))
	if err != nil || temperature < 1000 || temperature > 20000 {
		return 0, fmt.Errorf("%w: invalid temperature %q", ErrUnavailable, output)
	}
	return temperature, nil
}

func unavailable(err error) Snapshot {
	return Snapshot{Error: err.Error()}
}
