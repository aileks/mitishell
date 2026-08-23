package reminders

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type Runner interface {
	Schedule(context.Context, Record, string) error
	Active(context.Context, string) (bool, error)
	Stop(context.Context, string) error
}

type Executor interface {
	Run(context.Context, string, ...string) error
}

type CommandRunner struct {
	systemdRun string
	systemctl  string
	executor   Executor
}

func NewCommandRunner() (CommandRunner, error) {
	systemdRun, err := exec.LookPath("systemd-run")
	if err != nil {
		return CommandRunner{}, fmt.Errorf("systemd-run is unavailable")
	}
	systemctl, err := exec.LookPath("systemctl")
	if err != nil {
		return CommandRunner{}, fmt.Errorf("systemctl is unavailable")
	}
	return CommandRunner{
		systemdRun: systemdRun,
		systemctl:  systemctl,
		executor:   OSExecutor{},
	}, nil
}

func NewCommandRunnerWithExecutor(systemdRun string, systemctl string, executor Executor) CommandRunner {
	return CommandRunner{systemdRun: systemdRun, systemctl: systemctl, executor: executor}
}

func (runner CommandRunner) Schedule(ctx context.Context, record Record, executable string) error {
	arguments := []string{
		"--user",
		"--quiet",
		"--collect",
		"--unit=" + record.Unit(),
		"--on-active=" + strconv.Itoa(record.Minutes) + "m",
		"--property=PartOf=graphical-session.target",
		"--timer-property=PartOf=graphical-session.target",
		"--timer-property=AccuracySec=1s",
		"--",
		executable,
		"_reminder-fire",
		record.ID,
	}
	if err := runner.executor.Run(ctx, runner.systemdRun, arguments...); err != nil {
		return fmt.Errorf("schedule reminder timer: %w", err)
	}
	return nil
}

func (runner CommandRunner) Active(ctx context.Context, unit string) (bool, error) {
	err := runner.executor.Run(ctx, runner.systemctl, "--user", "is-active", "--quiet", unit+".timer")
	if err == nil {
		return true, nil
	}
	if errors.Is(err, ErrInactiveUnit) {
		return false, nil
	}
	return false, fmt.Errorf("inspect reminder timer: %w", err)
}

func (runner CommandRunner) Stop(ctx context.Context, unit string) error {
	for _, suffix := range []string{".timer", ".service"} {
		err := runner.executor.Run(ctx, runner.systemctl, "--user", "stop", unit+suffix)
		if errors.Is(err, ErrInactiveUnit) {
			continue
		}
		if err != nil {
			return fmt.Errorf("stop reminder timer: %w", err)
		}
	}
	return nil
}

var ErrInactiveUnit = errors.New("systemd unit is inactive")

type OSExecutor struct{}

func (OSExecutor) Run(ctx context.Context, name string, arguments ...string) error {
	command := exec.CommandContext(ctx, name, arguments...)
	if output, err := command.CombinedOutput(); err != nil {
		if _, exited := err.(*exec.ExitError); exited &&
			len(arguments) > 1 && arguments[1] == "is-active" {
			return fmt.Errorf("%w: %s", ErrInactiveUnit, output)
		}
		message := strings.TrimSpace(string(output))
		if _, exited := err.(*exec.ExitError); exited &&
			len(arguments) > 1 && arguments[1] == "stop" &&
			(strings.Contains(message, "not loaded") ||
				strings.Contains(message, "not found")) {
			return fmt.Errorf("%w: %s", ErrInactiveUnit, message)
		}
		if message == "" {
			return err
		}
		return fmt.Errorf("%s: %w", message, err)
	}
	return nil
}
