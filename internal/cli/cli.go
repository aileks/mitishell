package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strconv"

	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/display"
	"github.com/aileks/mitishell/internal/weather"
)

type Shell interface {
	Ping() error
	Reload() error
	ToggleNotifications() error
	OpenPowerMenu() error
}

// AudioControl applies audio actions in the running shell, which shows the
// matching OSD.
type AudioControl interface {
	Volume(action string) error
	VolumeSet(value int) error
	Mic(action string) error
	MicSet(value int) error
}

// DisplayControl applies brightness actions in the running shell, which
// shows the matching OSD.
type DisplayControl interface {
	Brightness(action string) error
	BrightnessSet(value int) error
}

// ControlCenter toggles the shell's control center on the focused output.
type ControlCenter interface {
	ToggleControlCenter(page string) error
}

// DisplayService discovers and drives DDC displays directly, used by the
// shell's display service through the hidden verbs.
type DisplayService interface {
	Discover(context.Context) display.Result
	Set(ctx context.Context, connector string, value int) display.Result
}

type Capabilities struct {
	Power bool `json:"power"`
}

type CapabilityDetector interface {
	Detect() Capabilities
}

type Status string

const (
	StatusOK      Status = "ok"
	StatusWarning Status = "warn"
	StatusFailure Status = "fail"
)

type Check struct {
	Name   string
	Status Status
	Detail string
}

type Doctor interface {
	Checks() []Check
}

type Weather interface {
	Snapshot(context.Context, bool, weather.Units) weather.Result
}

type Dependencies struct {
	ConfigPath     string
	Shell          Shell
	Doctor         Doctor
	Weather        Weather
	Capabilities   CapabilityDetector
	AudioControl   AudioControl
	DisplayControl DisplayControl
	DisplayService DisplayService
	ControlCenter  ControlCenter
}

func Run(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if len(args) == 1 && args[0] == "_capabilities" {
		if dependencies.Capabilities == nil {
			fmt.Fprintln(stderr, "mitishell: capability detection unavailable")
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(dependencies.Capabilities.Detect()); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode capabilities: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_config-resolve" {
		resolved, loadErr := config.Load(dependencies.ConfigPath)
		if loadErr != nil {
			resolved = config.Defaults()
			fmt.Fprintf(stderr, "mitishell: invalid config, using defaults: %v\n", loadErr)
		}
		if err := json.NewEncoder(stdout).Encode(resolved); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode config: %v\n", err)
			return 1
		}
		if loadErr != nil {
			return 1
		}
		return 0
	}
	if len(args) == 2 && args[0] == "_weather-snapshot" {
		units := weather.Units(args[1])
		if units != weather.Celsius && units != weather.Fahrenheit {
			fmt.Fprintln(stderr, "mitishell: weather units must be celsius or fahrenheit")
			return 2
		}
		resolved, err := config.Load(dependencies.ConfigPath)
		if err != nil {
			resolved = config.Defaults()
		}
		result := dependencies.Weather.Snapshot(
			context.Background(),
			resolved.Weather.Enabled,
			units,
		)
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode weather: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_display-discover" {
		if dependencies.DisplayService == nil {
			fmt.Fprintln(stderr, "mitishell: display discovery unavailable")
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(dependencies.DisplayService.Discover(context.Background())); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode displays: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 3 && args[0] == "_display-set" {
		if dependencies.DisplayService == nil {
			fmt.Fprintln(stderr, "mitishell: display control unavailable")
			return 1
		}
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 100 {
			fmt.Fprintln(stderr, "mitishell: brightness value must be 0-100")
			return 2
		}
		result := dependencies.DisplayService.Set(context.Background(), args[1], value)
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode displays: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) > 0 && args[0] == "config" {
		return runConfig(args[1:], stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "control" {
		return runControlAction(args, stdout, stderr, dependencies)
	}
	if len(args) > 0 && (args[0] == "volume" || args[0] == "mic") {
		return runAudioAction(args, stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "brightness" {
		return runBrightnessAction(args, stdout, stderr, dependencies)
	}
	if len(args) == 2 && args[0] == "notifications" && args[1] == "dnd" {
		if err := dependencies.Shell.ToggleNotifications(); err != nil {
			fmt.Fprintf(stderr, "mitishell: do not disturb unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "do not disturb toggled")
		return 0
	}
	if len(args) == 2 && args[0] == "power" && args[1] == "menu" {
		if err := dependencies.Shell.OpenPowerMenu(); err != nil {
			fmt.Fprintf(stderr, "mitishell: power menu unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "power menu opened")
		return 0
	}
	if len(args) != 1 {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell <command>")
		return 2
	}

	switch args[0] {
	case "ping":
		if err := dependencies.Shell.Ping(); err != nil {
			fmt.Fprintf(stderr, "mitishell: shell unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "pong")
		return 0
	case "reload":
		if err := dependencies.Shell.Reload(); err != nil {
			fmt.Fprintf(stderr, "mitishell: reload failed: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "reload requested")
		return 0
	case "doctor":
		failed := false
		for _, check := range dependencies.Doctor.Checks() {
			fmt.Fprintf(stdout, "[%s] %s: %s\n", check.Status, check.Name, check.Detail)
			failed = failed || check.Status == StatusFailure
		}
		if failed {
			return 1
		}
		return 0
	}

	fmt.Fprintln(stderr, "mitishell: usage: mitishell <command>")
	return 2
}

func runConfig(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if len(args) == 1 && args[0] == "path" {
		fmt.Fprintln(stdout, dependencies.ConfigPath)
		return 0
	}
	if len(args) == 1 && args[0] == "validate" {
		if _, err := config.Load(dependencies.ConfigPath); err != nil {
			fmt.Fprintf(stderr, "mitishell: invalid config: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "valid")
		return 0
	}
	if len(args) == 2 && args[0] == "get" {
		loaded, err := config.Load(dependencies.ConfigPath)
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: read config: %v\n", err)
			return 1
		}
		value, err := config.GetField(loaded, args[1])
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, value)
		return 0
	}
	if len(args) == 3 && args[0] == "set" {
		loaded, err := config.Load(dependencies.ConfigPath)
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: read config: %v\n", err)
			return 1
		}
		updated, err := config.SetField(loaded, args[1], args[2])
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: %v\n", err)
			return 1
		}
		if err := config.Write(dependencies.ConfigPath, updated); err != nil {
			fmt.Fprintf(stderr, "mitishell: write config: %v\n", err)
			return 1
		}
		fmt.Fprintf(stdout, "updated %s\n", args[1])
		return 0
	}

	fmt.Fprintln(stderr, "mitishell: usage: mitishell config <path|validate|get|set>")
	return 2
}

func runControlAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	page := "home"
	if len(args) == 2 {
		page = args[1]
	}
	valid := page == "home" || page == "audio" || page == "media" || page == "display"
	if len(args) > 2 || !valid {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell control <home|audio|media|display>")
		return 2
	}
	if dependencies.ControlCenter == nil {
		fmt.Fprintln(stderr, "mitishell: control center unavailable")
		return 1
	}
	if err := dependencies.ControlCenter.ToggleControlCenter(page); err != nil {
		fmt.Fprintf(stderr, "mitishell: control center unavailable: %v\n", err)
		return 1
	}
	fmt.Fprintln(stdout, "control center toggled")
	return 0
}

func runAudioAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	name := args[0]
	if dependencies.AudioControl == nil {
		fmt.Fprintf(stderr, "mitishell: %s actions unavailable\n", name)
		return 1
	}

	apply := dependencies.AudioControl.Volume
	applySet := dependencies.AudioControl.VolumeSet
	acknowledgement := "volume updated"
	unavailable := "volume"
	if name == "mic" {
		apply = dependencies.AudioControl.Mic
		applySet = dependencies.AudioControl.MicSet
		acknowledgement = "microphone updated"
		unavailable = "microphone"
	}

	var actionErr error
	switch {
	case len(args) == 2 && (args[1] == "up" || args[1] == "down" || args[1] == "mute"):
		actionErr = apply(args[1])
	case len(args) == 3 && args[1] == "set":
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 150 {
			fmt.Fprintf(stderr, "mitishell: usage: mitishell %s <up|down|mute|set <0-150>>\n", name)
			return 2
		}
		actionErr = applySet(value)
	default:
		fmt.Fprintf(stderr, "mitishell: usage: mitishell %s <up|down|mute|set <0-150>>\n", name)
		return 2
	}
	if actionErr != nil {
		fmt.Fprintf(stderr, "mitishell: %s unavailable: %v\n", unavailable, actionErr)
		return 1
	}
	fmt.Fprintln(stdout, acknowledgement)
	return 0
}

func runBrightnessAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if dependencies.DisplayControl == nil {
		fmt.Fprintln(stderr, "mitishell: brightness actions unavailable")
		return 1
	}

	var actionErr error
	switch {
	case len(args) == 2 && (args[1] == "up" || args[1] == "down"):
		actionErr = dependencies.DisplayControl.Brightness(args[1])
	case len(args) == 3 && args[1] == "set":
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 100 {
			fmt.Fprintln(stderr, "mitishell: usage: mitishell brightness <up|down|set <0-100>>")
			return 2
		}
		actionErr = dependencies.DisplayControl.BrightnessSet(value)
	default:
		fmt.Fprintln(stderr, "mitishell: usage: mitishell brightness <up|down|set <0-100>>")
		return 2
	}
	if actionErr != nil {
		fmt.Fprintf(stderr, "mitishell: brightness unavailable: %v\n", actionErr)
		return 1
	}
	fmt.Fprintln(stdout, "brightness updated")
	return 0
}
