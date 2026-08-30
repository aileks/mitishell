package cli

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/aileks/mitishell/internal/bluetooth"
	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/display"
	"github.com/aileks/mitishell/internal/emoji"
	"github.com/aileks/mitishell/internal/launcher"
	"github.com/aileks/mitishell/internal/network"
	"github.com/aileks/mitishell/internal/nightlight"
	"github.com/aileks/mitishell/internal/notifications"
	"github.com/aileks/mitishell/internal/osd"
	"github.com/aileks/mitishell/internal/power"
	"github.com/aileks/mitishell/internal/reminders"
	"github.com/aileks/mitishell/internal/systemmetrics"
	"github.com/aileks/mitishell/internal/updates"
	"github.com/aileks/mitishell/internal/weather"
)

type Shell interface {
	Ping() error
	Reload() error
	ToggleNotifications() error
	OpenPowerMenu() error
}

// AudioControl applies audio actions in the running shell, which shows the
// matching OSD.
type AudioControl interface {
	Volume(action string) error
	VolumeSet(value int) error
	Mic(action string) error
	MicSet(value int) error
}

// DisplayControl applies brightness actions in the running shell, which
// shows the matching OSD.
type DisplayControl interface {
	Brightness(action string) error
	BrightnessSet(value int) error
}

// SettingsSurface toggles Settings on the focused output.
type SettingsSurface interface {
	ToggleSettings(page string) error
}

// PowerService runs session power actions and reports logind support.
type PowerService interface {
	Capabilities(ctx context.Context) (power.Capabilities, error)
	Run(ctx context.Context, action power.Action) error
}

// NetworkService joins and forgets Wi-Fi networks, requests scans, and
// snapshots status.
type NetworkService interface {
	Snapshot(ctx context.Context) network.Snapshot
	SetWifiEnabled(ctx context.Context, enabled bool) error
	Connect(ctx context.Context, ssid string, password string, hidden bool) error
	Forget(ctx context.Context, ssid string) error
	RequestScan(ctx context.Context) error
}

// BluetoothService drives BlueZ devices and reports adapter status.
type BluetoothService interface {
	Snapshot(ctx context.Context) bluetooth.Snapshot
	Pair(ctx context.Context, address string) error
	Connect(ctx context.Context, address string) error
	Disconnect(ctx context.Context, address string) error
	SetTrusted(ctx context.Context, address string, trusted bool) error
	Remove(ctx context.Context, address string) error
}

// DisplayService discovers and drives DDC displays directly, used by the
// shell's display service through the hidden verbs.
type DisplayService interface {
	Discover(context.Context) display.Result
	Set(ctx context.Context, connector string, value int) display.Result
}

// Version tracks the release tag. Bump it when a release ships.
const Version = "1.1.1"

const helpText = `Usage: mitishell <command>

  ping                              check the running shell
  reload                            reload the shell
  doctor                            run environment checks
  config path|validate|get|set      manage the config file
  weather location <place...|auto>  set the weather location
  settings [page]                   toggle Settings, optionally on a page
  network                           open the network settings page
  bluetooth                         open the bluetooth settings page
  osd [flags]                       show a custom OSD
  reminder [minutes|list|clear]     manage reminders
  night-light on|off|toggle|status  control the night light
  emoji                             toggle the emoji picker
  launcher                          toggle the application launcher
  keybinds                          toggle the keybind viewer
  volume up|down|mute|set <0-150>   control the volume
  mic up|down|mute|set <0-150>      control the microphone
  brightness up|down|set <0-100>    control the brightness
  notifications dnd                 toggle do not disturb
  power menu                        open the power menu
  help                              show this help
  version                           show the version
`

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
	Snapshot(context.Context, bool, string, weather.Units) weather.Result
}

type NotificationHistory interface {
	Load() (notifications.State, error)
	Save(notifications.State) error
	Clear() error
	ImportMedia(notifications.MediaImport) (string, error)
}

type OSDControl interface {
	ShowOSD(osd.Request) error
}

type ReminderService interface {
	Schedule(context.Context, int, string) (reminders.ActiveReminder, error)
	List(context.Context) ([]reminders.ActiveReminder, error)
	Cancel(context.Context, string) (reminders.Record, error)
	Clear(context.Context) (int, error)
	Fire(context.Context, string) error
	Snapshot(context.Context) reminders.Snapshot
}

type ReminderUI interface {
	OpenReminders() error
	ReminderChanged(string) error
}

type EmojiUI interface {
	ToggleEmojiPicker() error
}

type EmojiRecents interface {
	Load() (emoji.Recents, error)
	Save(emoji.Recents) error
	Clear() error
}

type LauncherUI interface {
	ToggleLauncher() error
}

type KeybindingUI interface {
	ToggleKeybindings() error
}

type LauncherRecents interface {
	Load() (launcher.Recents, error)
	Save(launcher.Recents) error
}

type UpdateService interface {
	Snapshot(context.Context) updates.Result
}

type FontService interface {
	Catalog(context.Context) (families []string, nerdFamilies []string, err error)
}

type NightLightService interface {
	Snapshot(context.Context) nightlight.Snapshot
	Apply(context.Context, nightlight.Action) (nightlight.Snapshot, error)
}

type SystemTemperature interface {
	Snapshot() systemmetrics.Temperature
}

type Dependencies struct {
	ConfigPath          string
	Shell               Shell
	Doctor              Doctor
	Weather             Weather
	AudioControl        AudioControl
	DisplayControl      DisplayControl
	DisplayService      DisplayService
	SettingsSurface     SettingsSurface
	PowerService        PowerService
	NetworkService      NetworkService
	BluetoothService    BluetoothService
	NotificationHistory NotificationHistory
	OSD                 OSDControl
	Reminders           ReminderService
	ReminderUI          ReminderUI
	EmojiUI             EmojiUI
	EmojiRecents        EmojiRecents
	LauncherUI          LauncherUI
	KeybindingUI        KeybindingUI
	LauncherRecents     LauncherRecents
	Updates             UpdateService
	Fonts               FontService
	NightLight          NightLightService
	SystemTemperature   SystemTemperature
	Stdin               io.Reader
}

func Run(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if len(args) == 1 && args[0] == "_launcher-recents-load" {
		if dependencies.LauncherRecents == nil {
			fmt.Fprintln(stderr, "mitishell: launcher recents unavailable")
			return 1
		}
		state, err := dependencies.LauncherRecents.Load()
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: launcher recents unavailable: %v\n", err)
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode launcher recents: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_launcher-recents-save" {
		if dependencies.LauncherRecents == nil || dependencies.Stdin == nil {
			fmt.Fprintln(stderr, "mitishell: launcher recents unavailable")
			return 1
		}
		state := launcher.Recents{}
		decoder := json.NewDecoder(dependencies.Stdin)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&state); err != nil {
			fmt.Fprintf(stderr, "mitishell: decode launcher recents: %v\n", err)
			return 2
		}
		if err := dependencies.LauncherRecents.Save(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: save launcher recents: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "launcher recents saved")
		return 0
	}
	if len(args) == 1 && args[0] == "_system-temperature-snapshot" {
		result := systemmetrics.Temperature{}
		if dependencies.SystemTemperature != nil {
			result = dependencies.SystemTemperature.Snapshot()
		}
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode system temperature: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_night-light-snapshot" {
		result := nightlight.Snapshot{Error: "hyprsunset unavailable"}
		if dependencies.NightLight != nil {
			result = dependencies.NightLight.Snapshot(context.Background())
		}
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode night-light state: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 2 && args[0] == "_night-light-action" {
		if dependencies.NightLight == nil {
			fmt.Fprintln(stderr, "mitishell: night light unavailable")
			return 1
		}
		action := nightlight.Action(args[1])
		if !slices.Contains([]nightlight.Action{nightlight.On, nightlight.Off, nightlight.Toggle}, action) {
			fmt.Fprintln(stderr, "mitishell: invalid night-light action")
			return 2
		}
		result, err := dependencies.NightLight.Apply(context.Background(), action)
		if encodeErr := json.NewEncoder(stdout).Encode(result); encodeErr != nil {
			fmt.Fprintf(stderr, "mitishell: encode night-light state: %v\n", encodeErr)
			return 1
		}
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: night light unavailable: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_emoji-recents-load" {
		if dependencies.EmojiRecents == nil {
			fmt.Fprintln(stderr, "mitishell: emoji recents unavailable")
			return 1
		}
		state, err := dependencies.EmojiRecents.Load()
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: emoji recents unavailable: %v\n", err)
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode emoji recents: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_emoji-recents-save" {
		if dependencies.EmojiRecents == nil || dependencies.Stdin == nil {
			fmt.Fprintln(stderr, "mitishell: emoji recents unavailable")
			return 1
		}
		state := emoji.Recents{}
		decoder := json.NewDecoder(dependencies.Stdin)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&state); err != nil {
			fmt.Fprintf(stderr, "mitishell: decode emoji recents: %v\n", err)
			return 2
		}
		if err := dependencies.EmojiRecents.Save(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: save emoji recents: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "emoji recents saved")
		return 0
	}
	if len(args) == 1 && args[0] == "_emoji-recents-clear" {
		if dependencies.EmojiRecents == nil {
			fmt.Fprintln(stderr, "mitishell: emoji recents unavailable")
			return 1
		}
		if err := dependencies.EmojiRecents.Clear(); err != nil {
			fmt.Fprintf(stderr, "mitishell: clear emoji recents: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "emoji recents cleared")
		return 0
	}
	if len(args) == 1 && args[0] == "_updates-snapshot" {
		result := updates.Result{}
		if dependencies.Updates != nil {
			result = dependencies.Updates.Snapshot(context.Background())
		}
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode updates: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 2 && args[0] == "_reminder-fire" {
		if dependencies.Reminders == nil {
			fmt.Fprintln(stderr, "mitishell: reminders unavailable")
			return 1
		}
		if err := dependencies.Reminders.Fire(context.Background(), args[1]); err != nil {
			fmt.Fprintf(stderr, "mitishell: fire reminder: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_reminder-snapshot" {
		snapshot := reminders.Snapshot{
			Available: false,
			Error:     "reminders unavailable",
			Reminders: []reminders.ActiveReminder{},
		}
		if dependencies.Reminders != nil {
			snapshot = dependencies.Reminders.Snapshot(context.Background())
		}
		if err := json.NewEncoder(stdout).Encode(snapshot); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode reminders: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 2 && args[0] == "_reminder-cancel" {
		if dependencies.Reminders == nil {
			fmt.Fprintln(stderr, "mitishell: reminders unavailable")
			return 1
		}
		if _, err := dependencies.Reminders.Cancel(context.Background(), args[1]); err != nil {
			fmt.Fprintf(stderr, "mitishell: cancel reminder: %v\n", err)
			return 1
		}
		reminderChanged(dependencies, "Reminder cancelled")
		fmt.Fprintln(stdout, "Reminder cancelled")
		return 0
	}
	if len(args) == 1 && args[0] == "_notification-history-load" {
		if dependencies.NotificationHistory == nil {
			fmt.Fprintln(stderr, "mitishell: notification history unavailable")
			return 1
		}
		state, err := dependencies.NotificationHistory.Load()
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: notification history unavailable: %v\n", err)
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode notification history: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_notification-history-save" {
		if dependencies.NotificationHistory == nil || dependencies.Stdin == nil {
			fmt.Fprintln(stderr, "mitishell: notification history unavailable")
			return 1
		}
		state := notifications.State{}
		decoder := json.NewDecoder(dependencies.Stdin)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&state); err != nil {
			fmt.Fprintf(stderr, "mitishell: decode notification history: %v\n", err)
			return 2
		}
		if err := dependencies.NotificationHistory.Save(state); err != nil {
			fmt.Fprintf(stderr, "mitishell: save notification history: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "notification history saved")
		return 0
	}
	if len(args) == 1 && args[0] == "_notification-history-clear" {
		if dependencies.NotificationHistory == nil {
			fmt.Fprintln(stderr, "mitishell: notification history unavailable")
			return 1
		}
		if err := dependencies.NotificationHistory.Clear(); err != nil {
			fmt.Fprintf(stderr, "mitishell: clear notification history: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "notification history cleared")
		return 0
	}
	if len(args) == 1 && args[0] == "_notification-history-import" {
		if dependencies.NotificationHistory == nil || dependencies.Stdin == nil {
			fmt.Fprintln(stderr, "mitishell: notification history unavailable")
			return 1
		}
		media := notifications.MediaImport{}
		decoder := json.NewDecoder(dependencies.Stdin)
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&media); err != nil {
			fmt.Fprintf(stderr, "mitishell: decode notification media: %v\n", err)
			return 2
		}
		mediaURL, err := dependencies.NotificationHistory.ImportMedia(media)
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: import notification media: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, mediaURL)
		return 0
	}
	if len(args) == 1 && args[0] == "_fonts" {
		if dependencies.Fonts == nil {
			fmt.Fprintln(stderr, "mitishell: font enumeration unavailable")
			return 1
		}
		families, nerdFamilies, err := dependencies.Fonts.Catalog(context.Background())
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: list fonts: %v\n", err)
			return 1
		}
		catalog := struct {
			Families     []string `json:"families"`
			NerdFamilies []string `json:"nerdFamilies"`
		}{Families: families, NerdFamilies: nerdFamilies}
		if err := json.NewEncoder(stdout).Encode(catalog); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode fonts: %v\n", err)
			return 1
		}
		return 0
	}
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
			resolved.Weather.Location,
			units,
		)
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode weather: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_display-discover" {
		if dependencies.DisplayService == nil {
			fmt.Fprintln(stderr, "mitishell: display discovery unavailable")
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(dependencies.DisplayService.Discover(context.Background())); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode displays: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 3 && args[0] == "_display-set" {
		if dependencies.DisplayService == nil {
			fmt.Fprintln(stderr, "mitishell: display control unavailable")
			return 1
		}
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 100 {
			fmt.Fprintln(stderr, "mitishell: brightness value must be 0-100")
			return 2
		}
		result := dependencies.DisplayService.Set(context.Background(), args[1], value)
		if err := json.NewEncoder(stdout).Encode(result); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode displays: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) > 0 && args[0] == "config" {
		return runConfig(args[1:], stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "weather" {
		return runWeatherAction(args, stdout, stderr, dependencies)
	}
	if len(args) == 1 && args[0] == "_power-capabilities" {
		if dependencies.PowerService == nil {
			fmt.Fprintln(stderr, "mitishell: power unavailable")
			return 1
		}
		capabilities, err := dependencies.PowerService.Capabilities(context.Background())
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: power unavailable: %v\n", err)
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(capabilities); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode capabilities: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 2 && args[0] == "_power-action" {
		if dependencies.PowerService == nil {
			fmt.Fprintln(stderr, "mitishell: power unavailable")
			return 1
		}
		if err := dependencies.PowerService.Run(context.Background(), power.Action(args[1])); err != nil {
			fmt.Fprintf(stderr, "mitishell: power action unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "power action executed")
		return 0
	}
	if len(args) == 1 && args[0] == "_network-snapshot" {
		if dependencies.NetworkService == nil {
			fmt.Fprintln(stderr, "mitishell: network unavailable")
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(
			dependencies.NetworkService.Snapshot(context.Background())); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode network: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) == 1 && args[0] == "_network-scan" {
		if dependencies.NetworkService == nil {
			fmt.Fprintln(stderr, "mitishell: network unavailable")
			return 1
		}
		if err := dependencies.NetworkService.RequestScan(context.Background()); err != nil {
			fmt.Fprintf(stderr, "mitishell: network scan unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "network scan requested")
		return 0
	}
	if len(args) > 0 && args[0] == "_network-connect" {
		if dependencies.NetworkService == nil {
			fmt.Fprintln(stderr, "mitishell: network unavailable")
			return 1
		}
		hidden := false
		arguments := args[1:]
		if len(arguments) > 0 && arguments[0] == "--hidden" {
			hidden = true
			arguments = arguments[1:]
		}
		if len(arguments) != 2 {
			fmt.Fprintln(stderr, "mitishell: usage: mitishell _network-connect [--hidden] <ssid> <password>")
			return 2
		}
		if err := dependencies.NetworkService.Connect(
			context.Background(), arguments[0], arguments[1], hidden); err != nil {
			fmt.Fprintf(stderr, "mitishell: network unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "network connection requested")
		return 0
	}
	if len(args) == 2 && args[0] == "_network-wifi" {
		if dependencies.NetworkService == nil {
			fmt.Fprintln(stderr, "mitishell: network unavailable")
			return 1
		}
		enabled := args[1] == "on"
		if !enabled && args[1] != "off" {
			fmt.Fprintln(stderr, "mitishell: usage: mitishell _network-wifi <on|off>")
			return 2
		}
		if err := dependencies.NetworkService.SetWifiEnabled(
			context.Background(), enabled); err != nil {
			fmt.Fprintf(stderr, "mitishell: network unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "Wi-Fi state updated")
		return 0
	}
	if len(args) == 2 && args[0] == "_network-forget" {
		if dependencies.NetworkService == nil {
			fmt.Fprintln(stderr, "mitishell: network unavailable")
			return 1
		}
		if err := dependencies.NetworkService.Forget(context.Background(), args[1]); err != nil {
			fmt.Fprintf(stderr, "mitishell: network unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "network forgotten")
		return 0
	}
	if len(args) > 0 && args[0] == "network" {
		return runSettingsAction([]string{"settings", "network"}, stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "bluetooth" {
		return runSettingsAction([]string{"settings", "bluetooth"}, stdout, stderr, dependencies)
	}
	if len(args) == 1 && args[0] == "_bluetooth-snapshot" {
		if dependencies.BluetoothService == nil {
			fmt.Fprintln(stderr, "mitishell: bluetooth unavailable")
			return 1
		}
		if err := json.NewEncoder(stdout).Encode(
			dependencies.BluetoothService.Snapshot(context.Background())); err != nil {
			fmt.Fprintf(stderr, "mitishell: encode bluetooth: %v\n", err)
			return 1
		}
		return 0
	}
	if len(args) > 0 && args[0] == "_bluetooth-action" {
		if dependencies.BluetoothService == nil {
			fmt.Fprintln(stderr, "mitishell: bluetooth unavailable")
			return 1
		}
		exitCode, handled := runBluetoothAction(args[1:], stdout, stderr, dependencies)
		if handled {
			return exitCode
		}
		fmt.Fprintln(stderr, "mitishell: usage: mitishell _bluetooth-action <verb> <address>")
		return 2
	}
	if len(args) > 0 && args[0] == "control" {
		return runLegacyControlAction(args, stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "settings" {
		return runSettingsAction(args, stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "osd" {
		return runOSD(args[1:], stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "reminder" {
		return runReminder(args[1:], stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "night-light" {
		return runNightLight(args[1:], stdout, stderr, dependencies)
	}
	if len(args) == 1 && args[0] == "emoji" {
		if dependencies.EmojiUI == nil {
			fmt.Fprintln(stderr, "mitishell: emoji picker unavailable")
			return 1
		}
		if err := dependencies.EmojiUI.ToggleEmojiPicker(); err != nil {
			fmt.Fprintf(stderr, "mitishell: emoji picker unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "emoji picker toggled")
		return 0
	}
	if len(args) > 0 && (args[0] == "volume" || args[0] == "mic") {
		return runAudioAction(args, stdout, stderr, dependencies)
	}
	if len(args) > 0 && args[0] == "brightness" {
		return runBrightnessAction(args, stdout, stderr, dependencies)
	}
	if len(args) == 2 && args[0] == "notifications" && args[1] == "dnd" {
		if err := dependencies.Shell.ToggleNotifications(); err != nil {
			fmt.Fprintf(stderr, "mitishell: do not disturb unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "do not disturb toggled")
		return 0
	}
	if len(args) == 2 && args[0] == "power" && args[1] == "menu" {
		if err := dependencies.Shell.OpenPowerMenu(); err != nil {
			fmt.Fprintf(stderr, "mitishell: power menu unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "power menu opened")
		return 0
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
	case "launcher":
		if dependencies.LauncherUI == nil {
			fmt.Fprintln(stderr, "mitishell: launcher unavailable")
			return 1
		}
		if err := dependencies.LauncherUI.ToggleLauncher(); err != nil {
			fmt.Fprintf(stderr, "mitishell: launcher unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "launcher toggled")
		return 0
	case "keybinds":
		if dependencies.KeybindingUI == nil {
			fmt.Fprintln(stderr, "mitishell: keybind viewer unavailable")
			return 1
		}
		if err := dependencies.KeybindingUI.ToggleKeybindings(); err != nil {
			fmt.Fprintf(stderr, "mitishell: keybind viewer unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "keybinds toggled")
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
	case "help", "--help", "-h":
		fmt.Fprint(stdout, helpText)
		return 0
	case "version", "--version":
		fmt.Fprintf(stdout, "mitishell v%s\n", Version)
		return 0
	}

	fmt.Fprintf(stderr, "mitishell: unknown command %q, run \"mitishell help\"\n", args[0])
	return 2
}

func runNightLight(
	args []string,
	stdout io.Writer,
	stderr io.Writer,
	dependencies Dependencies,
) int {
	if len(args) != 1 || !slices.Contains([]string{"on", "off", "toggle", "status"}, args[0]) {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell night-light <on|off|toggle|status>")
		return 2
	}
	if dependencies.NightLight == nil {
		fmt.Fprintln(stderr, "mitishell: night light unavailable")
		return 1
	}

	if args[0] == "status" {
		result := dependencies.NightLight.Snapshot(context.Background())
		if !result.Available {
			fmt.Fprintf(stderr, "mitishell: night light unavailable: %s\n", result.Error)
			return 1
		}
		fmt.Fprintln(stdout, nightLightStatus(result))
		return 0
	}

	result, err := dependencies.NightLight.Apply(
		context.Background(), nightlight.Action(args[0]))
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: night light unavailable: %v\n", err)
		return 1
	}
	if dependencies.OSD != nil {
		request, requestErr := osd.NewRequest(
			"moon",
			fmt.Sprintf(
				"Night light %s · %d K",
				nightLightState(result),
				result.TemperatureKelvin,
			),
			nil,
			osd.DefaultDurationMS,
		)
		if requestErr == nil {
			_ = dependencies.OSD.ShowOSD(request)
		}
	}
	fmt.Fprintf(stdout, "night light %s\n", nightLightState(result))
	return 0
}

func nightLightStatus(result nightlight.Snapshot) string {
	return fmt.Sprintf("%s %d K", nightLightState(result), result.TemperatureKelvin)
}

func nightLightState(result nightlight.Snapshot) string {
	if result.Enabled {
		return "on"
	}
	return "off"
}

func runReminder(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if len(args) == 0 {
		if dependencies.ReminderUI == nil {
			fmt.Fprintln(stderr, "mitishell: reminders unavailable")
			return 1
		}
		if err := dependencies.ReminderUI.OpenReminders(); err != nil {
			fmt.Fprintf(stderr, "mitishell: reminders unavailable: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "Reminder overlay opened")
		return 0
	}
	if dependencies.Reminders == nil {
		fmt.Fprintln(stderr, "mitishell: reminders unavailable")
		return 1
	}
	if len(args) == 1 && args[0] == "list" {
		active, err := dependencies.Reminders.List(context.Background())
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: list reminders: %v\n", err)
			return 1
		}
		if len(active) == 0 {
			fmt.Fprintln(stdout, "No active reminders")
			return 0
		}
		for _, reminder := range active {
			fmt.Fprintf(
				stdout,
				"%s - %s remaining - %s\n",
				reminder.Label,
				formatRemaining(reminder.RemainingSeconds),
				time.Unix(reminder.FireAt, 0).Local().Format("3:04 PM"),
			)
		}
		return 0
	}
	if len(args) == 1 && args[0] == "clear" {
		count, err := dependencies.Reminders.Clear(context.Background())
		if err != nil {
			fmt.Fprintf(stderr, "mitishell: clear reminders: %v\n", err)
			return 1
		}
		reminderChanged(dependencies, "All reminders cleared")
		fmt.Fprintf(stdout, "Cleared %d reminders\n", count)
		return 0
	}
	minutes, err := positiveMinutes(args[0])
	if err != nil {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell reminder <positive-whole-minutes> [message...]")
		return 2
	}
	message := strings.Join(args[1:], " ")
	active, err := dependencies.Reminders.Schedule(context.Background(), minutes, message)
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: schedule reminder: %v\n", err)
		return 1
	}
	reminderChanged(dependencies, fmt.Sprintf("Reminder set for %d minutes", minutes))
	fmt.Fprintf(
		stdout,
		"Reminder set for %d minutes at %s\n",
		minutes,
		time.Unix(active.FireAt, 0).Local().Format("3:04 PM"),
	)
	return 0
}

func positiveMinutes(raw string) (int, error) {
	if raw == "" {
		return 0, fmt.Errorf("minutes are required")
	}
	for _, character := range raw {
		if character < '0' || character > '9' {
			return 0, fmt.Errorf("minutes must be digits")
		}
	}
	minutes, err := strconv.Atoi(raw)
	if err != nil || minutes <= 0 {
		return 0, fmt.Errorf("minutes must be positive")
	}
	return minutes, nil
}

func formatRemaining(seconds int64) string {
	if seconds < 0 {
		seconds = 0
	}
	minutes := seconds / 60
	remainder := seconds % 60
	if minutes > 0 && remainder > 0 {
		return fmt.Sprintf("%dm %ds", minutes, remainder)
	}
	if minutes > 0 {
		return fmt.Sprintf("%dm", minutes)
	}
	return fmt.Sprintf("%ds", remainder)
}

func reminderChanged(dependencies Dependencies, message string) {
	if dependencies.ReminderUI != nil {
		_ = dependencies.ReminderUI.ReminderChanged(message)
	}
}

func runOSD(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	flags := flag.NewFlagSet("osd", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	icon := flags.String("icon", "", "icon alias, path, theme name, glyph, or text")
	message := flags.String("message", "", "message text")
	progress := optionalFloat{}
	flags.Var(&progress, "progress", "progress from 0 through 100")
	durationMS := flags.Float64("duration", osd.DefaultDurationMS, "display duration in milliseconds")
	if err := flags.Parse(args); err != nil || flags.NArg() != 0 {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell osd [--icon <value>] [--message <text>] [--progress <0-100>] [--duration <ms>]")
		return 2
	}
	request, err := osd.NewRequest(*icon, *message, progress.Pointer(), *durationMS)
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: invalid OSD: %v\n", err)
		return 2
	}
	if dependencies.OSD == nil {
		fmt.Fprintln(stderr, "mitishell: OSD unavailable")
		return 1
	}
	if err := dependencies.OSD.ShowOSD(request); err != nil {
		fmt.Fprintf(stderr, "mitishell: OSD unavailable: %v\n", err)
		return 1
	}
	fmt.Fprintln(stdout, "OSD shown")
	return 0
}

type optionalFloat struct {
	value float64
	set   bool
}

func (value *optionalFloat) String() string {
	if !value.set {
		return ""
	}
	return strconv.FormatFloat(value.value, 'f', -1, 64)
}

func (value *optionalFloat) Set(raw string) error {
	parsed, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return err
	}
	value.value = parsed
	value.set = true
	return nil
}

func (value optionalFloat) Pointer() *float64 {
	if !value.set {
		return nil
	}
	return &value.value
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

func runWeatherAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if len(args) < 3 || args[1] != "location" || (args[2] == "auto" && len(args) != 3) {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell weather location <place...|auto>")
		return 2
	}
	location := strings.Join(args[2:], " ")
	if location == "auto" {
		location = ""
	}
	loaded, err := config.Load(dependencies.ConfigPath)
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: read config: %v\n", err)
		return 1
	}
	updated, err := config.SetField(loaded, "weather.location", location)
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: %v\n", err)
		return 1
	}
	if err := config.Write(dependencies.ConfigPath, updated); err != nil {
		fmt.Fprintf(stderr, "mitishell: write config: %v\n", err)
		return 1
	}
	if updated.Weather.Location == "" {
		fmt.Fprintln(stdout, "weather location set to auto")
	} else {
		fmt.Fprintf(stdout, "weather location set to %s\n", updated.Weather.Location)
	}
	return 0
}

func runSettingsAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	page := "overview"
	if len(args) == 2 {
		page = args[1]
	}
	valid := slices.Contains(
		[]string{"overview", "audio", "display", "network", "bluetooth", "system"}, page)
	if len(args) > 2 || !valid {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell settings <overview|audio|display|network|bluetooth|system>")
		return 2
	}
	if dependencies.SettingsSurface == nil {
		fmt.Fprintln(stderr, "mitishell: settings unavailable")
		return 1
	}
	if err := dependencies.SettingsSurface.ToggleSettings(page); err != nil {
		fmt.Fprintf(stderr, "mitishell: settings unavailable: %v\n", err)
		return 1
	}
	fmt.Fprintln(stdout, "settings toggled")
	return 0
}

func runLegacyControlAction(
	args []string,
	stdout io.Writer,
	stderr io.Writer,
	dependencies Dependencies,
) int {
	validPages := []string{"home", "audio", "display", "network", "bluetooth", "settings"}
	if len(args) > 2 || (len(args) == 2 && !slices.Contains(validPages, args[1])) {
		fmt.Fprintln(stderr, "mitishell: usage: mitishell control <home|audio|display|network|bluetooth|settings>")
		return 2
	}
	page := "overview"
	if len(args) == 2 {
		// Legacy aliases must match the renames in shell.qml's control
		// toggle handler; direct IPC callers rely on that side too.
		page = map[string]string{"home": "overview", "settings": "system"}[args[1]]
		if page == "" {
			page = args[1]
		}
	}
	return runSettingsAction([]string{"settings", page}, stdout, stderr, dependencies)
}

func runAudioAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	name := args[0]
	if dependencies.AudioControl == nil {
		fmt.Fprintf(stderr, "mitishell: %s actions unavailable\n", name)
		return 1
	}

	apply := dependencies.AudioControl.Volume
	applySet := dependencies.AudioControl.VolumeSet
	acknowledgement := "volume updated"
	unavailable := "volume"
	if name == "mic" {
		apply = dependencies.AudioControl.Mic
		applySet = dependencies.AudioControl.MicSet
		acknowledgement = "microphone updated"
		unavailable = "microphone"
	}

	var actionErr error
	switch {
	case len(args) == 2 && (args[1] == "up" || args[1] == "down" || args[1] == "mute"):
		actionErr = apply(args[1])
	case len(args) == 3 && args[1] == "set":
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 150 {
			fmt.Fprintf(stderr, "mitishell: usage: mitishell %s <up|down|mute|set <0-150>>\n", name)
			return 2
		}
		actionErr = applySet(value)
	default:
		fmt.Fprintf(stderr, "mitishell: usage: mitishell %s <up|down|mute|set <0-150>>\n", name)
		return 2
	}
	if actionErr != nil {
		fmt.Fprintf(stderr, "mitishell: %s unavailable: %v\n", unavailable, actionErr)
		return 1
	}
	fmt.Fprintln(stdout, acknowledgement)
	return 0
}

func runBrightnessAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) int {
	if dependencies.DisplayControl == nil {
		fmt.Fprintln(stderr, "mitishell: brightness actions unavailable")
		return 1
	}

	var actionErr error
	switch {
	case len(args) == 2 && (args[1] == "up" || args[1] == "down"):
		actionErr = dependencies.DisplayControl.Brightness(args[1])
	case len(args) == 3 && args[1] == "set":
		value, err := strconv.Atoi(args[2])
		if err != nil || value < 0 || value > 100 {
			fmt.Fprintln(stderr, "mitishell: usage: mitishell brightness <up|down|set <0-100>>")
			return 2
		}
		actionErr = dependencies.DisplayControl.BrightnessSet(value)
	default:
		fmt.Fprintln(stderr, "mitishell: usage: mitishell brightness <up|down|set <0-100>>")
		return 2
	}
	if actionErr != nil {
		fmt.Fprintf(stderr, "mitishell: brightness unavailable: %v\n", actionErr)
		return 1
	}
	fmt.Fprintln(stdout, "brightness updated")
	return 0
}

func runBluetoothAction(args []string, stdout io.Writer, stderr io.Writer, dependencies Dependencies) (int, bool) {
	if len(args) != 2 {
		return 0, false
	}
	verb, address := args[0], args[1]

	var err error
	ctx := context.Background()
	switch verb {
	case "pair":
		err = dependencies.BluetoothService.Pair(ctx, address)
	case "connect":
		err = dependencies.BluetoothService.Connect(ctx, address)
	case "disconnect":
		err = dependencies.BluetoothService.Disconnect(ctx, address)
	case "trust":
		err = dependencies.BluetoothService.SetTrusted(ctx, address, true)
	case "untrust":
		err = dependencies.BluetoothService.SetTrusted(ctx, address, false)
	case "remove":
		err = dependencies.BluetoothService.Remove(ctx, address)
	default:
		return 0, false
	}
	if err != nil {
		fmt.Fprintf(stderr, "mitishell: bluetooth unavailable: %v\n", err)
		return 1, true
	}
	fmt.Fprintln(stdout, "bluetooth action executed")
	return 0, true
}
