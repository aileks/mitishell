package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/aileks/mitishell/internal/bluetooth"
	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/clipboard"
	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/display"
	"github.com/aileks/mitishell/internal/emoji"
	"github.com/aileks/mitishell/internal/fonts"
	"github.com/aileks/mitishell/internal/ipc"
	"github.com/aileks/mitishell/internal/launcher"
	"github.com/aileks/mitishell/internal/network"
	"github.com/aileks/mitishell/internal/nightlight"
	"github.com/aileks/mitishell/internal/notifications"
	"github.com/aileks/mitishell/internal/power"
	"github.com/aileks/mitishell/internal/reminders"
	"github.com/aileks/mitishell/internal/systemmetrics"
	"github.com/aileks/mitishell/internal/updates"
	"github.com/aileks/mitishell/internal/weather"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "_bluetooth-scan" {
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		if err := bluetooth.RunScan(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "mitishell: bluetooth scan: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}
	if len(os.Args) >= 2 && os.Args[1] == "_bluetooth-agent" {
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		if err := bluetooth.RunAgent(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "mitishell: bluetooth agent: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}
	if len(os.Args) == 4 && os.Args[1] == "_bluetooth-respond" {
		if err := bluetooth.Respond(os.Args[2], os.Args[3]); err != nil {
			fmt.Fprintf(os.Stderr, "mitishell: pairing response: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	configPath, err := config.Path()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	shellPath, err := ipc.ResolveShellPath()
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
		weather.NewWttrClient(
			&http.Client{Timeout: 15 * time.Second},
			"https://wttr.in",
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
	notificationHistoryPath, err := notifications.Path()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	emojiRecentsPath, err := emoji.RecentsPath()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	clipboardHistoryPath, err := clipboard.HistoryPath()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	launcherRecentsPath, err := launcher.RecentsPath()
	if err != nil {
		fmt.Fprintf(os.Stderr, "mitishell: %v\n", err)
		os.Exit(1)
	}
	reminderDirectory, reminderDirectoryErr := reminders.RuntimeDirectory()
	reminderRunner, reminderRunnerErr := reminders.NewCommandRunner()
	executable, executableErr := os.Executable()
	reminderService := reminders.Unavailable(errors.Join(
		reminderDirectoryErr,
		reminderRunnerErr,
		executableErr,
	))
	if reminderDirectoryErr == nil && reminderRunnerErr == nil && executableErr == nil {
		reminderService = reminders.NewService(
			reminderRunner,
			reminders.NewFileStore(reminderDirectory),
			reminders.NewDBusNotifier(),
			executable,
		)
	}
	dependencies := cli.Dependencies{
		ConfigPath:          configPath,
		Shell:               shell,
		Doctor:              systemDoctor{configPath: configPath, shell: shell},
		Weather:             weatherService,
		AudioControl:        shell,
		DisplayControl:      shell,
		DisplayService:      displayService,
		SettingsSurface:     shell,
		PowerService:        power.NewService(power.LogindCaller{}),
		NetworkService:      network.NewService(network.NMCaller{}),
		BluetoothService:    bluetooth.NewService(bluetooth.BlueZCaller{}),
		NotificationHistory: notifications.NewFileHistory(notificationHistoryPath),
		OSD:                 shell,
		Reminders:           reminderService,
		ReminderUI:          shell,
		EmojiUI:             shell,
		EmojiRecents:        emoji.NewFileRecents(emojiRecentsPath),
		ClipboardHistory:    clipboard.NewFileHistory(clipboardHistoryPath),
		LauncherUI:          shell,
		ClipboardUI:         shell,
		KeybindingUI:        shell,
		LauncherRecents:     launcher.NewFileRecents(launcherRecentsPath),
		Updates:             updates.NewService(updates.SystemRunner{}),
		Fonts:               fonts.NewService(fonts.SystemRunner{}),
		NightLight:          nightlight.NewService(nightlight.SystemRunner{}),
		SystemTemperature: systemmetrics.NewTemperatureService(
			"/sys/class/hwmon",
			"/sys/class/thermal",
		),
		Stdin: os.Stdin,
	}
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr, dependencies))
}
