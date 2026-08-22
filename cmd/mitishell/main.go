package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/display"
	"github.com/aileks/mitishell/internal/ipc"
	"github.com/aileks/mitishell/internal/weather"
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
	cacheDirectory, err := os.UserCacheDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: resolve user cache directory: %v\n", err)
		os.Exit(1)
	}
	weatherService := weather.NewService(
		weather.NewGeoClue("mitishell", 12*time.Second),
		weather.NewOpenMeteoClient(
			&http.Client{Timeout: 15 * time.Second},
			"https://api.open-meteo.com/v1/forecast",
			time.Now,
		),
		weather.NewFileCache(filepath.Join(cacheDirectory, "mitishell", "weather.json")),
		time.Now,
	)
	ddcutilRunner, err := display.NewSystemRunner()
	if err != nil {
		ddcutilRunner = display.UnavailableRunner(err)
	}
	displayService := display.NewService(
		ddcutilRunner,
		"/sys/class/drm",
		display.NewFileCache(filepath.Join(cacheDirectory, "mitishell", "displays.json")),
	)
	dependencies := cli.Dependencies{
		ConfigPath:     configPath,
		Shell:          shell,
		Doctor:         systemDoctor{configPath: configPath, shell: shell},
		Weather:        weatherService,
		Capabilities:   systemCapabilities{},
		AudioControl:   shell,
		DisplayControl: shell,
		DisplayService: displayService,
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
