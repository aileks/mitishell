package ipc

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

type Client struct {
	executable string
	shellPath  string
}

func NewClient(executable string, shellPath string) Client {
	return Client{executable: executable, shellPath: shellPath}
}

func (client Client) Ping() error {
	response, err := client.call("shell", "ping")
	if err != nil {
		return err
	}
	if response != "pong" {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

func (client Client) Reload() error {
	response, err := client.call("shell", "reload")
	if err != nil {
		return err
	}
	if response != "reload requested" {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

func (client Client) ToggleNotifications() error {
	response, err := client.call("notifications", "toggle")
	if err != nil {
		return err
	}
	if response != "notifications toggled" {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

func (client Client) OpenPowerMenu() error {
	response, err := client.call("power", "open")
	if err != nil {
		return err
	}
	if response != "power menu opened" {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

func (client Client) call(target string, method string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	command := exec.CommandContext(
		ctx,
		client.executable,
		"ipc",
		"-p",
		client.shellPath,
		"call",
		target,
		method,
	)
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
