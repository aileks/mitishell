package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"

	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/weather"
)

type Shell interface {
	Ping() error
	Reload() error
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
	ConfigPath string
	Shell      Shell
	Doctor     Doctor
	Weather    Weather
}

func Run(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
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
	if len(args) > 0 && args[0] == "config" {
		return runConfig(args[1:], stdout, stderr, dependencies)
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
