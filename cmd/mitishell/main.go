package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/ipc"
)

func main() {
	configPath, err := config.Path()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	shellPath, err := resolveShellPath()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}

	qsExecutable := os.Getenv("MITISHELL_QS_BIN")
	if qsExecutable == "" {
		qsExecutable = "qs"
	}
	shell := ipc.NewClient(qsExecutable, shellPath)
	dependencies := cli.Dependencies{
		ConfigPath: configPath,
		Shell:      shell,
		Doctor:     systemDoctor{configPath: configPath, shell: shell},
	}
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr, dependencies))
}

func resolveShellPath() (string, error) {
	if override := os.Getenv("MITISHELL_QS_PATH"); override != "" {
		return filepath.Abs(override)
	}
	directory := os.Getenv("XDG_DATA_HOME")
	if directory == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve user data directory: %w", err)
		}
		directory = filepath.Join(homeDirectory, ".local", "share")
	}
	return filepath.Join(directory, "mitishell", "shell"), nil
}
