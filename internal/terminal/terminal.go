// Package terminal resolves the user's preferred terminal command.
package terminal

import (
	"os"
	"path/filepath"
	"strings"
)

type Finder interface {
	LookPath(file string) (string, error)
}

// Command returns argv that opens command in the user's preferred terminal.
func Command(finder Finder, command []string) []string {
	if found, err := finder.LookPath("xdg-terminal-exec"); err == nil {
		return append([]string{found, "--"}, command...)
	}
	if fields := strings.Fields(os.Getenv("TERMINAL")); len(fields) > 0 {
		return appendCommand(fields, command)
	}
	for _, name := range []string{"foot", "alacritty", "kitty", "ghostty"} {
		if found, err := finder.LookPath(name); err == nil {
			return appendCommand([]string{found}, command)
		}
	}
	return nil
}

func appendCommand(terminal []string, command []string) []string {
	argv := append([]string(nil), terminal...)
	name := filepath.Base(terminal[0])
	if name == "alacritty" || name == "ghostty" {
		argv = append(argv, "-e")
	}
	return append(argv, command...)
}
