package main

import (
	"os/exec"

	"github.com/aileks/mitishell/internal/cli"
)

type systemCapabilities struct{}

func (systemCapabilities) Detect() cli.Capabilities {
	return cli.Capabilities{
		Notifications: executableAvailable("swaync-client"),
		Power:         executableAvailable("wlogout"),
	}
}

func executableAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
