package ipc

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
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
	return client.action("shell", "ping", "pong")
}

func (client Client) Reload() error {
	return client.action("shell", "reload", "reload requested")
}

func (client Client) ToggleNotifications() error {
	return client.action("notifications", "toggle", "notifications toggled")
}

func (client Client) OpenPowerMenu() error {
	return client.action("power", "open", "power menu opened")
}

// Volume applies an output volume step action: up, down, or mute.
func (client Client) Volume(action string) error {
	return client.action("audio", "volume", "volume updated", action)
}

// VolumeSet applies an absolute output volume percentage.
func (client Client) VolumeSet(value int) error {
	return client.action("audio", "volume-set", "volume updated", strconv.Itoa(value))
}

// Mic applies a microphone step action: up, down, or mute.
func (client Client) Mic(action string) error {
	return client.action("audio", "mic", "microphone updated", action)
}

// MicSet applies an absolute microphone volume percentage.
func (client Client) MicSet(value int) error {
	return client.action("audio", "mic-set", "microphone updated", strconv.Itoa(value))
}

// Brightness applies a brightness step action: up or down.
func (client Client) Brightness(action string) error {
	return client.action("display", "brightness", "brightness updated", action)
}

// BrightnessSet applies an absolute brightness percentage.
func (client Client) BrightnessSet(value int) error {
	return client.action("display", "brightness-set", "brightness updated", strconv.Itoa(value))
}

func (client Client) action(target string, method string, acknowledgement string, args ...string) error {
	response, err := client.call(target, method, args...)
	if err != nil {
		return err
	}
	if response != acknowledgement {
		return fmt.Errorf("unexpected response %q", response)
	}
	return nil
}

func (client Client) call(target string, method string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	// The -- keeps target, method, and arguments that shadow qs subcommands
	// (such as show or up) positional.
	arguments := append([]string{"ipc", "-p", client.shellPath, "call", "--", target, method}, args...)
	command := exec.CommandContext(ctx, client.executable, arguments...)
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
