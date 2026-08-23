package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/config"
)

type shellPinger interface {
	Ping() error
}

type systemDoctor struct {
	configPath string
	shell      shellPinger
}

func (doctor systemDoctor) Checks() []cli.Check {
	checks := []cli.Check{
		commandCheck("quickshell", true),
		commandCheck("qs", true),
		commandCheck("hyprctl", true),
		commandCheck("missioncenter", false),
		commandCheck("ddcutil", false),
		commandCheck("nmcli", false),
		commandCheck("bluetoothctl", false),
		fontCheck("Adwaita Sans"),
		fontCheck("Adwaita Mono"),
	}

	checks = append(checks, quickshellVersionCheck())
	checks = append(checks, hyprlandCheck())
	if _, err := config.Load(doctor.configPath); err != nil {
		checks = append(checks, cli.Check{
			Name: "config", Status: cli.StatusFailure, Detail: err.Error(),
		})
	} else {
		checks = append(checks, cli.Check{
			Name: "config", Status: cli.StatusOK, Detail: doctor.configPath,
		})
	}
	if err := doctor.shell.Ping(); err != nil {
		checks = append(checks, cli.Check{
			Name: "shell", Status: cli.StatusFailure, Detail: err.Error(),
		})
	} else {
		checks = append(checks, cli.Check{
			Name: "shell", Status: cli.StatusOK, Detail: "IPC reachable",
		})
	}

	return checks
}

func commandCheck(name string, required bool) cli.Check {
	path, err := exec.LookPath(name)
	if err == nil {
		return cli.Check{Name: name, Status: cli.StatusOK, Detail: path}
	}
	status := cli.StatusWarning
	if required {
		status = cli.StatusFailure
	}
	return cli.Check{Name: name, Status: status, Detail: "not found"}
}

func quickshellVersionCheck() cli.Check {
	output, err := exec.Command("quickshell", "--version").CombinedOutput()
	if err != nil {
		return cli.Check{Name: "quickshell-version", Status: cli.StatusFailure, Detail: err.Error()}
	}
	version := strings.TrimSpace(string(output))
	if !strings.Contains(version, "0.3.0") {
		return cli.Check{
			Name: "quickshell-version", Status: cli.StatusFailure,
			Detail: fmt.Sprintf("expected 0.3.0, found %s", version),
		}
	}
	return cli.Check{Name: "quickshell-version", Status: cli.StatusOK, Detail: version}
}

func hyprlandCheck() cli.Check {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		return cli.Check{Name: "hyprland", Status: cli.StatusFailure, Detail: "session environment missing"}
	}
	if output, err := exec.Command("hyprctl", "-j", "monitors").CombinedOutput(); err != nil {
		return cli.Check{
			Name: "hyprland", Status: cli.StatusFailure,
			Detail: strings.TrimSpace(string(output)),
		}
	}
	return cli.Check{Name: "hyprland", Status: cli.StatusOK, Detail: "session reachable"}
}

func fontCheck(font string) cli.Check {
	output, err := exec.Command("fc-match", "-f", "%{family}", font).CombinedOutput()
	if err != nil || !strings.Contains(string(output), font) {
		return cli.Check{Name: "font-" + strings.ToLower(strings.ReplaceAll(font, " ", "-")), Status: cli.StatusFailure, Detail: "not found"}
	}
	return cli.Check{Name: "font-" + strings.ToLower(strings.ReplaceAll(font, " ", "-")), Status: cli.StatusOK, Detail: font}
}
