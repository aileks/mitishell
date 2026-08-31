package cli_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/clipboard"
	"github.com/aileks/mitishell/internal/config"
	"github.com/aileks/mitishell/internal/desktopactions"
	"github.com/aileks/mitishell/internal/display"
	"github.com/aileks/mitishell/internal/emoji"
	"github.com/aileks/mitishell/internal/launcher"
	"github.com/aileks/mitishell/internal/nightlight"
	"github.com/aileks/mitishell/internal/notifications"
	"github.com/aileks/mitishell/internal/osd"
	"github.com/aileks/mitishell/internal/power"
	"github.com/aileks/mitishell/internal/reminders"
	"github.com/aileks/mitishell/internal/systemmetrics"
	"github.com/aileks/mitishell/internal/updates"
	"github.com/aileks/mitishell/internal/weather"
)

type shellStub struct {
	pingErr          error
	reloadErr        error
	notificationsErr error
	powerErr         error
}

type controlStub struct {
	volumeCalls   []string
	volumeSet     []int
	micCalls      []string
	micSet        []int
	brightness    []string
	brightnessSet []int
	settingsPages []string
	err           error
}

type systemTemperatureStub struct {
	temperature systemmetrics.Temperature
}

func (stub systemTemperatureStub) Snapshot() systemmetrics.Temperature {
	return stub.temperature
}

func TestInternalSystemTemperatureSnapshotEncodesResult(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	result := systemmetrics.Temperature{Available: true, Celsius: 52.5, Sensor: "k10temp Tctl"}
	exitCode := cli.Run(
		[]string{"_system-temperature-snapshot"},
		&stdout,
		&stderr,
		cli.Dependencies{SystemTemperature: systemTemperatureStub{temperature: result}},
	)
	if exitCode != 0 || stderr.Len() != 0 {
		t.Fatalf("exitCode=%d stderr=%q", exitCode, stderr.String())
	}
	var got systemmetrics.Temperature
	if err := json.Unmarshal(stdout.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got != result {
		t.Fatalf("result = %#v", got)
	}
}

type fontCatalogStub struct {
	families     []string
	nerdFamilies []string
	err          error
}

func (stub fontCatalogStub) Catalog(context.Context) ([]string, []string, error) {
	return stub.families, stub.nerdFamilies, stub.err
}

func TestInternalFontsEncodesStandardAndNerdFamilies(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	exitCode := cli.Run(
		[]string{"_fonts"},
		&stdout,
		&stderr,
		cli.Dependencies{Fonts: fontCatalogStub{
			families:     []string{"Adwaita Sans", "DejaVu Sans"},
			nerdFamilies: []string{"AdwaitaMono Nerd Font"},
		}},
	)
	if exitCode != 0 || stderr.Len() != 0 {
		t.Fatalf("exitCode=%d stderr=%q", exitCode, stderr.String())
	}
	var catalog struct {
		Families     []string `json:"families"`
		NerdFamilies []string `json:"nerdFamilies"`
	}
	if err := json.Unmarshal(stdout.Bytes(), &catalog); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(catalog.Families, []string{"Adwaita Sans", "DejaVu Sans"}) {
		t.Fatalf("families = %#v", catalog.Families)
	}
	if !slices.Equal(catalog.NerdFamilies, []string{"AdwaitaMono Nerd Font"}) {
		t.Fatalf("nerdFamilies = %#v", catalog.NerdFamilies)
	}
}

func TestInternalFontsReportsUnavailableService(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	exitCode := cli.Run([]string{"_fonts"}, &stdout, &stderr, cli.Dependencies{})
	if exitCode != 1 || !strings.Contains(stderr.String(), "font enumeration unavailable") {
		t.Fatalf("exitCode=%d stderr=%q", exitCode, stderr.String())
	}
}

type osdStub struct {
	requests []osd.Request
	err      error
}

type reminderServiceStub struct {
	minutes     int
	message     string
	scheduled   reminders.ActiveReminder
	active      []reminders.ActiveReminder
	cancelledID string
	clearCount  int
	firedID     string
	snapshot    reminders.Snapshot
	err         error
}

func (stub *reminderServiceStub) Schedule(
	_ context.Context,
	minutes int,
	message string,
) (reminders.ActiveReminder, error) {
	stub.minutes = minutes
	stub.message = message
	return stub.scheduled, stub.err
}

func (stub *reminderServiceStub) List(context.Context) ([]reminders.ActiveReminder, error) {
	return stub.active, stub.err
}

func (stub *reminderServiceStub) Cancel(_ context.Context, id string) (reminders.Record, error) {
	stub.cancelledID = id
	return reminders.Record{ID: id}, stub.err
}

func (stub *reminderServiceStub) Clear(context.Context) (int, error) {
	return stub.clearCount, stub.err
}

func (stub *reminderServiceStub) Fire(_ context.Context, id string) error {
	stub.firedID = id
	return stub.err
}

func (stub *reminderServiceStub) Snapshot(context.Context) reminders.Snapshot {
	return stub.snapshot
}

type reminderUIStub struct {
	opened   bool
	messages []string
	err      error
}

type emojiUIStub struct {
	toggled bool
	err     error
}

type launcherUIStub struct {
	toggled     bool
	actionsMenu string
	err         error
}

func (stub *launcherUIStub) OpenActions(menu string) error {
	stub.actionsMenu = menu
	return stub.err
}

func (stub *launcherUIStub) ToggleLauncher() error {
	stub.toggled = true
	return stub.err
}

type keybindingUIStub struct {
	toggled bool
	err     error
}

func (stub *keybindingUIStub) ToggleKeybindings() error {
	stub.toggled = true
	return stub.err
}

type launcherRecentsStub struct {
	state launcher.Recents
	saved launcher.Recents
	err   error
}

type desktopActionsStub struct {
	snapshot    desktopactions.Snapshot
	runArgs     []string
	runErr      error
	validateErr error
}

func (stub *desktopActionsStub) ValidateRecording(string) error {
	return stub.validateErr
}

func (stub *desktopActionsStub) Run(_ context.Context, args []string) error {
	stub.runArgs = append([]string(nil), args...)
	return stub.runErr
}

func (stub desktopActionsStub) Snapshot(context.Context) desktopactions.Snapshot {
	return stub.snapshot
}

func (stub *launcherRecentsStub) Load() (launcher.Recents, error) {
	return stub.state, stub.err
}

func (stub *launcherRecentsStub) Save(state launcher.Recents) error {
	stub.saved = state
	return stub.err
}

func (stub *emojiUIStub) ToggleEmojiPicker() error {
	stub.toggled = true
	return stub.err
}

type emojiRecentsStub struct {
	state   emoji.Recents
	saved   emoji.Recents
	cleared bool
	err     error
}

func (stub *emojiRecentsStub) Load() (emoji.Recents, error) { return stub.state, stub.err }
func (stub *emojiRecentsStub) Save(state emoji.Recents) error {
	stub.saved = state
	return stub.err
}
func (stub *emojiRecentsStub) Clear() error {
	stub.cleared = true
	return stub.err
}

type clipboardHistoryStub struct {
	state      clipboard.History
	saved      clipboard.History
	imageEntry clipboard.Entry
	imageBytes []byte
	cleared    bool
	err        error
}

func (stub *clipboardHistoryStub) Load() (clipboard.History, error) { return stub.state, stub.err }
func (stub *clipboardHistoryStub) Save(state clipboard.History) error {
	stub.saved = state
	return stub.err
}
func (stub *clipboardHistoryStub) Clear() error {
	stub.cleared = true
	return stub.err
}
func (stub *clipboardHistoryStub) Record(
	state clipboard.History,
	contents []byte,
	maxEntries int,
) (clipboard.History, error) {
	if stub.err != nil {
		return clipboard.History{}, stub.err
	}
	return clipboard.RecordText(state, string(contents), maxEntries), nil
}
func (stub *clipboardHistoryStub) ImageData(string) (clipboard.Entry, []byte, error) {
	return stub.imageEntry, stub.imageBytes, stub.err
}

type clipboardWriterStub struct {
	mimeType string
	contents []byte
	err      error
}

func (stub *clipboardWriterStub) CopyImage(mimeType string, contents []byte) error {
	stub.mimeType = mimeType
	stub.contents = append([]byte(nil), contents...)
	return stub.err
}

func TestEmojiCommandTogglesPicker(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	ui := &emojiUIStub{}
	code := cli.Run([]string{"emoji"}, &stdout, &stderr, cli.Dependencies{EmojiUI: ui})
	if code != 0 || !ui.toggled || stdout.String() != "emoji picker toggled\n" {
		t.Fatalf("code=%d toggled=%v stdout=%q stderr=%q", code, ui.toggled, stdout.String(), stderr.String())
	}
}

type clipboardUIStub struct {
	toggled bool
	err     error
}

func (stub *clipboardUIStub) OpenClipboard() error {
	stub.toggled = true
	return stub.err
}

func TestClipboardCommandOpensHistory(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	ui := &clipboardUIStub{}
	code := cli.Run([]string{"clipboard"}, &stdout, &stderr, cli.Dependencies{ClipboardUI: ui})
	if code != 0 || !ui.toggled || stdout.String() != "clipboard opened\n" {
		t.Fatalf("code=%d toggled=%v stdout=%q stderr=%q", code, ui.toggled, stdout.String(), stderr.String())
	}
}

func TestLauncherAndKeybindCommandsToggleSurfaces(t *testing.T) {
	launcherUI := &launcherUIStub{}
	keybindingUI := &keybindingUIStub{}
	dependencies := cli.Dependencies{LauncherUI: launcherUI, KeybindingUI: keybindingUI}

	for _, testCase := range []struct {
		command string
		output  string
	}{
		{command: "launcher", output: "launcher toggled\n"},
		{command: "keybinds", output: "keybinds toggled\n"},
	} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{testCase.command}, &stdout, &stderr, dependencies)
		if code != 0 || stdout.String() != testCase.output || stderr.Len() != 0 {
			t.Fatalf("%s code=%d stdout=%q stderr=%q", testCase.command, code, stdout.String(), stderr.String())
		}
	}
	if !launcherUI.toggled || !keybindingUI.toggled {
		t.Fatalf("launcher=%v keybinds=%v", launcherUI.toggled, keybindingUI.toggled)
	}
}

func TestActionsCommandOpensLauncherMenu(t *testing.T) {
	ui := &launcherUIStub{}
	var stdout, stderr bytes.Buffer
	code := cli.Run([]string{"actions"}, &stdout, &stderr,
		cli.Dependencies{LauncherUI: ui})
	if code != 0 || ui.actionsMenu != "actions" || stdout.String() != "Actions menu opened\n" {
		t.Fatalf("code=%d menu=%q stdout=%q stderr=%q",
			code, ui.actionsMenu, stdout.String(), stderr.String())
	}
}

func TestInternalLauncherRecentCommands(t *testing.T) {
	stub := &launcherRecentsStub{state: launcher.Recents{
		Version: launcher.RecentsVersion,
		Entries: []string{"firefox.desktop"},
	}}
	t.Run("load", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_launcher-recents-load"}, &stdout, &stderr,
			cli.Dependencies{LauncherRecents: stub})
		if code != 0 || !strings.Contains(stdout.String(), `"entries":["firefox.desktop"]`) {
			t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
		}
	})
	t.Run("save", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		input := strings.NewReader(`{"version":1,"entries":["foot.desktop"]}`)
		code := cli.Run([]string{"_launcher-recents-save"}, &stdout, &stderr,
			cli.Dependencies{LauncherRecents: stub, Stdin: input})
		if code != 0 || !slices.Equal(stub.saved.Entries, []string{"foot.desktop"}) {
			t.Fatalf("code=%d saved=%#v stderr=%q", code, stub.saved, stderr.String())
		}
	})
}

func TestInternalEmojiRecentCommands(t *testing.T) {
	stub := &emojiRecentsStub{state: emoji.Recents{
		Version: emoji.RecentsVersion,
		Entries: []string{"😀"},
	}}
	t.Run("load", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_emoji-recents-load"}, &stdout, &stderr,
			cli.Dependencies{EmojiRecents: stub})
		if code != 0 || !strings.Contains(stdout.String(), `"entries":["😀"]`) {
			t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
		}
	})
	t.Run("save", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		input := strings.NewReader(`{"version":1,"entries":["🎉"]}`)
		code := cli.Run([]string{"_emoji-recents-save"}, &stdout, &stderr,
			cli.Dependencies{EmojiRecents: stub, Stdin: input})
		if code != 0 || len(stub.saved.Entries) != 1 || stub.saved.Entries[0] != "🎉" {
			t.Fatalf("code=%d saved=%#v stderr=%q", code, stub.saved, stderr.String())
		}
	})
	t.Run("clear", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_emoji-recents-clear"}, &stdout, &stderr,
			cli.Dependencies{EmojiRecents: stub})
		if code != 0 || !stub.cleared {
			t.Fatalf("code=%d cleared=%v stderr=%q", code, stub.cleared, stderr.String())
		}
	})
}

func TestInternalClipboardHistoryCommands(t *testing.T) {
	first := clipboard.RecordText(clipboard.EmptyHistory(), "first", 25)
	stub := &clipboardHistoryStub{state: first}
	t.Run("load", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-history-load"}, &stdout, &stderr,
			cli.Dependencies{ClipboardHistory: stub})
		if code != 0 || !strings.Contains(stdout.String(), `"kind":"text","text":"first"`) {
			t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
		}
	})
	t.Run("save", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		second := clipboard.RecordText(clipboard.EmptyHistory(), "second", 25)
		payload, err := json.Marshal(second)
		if err != nil {
			t.Fatal(err)
		}
		input := bytes.NewReader(payload)
		code := cli.Run([]string{"_clipboard-history-save"}, &stdout, &stderr,
			cli.Dependencies{ClipboardHistory: stub, Stdin: input})
		if code != 0 || len(stub.saved.Entries) != 1 || stub.saved.Entries[0].Text != "second" {
			t.Fatalf("code=%d saved=%#v stderr=%q", code, stub.saved, stderr.String())
		}
	})
	t.Run("clear", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-history-clear"}, &stdout, &stderr,
			cli.Dependencies{ClipboardHistory: stub})
		if code != 0 || !stub.cleared {
			t.Fatalf("code=%d cleared=%v stderr=%q", code, stub.cleared, stderr.String())
		}
	})
	t.Run("record", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "config.json")
		contents := `{"version":2,"bar":{"outputs":["*"],"height":36,"systemMetrics":"separate"},"weather":{"units":"auto"},"clock":{"format":"24h"},"clipboard":{"enabled":true,"maxEntries":5}}`
		if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
			t.Fatal(err)
		}
		state := clipboard.EmptyHistory()
		for _, value := range []string{"e", "d", "c", "b", "a"} {
			state = clipboard.RecordText(state, value, 5)
		}
		store := &clipboardHistoryStub{state: state}
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		input := strings.NewReader("z")
		code := cli.Run([]string{"_clipboard-record"}, &stdout, &stderr, cli.Dependencies{
			ConfigPath:       path,
			ClipboardHistory: store,
			Stdin:            input,
		})
		if code != 0 {
			t.Fatalf("code=%d stderr=%q", code, stderr.String())
		}
		texts := make([]string, 0, len(store.saved.Entries))
		for _, entry := range store.saved.Entries {
			texts = append(texts, entry.Text)
		}
		if !slices.Equal(texts, []string{"z", "a", "b", "c", "d"}) {
			t.Fatalf("saved=%#v", store.saved.Entries)
		}
	})
	t.Run("sensitive record skips save", func(t *testing.T) {
		t.Setenv("CLIPBOARD_STATE", "sensitive")
		store := &clipboardHistoryStub{state: clipboard.EmptyHistory()}
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-record"}, &stdout, &stderr, cli.Dependencies{
			ClipboardHistory: store,
			Stdin:            strings.NewReader("secret"),
		})
		if code != 0 || len(store.saved.Entries) != 0 {
			t.Fatalf("code=%d saved=%#v stderr=%q", code, store.saved, stderr.String())
		}
	})
	t.Run("copy image", func(t *testing.T) {
		store := &clipboardHistoryStub{
			imageEntry: clipboard.Entry{ID: "image-id", Kind: clipboard.KindImage, MimeType: "image/png"},
			imageBytes: []byte("png"),
		}
		writer := &clipboardWriterStub{}
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-copy-image", "image-id"}, &stdout, &stderr,
			cli.Dependencies{ClipboardHistory: store, ClipboardWriter: writer})
		if code != 0 || writer.mimeType != "image/png" || string(writer.contents) != "png" {
			t.Fatalf("code=%d writer=%#v stderr=%q", code, writer, stderr.String())
		}
	})
	t.Run("record disabled skips save", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "config.json")
		contents := `{"version":2,"bar":{"outputs":["*"],"height":36,"systemMetrics":"separate"},"weather":{"units":"auto"},"clock":{"format":"24h"},"clipboard":{"enabled":false,"maxEntries":25}}`
		if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
			t.Fatal(err)
		}
		store := &clipboardHistoryStub{}
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-record"}, &stdout, &stderr, cli.Dependencies{
			ConfigPath:       path,
			ClipboardHistory: store,
			Stdin:            strings.NewReader("text"),
		})
		if code != 0 || store.saved.Entries != nil {
			t.Fatalf("code=%d saved=%#v", code, store.saved)
		}
	})
	t.Run("unavailable", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run([]string{"_clipboard-history-load"}, &stdout, &stderr,
			cli.Dependencies{})
		if code != 1 || stderr.String() == "" {
			t.Fatalf("code=%d stderr=%q", code, stderr.String())
		}
	})
}

func TestDesktopActionsSnapshotCommand(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := cli.Run([]string{"_desktop-actions-snapshot"}, &stdout, &stderr, cli.Dependencies{
		DesktopActions: &desktopActionsStub{snapshot: desktopactions.Snapshot{
			ScreenshotModes: []string{"region"},
			PowerProfiles:   []desktopactions.Profile{{Name: "balanced", Active: true}},
		}},
	})
	if code != 0 || stderr.Len() != 0 ||
		!strings.Contains(stdout.String(), `"screenshotModes":["region"]`) ||
		!strings.Contains(stdout.String(), `"name":"balanced","active":true`) {
		t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
}

func TestCaptureCommandRunsMitishellOwnedAction(t *testing.T) {
	service := &desktopActionsStub{}
	var stdout, stderr bytes.Buffer
	code := cli.Run([]string{"capture", "region"}, &stdout, &stderr,
		cli.Dependencies{DesktopActions: service})
	if code != 0 || !slices.Equal(service.runArgs, []string{"screenshot", "region"}) {
		t.Fatalf("code=%d args=%#v stderr=%q", code, service.runArgs, stderr.String())
	}
}

func TestRecordCommandOpensAudioMenu(t *testing.T) {
	ui := &launcherUIStub{}
	service := &desktopActionsStub{}
	var stdout, stderr bytes.Buffer
	code := cli.Run([]string{"record", "output"}, &stdout, &stderr,
		cli.Dependencies{LauncherUI: ui, DesktopActions: service})
	if code != 0 || ui.actionsMenu != "record-output" || stdout.String() != "Recording menu opened\n" {
		t.Fatalf("code=%d menu=%q stdout=%q stderr=%q",
			code, ui.actionsMenu, stdout.String(), stderr.String())
	}
}

func TestRecordCommandReportsMissingDependencyBeforeOpeningMenu(t *testing.T) {
	ui := &launcherUIStub{}
	service := &desktopActionsStub{validateErr: errors.New(
		"Please install gpu-screen-recorder for screen recording")}
	var stdout, stderr bytes.Buffer
	code := cli.Run([]string{"record", "region"}, &stdout, &stderr,
		cli.Dependencies{LauncherUI: ui, DesktopActions: service})
	if code != 1 || ui.actionsMenu != "" ||
		!strings.Contains(stderr.String(), "Please install gpu-screen-recorder") {
		t.Fatalf("code=%d menu=%q stderr=%q", code, ui.actionsMenu, stderr.String())
	}
}

type updateServiceStub struct{ result updates.Result }

func (stub updateServiceStub) Snapshot(context.Context) updates.Result { return stub.result }

type nightLightServiceStub struct {
	snapshot nightlight.Snapshot
	actions  []nightlight.Action
	err      error
}

func (stub *nightLightServiceStub) Snapshot(context.Context) nightlight.Snapshot {
	return stub.snapshot
}

func (stub *nightLightServiceStub) Apply(
	_ context.Context,
	action nightlight.Action,
) (nightlight.Snapshot, error) {
	stub.actions = append(stub.actions, action)
	return stub.snapshot, stub.err
}

func TestNightLightStatusPrintsStablePlainState(t *testing.T) {
	for name, snapshot := range map[string]nightlight.Snapshot{
		"on":  {Available: true, Enabled: true, TemperatureKelvin: 4500},
		"off": {Available: true, Enabled: false, TemperatureKelvin: 6000},
	} {
		t.Run(name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			service := &nightLightServiceStub{snapshot: snapshot}
			osdControl := &osdStub{}
			code := cli.Run([]string{"night-light", "status"}, &stdout, &stderr,
				cli.Dependencies{NightLight: service, OSD: osdControl})
			want := name + " " + strconv.Itoa(snapshot.TemperatureKelvin) + " K\n"
			if code != 0 || stdout.String() != want || len(osdControl.requests) != 0 {
				t.Fatalf("code=%d stdout=%q osd=%v stderr=%q", code, stdout.String(), osdControl.requests, stderr.String())
			}
		})
	}
}

func TestNightLightMutationsApplyAndShowOSD(t *testing.T) {
	for _, action := range []string{"on", "off", "toggle"} {
		t.Run(action, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			enabled := action != "off"
			service := &nightLightServiceStub{snapshot: nightlight.Snapshot{
				Available: true, Enabled: enabled, TemperatureKelvin: 4200,
			}}
			osdControl := &osdStub{}
			code := cli.Run([]string{"night-light", action}, &stdout, &stderr,
				cli.Dependencies{NightLight: service, OSD: osdControl})
			if code != 0 || len(service.actions) != 1 || string(service.actions[0]) != action {
				t.Fatalf("code=%d actions=%v stderr=%q", code, service.actions, stderr.String())
			}
			wantState := "off"
			if enabled {
				wantState = "on"
			}
			if len(osdControl.requests) != 1 || osdControl.requests[0].Icon != "moon" ||
				osdControl.requests[0].Message != "Night light "+wantState+" · 4200 K" {
				t.Fatalf("OSD requests = %#v", osdControl.requests)
			}
		})
	}
}

func TestNightLightReportsUnavailableAndRejectsBadUsage(t *testing.T) {
	t.Run("unavailable", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		service := &nightLightServiceStub{snapshot: nightlight.Snapshot{
			Error: "hyprsunset unavailable: socket missing",
		}}
		code := cli.Run([]string{"night-light", "status"}, &stdout, &stderr,
			cli.Dependencies{NightLight: service})
		if code != 1 || !strings.Contains(stderr.String(), "socket missing") {
			t.Fatalf("code=%d stderr=%q", code, stderr.String())
		}
	})
	for _, args := range [][]string{{"night-light"}, {"night-light", "warm"}, {"night-light", "on", "now"}} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run(args, &stdout, &stderr, cli.Dependencies{})
		if code != 2 || !strings.Contains(stderr.String(), "<on|off|toggle|status>") {
			t.Fatalf("args=%v code=%d stderr=%q", args, code, stderr.String())
		}
	}
}

func TestInternalNightLightCommandsEncodeState(t *testing.T) {
	snapshot := nightlight.Snapshot{
		Available: true, Enabled: true, TemperatureKelvin: 3900,
	}
	service := &nightLightServiceStub{snapshot: snapshot}
	for _, args := range [][]string{
		{"_night-light-snapshot"},
		{"_night-light-action", "toggle"},
	} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run(args, &stdout, &stderr, cli.Dependencies{NightLight: service})
		if code != 0 || !strings.Contains(stdout.String(), `"temperatureKelvin":3900`) {
			t.Fatalf("args=%v code=%d stdout=%q stderr=%q", args, code, stdout.String(), stderr.String())
		}
	}
}

func TestNightLightActionFailureDoesNotShowOSD(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &nightLightServiceStub{err: errors.New("hyprsunset stopped")}
	osdControl := &osdStub{}
	code := cli.Run([]string{"night-light", "toggle"}, &stdout, &stderr,
		cli.Dependencies{NightLight: service, OSD: osdControl})
	if code != 1 || len(osdControl.requests) != 0 || !strings.Contains(stderr.String(), "hyprsunset stopped") {
		t.Fatalf("code=%d osd=%v stderr=%q", code, osdControl.requests, stderr.String())
	}
}

func TestInternalNightLightActionRejectsUnknownVerb(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &nightLightServiceStub{}
	code := cli.Run([]string{"_night-light-action", "warm"}, &stdout, &stderr,
		cli.Dependencies{NightLight: service})
	if code != 2 || len(service.actions) != 0 {
		t.Fatalf("code=%d actions=%v stderr=%q", code, service.actions, stderr.String())
	}
}

func TestUpdatesSnapshotEncodesServiceResult(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	want := updates.Result{Supported: true, System: updates.Source{Count: 3}}
	code := cli.Run([]string{"_updates-snapshot"}, &stdout, &stderr,
		cli.Dependencies{Updates: updateServiceStub{result: want}})
	if code != 0 || !strings.Contains(stdout.String(), `"count":3`) {
		t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
}

func (stub *reminderUIStub) OpenReminders() error {
	stub.opened = true
	return stub.err
}

func (stub *reminderUIStub) ReminderChanged(message string) error {
	stub.messages = append(stub.messages, message)
	return stub.err
}

func TestReminderOpensOverlayWithoutArguments(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	ui := &reminderUIStub{}
	code := cli.Run([]string{"reminder"}, &stdout, &stderr, cli.Dependencies{ReminderUI: ui})
	if code != 0 || !ui.opened || stdout.String() != "Reminder overlay opened\n" {
		t.Fatalf("code=%d opened=%v stdout=%q stderr=%q", code, ui.opened, stdout.String(), stderr.String())
	}
}

func TestReminderSchedulesWholeMinutesAndMessage(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &reminderServiceStub{scheduled: reminders.ActiveReminder{FireAt: 1_800_000_300}}
	ui := &reminderUIStub{}
	code := cli.Run(
		[]string{"reminder", "5", "Check", "the", "oven"},
		&stdout,
		&stderr,
		cli.Dependencies{Reminders: service, ReminderUI: ui},
	)
	if code != 0 || service.minutes != 5 || service.message != "Check the oven" {
		t.Fatalf("code=%d minutes=%d message=%q stderr=%q", code, service.minutes, service.message, stderr.String())
	}
	if len(ui.messages) != 1 || ui.messages[0] != "Reminder set for 5 minutes" {
		t.Fatalf("feedback = %v", ui.messages)
	}
	if !strings.HasPrefix(stdout.String(), "Reminder set for 5 minutes at ") {
		t.Fatalf("stdout = %q", stdout.String())
	}
}

func TestReminderListPrintsLabelRemainingAndLocalTime(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &reminderServiceStub{active: []reminders.ActiveReminder{{
		Label: "Tea", FireAt: 1_800_000_300, RemainingSeconds: 242,
	}}}
	code := cli.Run([]string{"reminder", "list"}, &stdout, &stderr,
		cli.Dependencies{Reminders: service})
	if code != 0 || !strings.Contains(stdout.String(), "Tea - 4m 2s remaining - ") {
		t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
}

func TestReminderListPrintsExactEmptyState(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := cli.Run([]string{"reminder", "list"}, &stdout, &stderr,
		cli.Dependencies{Reminders: &reminderServiceStub{}})
	if code != 0 || stdout.String() != "No active reminders\n" {
		t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
	}
}

func TestReminderClearCancelsPendingStateAndRefreshesShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &reminderServiceStub{clearCount: 3}
	ui := &reminderUIStub{}
	code := cli.Run([]string{"reminder", "clear"}, &stdout, &stderr,
		cli.Dependencies{Reminders: service, ReminderUI: ui})
	if code != 0 || stdout.String() != "Cleared 3 reminders\n" ||
		len(ui.messages) != 1 || ui.messages[0] != "All reminders cleared" {
		t.Fatalf("code=%d stdout=%q feedback=%v stderr=%q", code, stdout.String(), ui.messages, stderr.String())
	}
}

func TestReminderRejectsInvalidMinutes(t *testing.T) {
	for _, raw := range []string{"0", "-1", "1.5", "+5", "five"} {
		t.Run(raw, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			service := &reminderServiceStub{}
			code := cli.Run([]string{"reminder", raw}, &stdout, &stderr,
				cli.Dependencies{Reminders: service})
			if code != 2 || service.minutes != 0 {
				t.Fatalf("code=%d minutes=%d stderr=%q", code, service.minutes, stderr.String())
			}
		})
	}
}

func TestInternalReminderCommandsUseTypedIDs(t *testing.T) {
	service := &reminderServiceStub{snapshot: reminders.Snapshot{
		Available: true,
		Reminders: []reminders.ActiveReminder{{ID: "0123456789abcdef"}},
	}}
	ui := &reminderUIStub{}
	for _, testCase := range []struct {
		args []string
		id   string
	}{
		{args: []string{"_reminder-fire", "0123456789abcdef"}, id: "fire"},
		{args: []string{"_reminder-cancel", "0123456789abcdef"}, id: "cancel"},
	} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		code := cli.Run(testCase.args, &stdout, &stderr,
			cli.Dependencies{Reminders: service, ReminderUI: ui})
		if code != 0 {
			t.Fatalf("%s code=%d stderr=%q", testCase.id, code, stderr.String())
		}
	}
	if service.firedID != "0123456789abcdef" || service.cancelledID != "0123456789abcdef" {
		t.Fatalf("fire=%q cancel=%q", service.firedID, service.cancelledID)
	}
	var snapshotOutput bytes.Buffer
	var snapshotError bytes.Buffer
	if code := cli.Run([]string{"_reminder-snapshot"}, &snapshotOutput, &snapshotError,
		cli.Dependencies{Reminders: service}); code != 0 ||
		!strings.Contains(snapshotOutput.String(), `"id":"0123456789abcdef"`) {
		t.Fatalf("code=%d stdout=%q stderr=%q", code, snapshotOutput.String(), snapshotError.String())
	}
}

func (stub *osdStub) ShowOSD(request osd.Request) error {
	stub.requests = append(stub.requests, request)
	return stub.err
}

func TestOSDPassesValidatedStateToShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &osdStub{}
	code := cli.Run([]string{
		"osd",
		"--icon", "reminder",
		"--message", "Tea is ready",
		"--progress", "62.5",
		"--duration", "2400",
	}, &stdout, &stderr, cli.Dependencies{OSD: stub})
	if code != 0 || len(stub.requests) != 1 {
		t.Fatalf("code=%d requests=%#v stderr=%q", code, stub.requests, stderr.String())
	}
	request := stub.requests[0]
	if request.Icon != "reminder" || request.Message != "Tea is ready" ||
		request.Progress == nil || *request.Progress != 62.5 || request.DurationMS != 2400 {
		t.Fatalf("request = %#v", request)
	}
	if stdout.String() != "OSD shown\n" {
		t.Fatalf("stdout = %q", stdout.String())
	}
}

func TestOSDUsesDefaultDurationAndPreservesGlyph(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &osdStub{}
	code := cli.Run([]string{"osd", "--icon", "󰀻"}, &stdout, &stderr,
		cli.Dependencies{OSD: stub})
	if code != 0 || len(stub.requests) != 1 {
		t.Fatalf("code=%d requests=%#v stderr=%q", code, stub.requests, stderr.String())
	}
	if stub.requests[0].Icon != "󰀻" || stub.requests[0].DurationMS != osd.DefaultDurationMS {
		t.Fatalf("request = %#v", stub.requests[0])
	}
}

func TestOSDRejectsInvalidInput(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{name: "empty", args: []string{"osd"}},
		{name: "negative progress", args: []string{"osd", "--progress", "-1"}},
		{name: "nan progress", args: []string{"osd", "--progress", "NaN"}},
		{name: "short duration", args: []string{"osd", "--message", "x", "--duration", "249"}},
		{name: "infinite duration", args: []string{"osd", "--message", "x", "--duration", "+Inf"}},
		{name: "remote icon", args: []string{"osd", "--icon", "https://example.com/icon.png"}},
		{name: "positional text", args: []string{"osd", "hello"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &osdStub{}
			code := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{OSD: stub})
			if code != 2 || len(stub.requests) != 0 {
				t.Fatalf("code=%d requests=%#v stderr=%q", code, stub.requests, stderr.String())
			}
		})
	}
}

func TestOSDReportsUnavailableShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &osdStub{err: errors.New("shell not running")}
	code := cli.Run([]string{"osd", "--message", "hello"}, &stdout, &stderr,
		cli.Dependencies{OSD: stub})
	if code != 1 || !strings.Contains(stderr.String(), "shell not running") {
		t.Fatalf("code=%d stderr=%q", code, stderr.String())
	}
}

type displaySetCall struct {
	connector string
	value     int
}

type displayServiceStub struct {
	discover display.Result
	setCalls []displaySetCall
	set      display.Result
}

type notificationHistoryStub struct {
	state    notifications.State
	saved    notifications.State
	cleared  bool
	media    notifications.MediaImport
	mediaURL string
	err      error
}

func (stub *notificationHistoryStub) Load() (notifications.State, error) {
	return stub.state, stub.err
}

func (stub *notificationHistoryStub) Save(state notifications.State) error {
	stub.saved = state
	return stub.err
}

func (stub *notificationHistoryStub) Clear() error {
	stub.cleared = true
	return stub.err
}

func (stub *notificationHistoryStub) ImportMedia(media notifications.MediaImport) (string, error) {
	stub.media = media
	return stub.mediaURL, stub.err
}

func TestInternalNotificationHistoryCommands(t *testing.T) {
	state := notifications.State{
		Version:    notifications.HistoryVersion,
		LastSeenAt: 100,
		Entries: []notifications.Entry{{
			RecordID:  "100-1",
			Urgency:   1,
			Timestamp: 100,
		}},
	}
	t.Run("load", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		stub := &notificationHistoryStub{state: state}
		code := cli.Run([]string{"_notification-history-load"}, &stdout, &stderr,
			cli.Dependencies{NotificationHistory: stub})
		if code != 0 || !strings.Contains(stdout.String(), `"recordId":"100-1"`) {
			t.Fatalf("code=%d stdout=%q stderr=%q", code, stdout.String(), stderr.String())
		}
	})
	t.Run("save", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		stub := &notificationHistoryStub{}
		payload, err := json.Marshal(state)
		if err != nil {
			t.Fatal(err)
		}
		code := cli.Run([]string{"_notification-history-save"}, &stdout, &stderr,
			cli.Dependencies{NotificationHistory: stub, Stdin: bytes.NewReader(payload)})
		if code != 0 || stub.saved.LastSeenAt != 100 {
			t.Fatalf("code=%d saved=%#v stderr=%q", code, stub.saved, stderr.String())
		}
	})
	t.Run("clear", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		stub := &notificationHistoryStub{}
		code := cli.Run([]string{"_notification-history-clear"}, &stdout, &stderr,
			cli.Dependencies{NotificationHistory: stub})
		if code != 0 || !stub.cleared {
			t.Fatalf("code=%d cleared=%v stderr=%q", code, stub.cleared, stderr.String())
		}
	})
	t.Run("import media", func(t *testing.T) {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		stub := &notificationHistoryStub{mediaURL: "file:///state/media.png"}
		payload := `{"recordId":"100-1","role":"image","source":"/tmp/capture.png","temporary":true}`
		code := cli.Run([]string{"_notification-history-import"}, &stdout, &stderr,
			cli.Dependencies{NotificationHistory: stub, Stdin: strings.NewReader(payload)})
		if code != 0 || !stub.media.Temporary || stub.media.Role != "image" {
			t.Fatalf("code=%d media=%#v stderr=%q", code, stub.media, stderr.String())
		}
	})
}

func TestInternalNotificationHistorySaveRejectsUnknownFields(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &notificationHistoryStub{}
	code := cli.Run([]string{"_notification-history-save"}, &stdout, &stderr,
		cli.Dependencies{
			NotificationHistory: stub,
			Stdin: strings.NewReader(
				`{"version":1,"lastSeenAt":0,"entries":[],"surprise":true}`,
			),
		})
	if code != 2 {
		t.Fatalf("code=%d stderr=%q", code, stderr.String())
	}
}

func (stub *controlStub) Volume(action string) error {
	stub.volumeCalls = append(stub.volumeCalls, action)
	return stub.err
}

func (stub *controlStub) VolumeSet(value int) error {
	stub.volumeSet = append(stub.volumeSet, value)
	return stub.err
}

func (stub *controlStub) Mic(action string) error {
	stub.micCalls = append(stub.micCalls, action)
	return stub.err
}

func (stub *controlStub) MicSet(value int) error {
	stub.micSet = append(stub.micSet, value)
	return stub.err
}

func (stub *controlStub) Brightness(action string) error {
	stub.brightness = append(stub.brightness, action)
	return stub.err
}

func (stub *controlStub) BrightnessSet(value int) error {
	stub.brightnessSet = append(stub.brightnessSet, value)
	return stub.err
}

func (stub *controlStub) ToggleSettings(page string) error {
	stub.settingsPages = append(stub.settingsPages, page)
	return stub.err
}

func (stub *displayServiceStub) Discover(context.Context) display.Result {
	return stub.discover
}

func (stub *displayServiceStub) Set(_ context.Context, connector string, value int) display.Result {
	stub.setCalls = append(stub.setCalls, displaySetCall{connector: connector, value: value})
	return stub.set
}

type doctorStub struct {
	checks []cli.Check
}

type weatherStub struct {
	calls    int
	enabled  bool
	location string
}

func (stub *weatherStub) Snapshot(
	_ context.Context,
	enabled bool,
	location string,
	_ weather.Units,
) weather.Result {
	stub.calls++
	stub.enabled = enabled
	stub.location = location
	state := weather.Ready
	if !enabled {
		state = weather.Disabled
	}
	return weather.Result{State: state}
}

func (stub doctorStub) Checks() []cli.Check {
	return stub.checks
}

func (stub shellStub) Ping() error {
	return stub.pingErr
}

func (stub shellStub) Reload() error {
	return stub.reloadErr
}

func (stub shellStub) ToggleNotifications() error {
	return stub.notificationsErr
}

func (stub shellStub) OpenPowerMenu() error {
	return stub.powerErr
}

type powerStub struct {
	capabilities power.Capabilities
	calls        []power.Action
	err          error
}

func (stub *powerStub) Capabilities(context.Context) (power.Capabilities, error) {
	return stub.capabilities, stub.err
}

func (stub *powerStub) Run(_ context.Context, action power.Action) error {
	stub.calls = append(stub.calls, action)
	return stub.err
}

func TestInternalPowerCapabilitiesEncodesResult(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		PowerService: &powerStub{capabilities: power.Capabilities{
			Suspend:   true,
			Hibernate: false,
		}},
	}

	exitCode := cli.Run([]string{"_power-capabilities"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "{\"suspend\":true,\"hibernate\":false}\n" {
		t.Fatalf("stdout = %q", got)
	}
}

func TestInternalPowerActionRunsRequestedAction(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &powerStub{}

	exitCode := cli.Run([]string{"_power-action", "lock"}, &stdout, &stderr,
		cli.Dependencies{PowerService: stub})

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "power action executed\n" {
		t.Fatalf("stdout = %q", got)
	}
	if len(stub.calls) != 1 || stub.calls[0] != power.Lock {
		t.Fatalf("calls = %v", stub.calls)
	}
}

func TestInternalPowerActionReportsFailure(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &powerStub{err: errors.New("logind unreachable")}

	exitCode := cli.Run([]string{"_power-action", "suspend"}, &stdout, &stderr,
		cli.Dependencies{PowerService: stub})

	if exitCode != 1 {
		t.Fatalf("Run() exit code = %d, want failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "logind unreachable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestPingPrintsPongOnlyWhenShellAnswers(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}

	exitCode := cli.Run([]string{"ping"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "pong\n" {
		t.Fatalf("stdout = %q, want pong", got)
	}
}

func TestPingReportsUnreachableShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{pingErr: errors.New("not running")},
	}

	exitCode := cli.Run([]string{"ping"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() returned success for an unreachable shell")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if got := stderr.String(); got != "mitishell: shell unavailable: not running\n" {
		t.Fatalf("stderr = %q", got)
	}
}

func TestReloadReportsSuccessfulRequest(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}

	exitCode := cli.Run([]string{"reload"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "reload requested\n" {
		t.Fatalf("stdout = %q", got)
	}
}

func TestNotificationsDndTogglesThroughShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{Shell: shellStub{}}

	exitCode := cli.Run([]string{"notifications", "dnd"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "do not disturb toggled\n" {
		t.Fatalf("stdout = %q", got)
	}
}

func TestSettingsOpensWindow(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	settings := &controlStub{}
	dependencies := cli.Dependencies{SettingsSurface: settings}

	exitCode := cli.Run([]string{"settings"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "settings toggled\n" {
		t.Fatalf("stdout = %q", got)
	}
	if !slices.Equal(settings.settingsPages, []string{"overview"}) {
		t.Fatalf("pages = %v", settings.settingsPages)
	}
}

func TestSettingsReportsUnavailableAction(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		SettingsSurface: &controlStub{err: errors.New("IPC open failed")},
	}

	exitCode := cli.Run([]string{"settings"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() returned success for unavailable settings")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if got := stderr.String(); got != "mitishell: settings unavailable: IPC open failed\n" {
		t.Fatalf("stderr = %q", got)
	}
}

func TestPowerMenuReportsUnavailableAction(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		Shell: shellStub{powerErr: errors.New("wlogout not found")},
	}

	exitCode := cli.Run([]string{"power", "menu"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() returned success for an unavailable power menu")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if got := stderr.String(); got != "mitishell: power menu unavailable: wlogout not found\n" {
		t.Fatalf("stderr = %q", got)
	}
}

func TestConfigPathPrintsCanonicalPath(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	path := filepath.Join(t.TempDir(), "mitishell", "config.json")
	dependencies := cli.Dependencies{ConfigPath: path, Shell: shellStub{}}

	exitCode := cli.Run([]string{"config", "path"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != path+"\n" {
		t.Fatalf("stdout = %q, want %q", got, path)
	}
}

func TestConfigValidateAcceptsDefaultsWhenFileIsMissing(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}

	exitCode := cli.Run([]string{"config", "validate"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "valid\n" {
		t.Fatalf("stdout = %q", got)
	}
}

func TestConfigValidateReportsInvalidFile(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{"version":3}`), 0o600); err != nil {
		t.Fatal(err)
	}
	dependencies := cli.Dependencies{ConfigPath: path, Shell: shellStub{}}

	exitCode := cli.Run([]string{"config", "validate"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() accepted invalid config")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if !strings.Contains(stderr.String(), "mitishell: invalid config:") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestConfigSetPersistsTypedValueAndGetPrintsJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	dependencies := cli.Dependencies{ConfigPath: path, Shell: shellStub{}}

	var setOut bytes.Buffer
	var setErr bytes.Buffer
	if code := cli.Run(
		[]string{"config", "set", "weather.enabled", "true"},
		&setOut,
		&setErr,
		dependencies,
	); code != 0 {
		t.Fatalf("config set exit code = %d, stderr = %q", code, setErr.String())
	}
	if got := setOut.String(); got != "updated weather.enabled\n" {
		t.Fatalf("config set stdout = %q", got)
	}

	var getOut bytes.Buffer
	var getErr bytes.Buffer
	if code := cli.Run(
		[]string{"config", "get", "weather.enabled"},
		&getOut,
		&getErr,
		dependencies,
	); code != 0 {
		t.Fatalf("config get exit code = %d, stderr = %q", code, getErr.String())
	}
	if got := getOut.String(); got != "true\n" {
		t.Fatalf("config get stdout = %q", got)
	}
}

func TestInternalConfigResolveReturnsDefaultsForInvalidColdStart(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{"version":2}`), 0o600); err != nil {
		t.Fatal(err)
	}
	dependencies := cli.Dependencies{ConfigPath: path, Shell: shellStub{}}

	exitCode := cli.Run([]string{"_config-resolve"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() did not report fallback from invalid config")
	}
	if !strings.Contains(stdout.String(), `"version":2`) {
		t.Fatalf("stdout does not contain normalized defaults: %q", stdout.String())
	}
	if !strings.Contains(stderr.String(), "using defaults") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestInternalWeatherSnapshotKeepsDefaultOptOutDisabled(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	provider := &weatherStub{}
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
		Weather:    provider,
	}

	exitCode := cli.Run(
		[]string{"_weather-snapshot", "celsius"},
		&stdout,
		&stderr,
		dependencies,
	)

	if exitCode != 0 || provider.calls != 1 || provider.enabled {
		t.Fatalf("exit=%d calls=%d enabled=%v stderr=%q", exitCode, provider.calls, provider.enabled, stderr.String())
	}
	var result weather.Result
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("decode output: %v", err)
	}
	if result.State != weather.Disabled {
		t.Fatalf("result = %#v", result)
	}
}

func TestWeatherLocationPersistsManualAndAutomaticValues(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	dependencies := cli.Dependencies{ConfigPath: path, Shell: shellStub{}}
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if code := cli.Run([]string{"weather", "location", " New", "York "}, &stdout, &stderr, dependencies); code != 0 {
		t.Fatalf("manual exit=%d stderr=%q", code, stderr.String())
	}
	loaded, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Weather.Location != "New York" {
		t.Fatalf("location = %q", loaded.Weather.Location)
	}
	stdout.Reset()
	stderr.Reset()
	if code := cli.Run([]string{"weather", "location", "auto"}, &stdout, &stderr, dependencies); code != 0 {
		t.Fatalf("auto exit=%d stderr=%q", code, stderr.String())
	}
	loaded, err = config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Weather.Location != "" || stdout.String() != "weather location set to auto\n" {
		t.Fatalf("location=%q stdout=%q", loaded.Weather.Location, stdout.String())
	}
}

func TestDoctorReportsRequiredFailuresAndOptionalWarnings(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
		Doctor: doctorStub{checks: []cli.Check{
			{Name: "quickshell", Status: cli.StatusOK, Detail: "0.3.0"},
			{Name: "ddcutil", Status: cli.StatusWarning, Detail: "not found"},
			{Name: "hyprland", Status: cli.StatusFailure, Detail: "session unavailable"},
		}},
	}

	exitCode := cli.Run([]string{"doctor"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() returned success despite required doctor failure")
	}
	want := "[ok] quickshell: 0.3.0\n[warn] ddcutil: not found\n[fail] hyprland: session unavailable\n"
	if got := stdout.String(); got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
}

func TestVolumeActionsApplyThroughShell(t *testing.T) {
	cases := []struct {
		name     string
		args     []string
		stdout   string
		recorder func(stub *controlStub) string
	}{
		{
			name:   "volume up",
			args:   []string{"volume", "up"},
			stdout: "volume updated\n",
			recorder: func(stub *controlStub) string {
				return strings.Join(stub.volumeCalls, ",")
			},
		},
		{
			name:   "volume down",
			args:   []string{"volume", "down"},
			stdout: "volume updated\n",
			recorder: func(stub *controlStub) string {
				return strings.Join(stub.volumeCalls, ",")
			},
		},
		{
			name:   "mic mute",
			args:   []string{"mic", "mute"},
			stdout: "microphone updated\n",
			recorder: func(stub *controlStub) string {
				return strings.Join(stub.micCalls, ",")
			},
		},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &controlStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{AudioControl: stub})

			if exitCode != 0 {
				t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
			}
			if got := stdout.String(); got != testCase.stdout {
				t.Fatalf("stdout = %q, want %q", got, testCase.stdout)
			}
			if got := testCase.recorder(stub); got == "" {
				t.Fatal("action was not applied")
			}
		})
	}
}

func TestVolumeSetAppliesAbsoluteValue(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &controlStub{}

	exitCode := cli.Run([]string{"volume", "set", "80"}, &stdout, &stderr, cli.Dependencies{AudioControl: stub})

	if exitCode != 0 {
		t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "volume updated\n" {
		t.Fatalf("stdout = %q", got)
	}
	if len(stub.volumeSet) != 1 || stub.volumeSet[0] != 80 {
		t.Fatalf("volumeSet calls = %v", stub.volumeSet)
	}
}

func TestAudioActionsRejectInvalidUsage(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{"volume alone", []string{"volume"}},
		{"volume bad action", []string{"volume", "frob"}},
		{"volume set without value", []string{"volume", "set"}},
		{"volume set above range", []string{"volume", "set", "151"}},
		{"volume set not a number", []string{"volume", "set", "loud"}},
		{"mic set negative", []string{"mic", "set", "-1"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{AudioControl: &controlStub{}})

			if exitCode != 2 {
				t.Fatalf("exit code = %d, want usage failure", exitCode)
			}
			if !strings.Contains(stderr.String(), "usage: mitishell") {
				t.Fatalf("stderr = %q", stderr.String())
			}
		})
	}
}

func TestAudioActionsReportUnavailableControl(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := cli.Run([]string{"volume", "up"}, &stdout, &stderr, cli.Dependencies{})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want unavailable failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "volume actions unavailable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestAudioActionsReportShellFailure(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &controlStub{err: errors.New("shell not running")}

	exitCode := cli.Run([]string{"mic", "mute"}, &stdout, &stderr, cli.Dependencies{AudioControl: stub})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want failure", exitCode)
	}
	if got := stderr.String(); got != "mitishell: microphone unavailable: shell not running\n" {
		t.Fatalf("stderr = %q", got)
	}
}

func TestBrightnessActionsApplyThroughShell(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &controlStub{}

	exitCode := cli.Run([]string{"brightness", "up"}, &stdout, &stderr, cli.Dependencies{DisplayControl: stub})

	if exitCode != 0 {
		t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "brightness updated\n" {
		t.Fatalf("stdout = %q", got)
	}
	if strings.Join(stub.brightness, ",") != "up" {
		t.Fatalf("brightness calls = %v", stub.brightness)
	}
}

func TestBrightnessSetAppliesAbsoluteValue(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stub := &controlStub{}

	exitCode := cli.Run([]string{"brightness", "set", "0"}, &stdout, &stderr, cli.Dependencies{DisplayControl: stub})

	if exitCode != 0 {
		t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if len(stub.brightnessSet) != 1 || stub.brightnessSet[0] != 0 {
		t.Fatalf("brightnessSet calls = %v", stub.brightnessSet)
	}
}

func TestBrightnessActionsRejectInvalidUsage(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{"brightness alone", []string{"brightness"}},
		{"brightness mute", []string{"brightness", "mute"}},
		{"brightness set above range", []string{"brightness", "set", "101"}},
		{"brightness set not a number", []string{"brightness", "set", "bright"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{DisplayControl: &controlStub{}})

			if exitCode != 2 {
				t.Fatalf("exit code = %d, want usage failure", exitCode)
			}
			if !strings.Contains(stderr.String(), "usage: mitishell brightness") {
				t.Fatalf("stderr = %q", stderr.String())
			}
		})
	}
}

func TestBrightnessReportsUnavailableControl(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := cli.Run([]string{"brightness", "up"}, &stdout, &stderr, cli.Dependencies{})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want unavailable failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "brightness actions unavailable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestInternalDisplayDiscoverEncodesResult(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &displayServiceStub{discover: display.Result{
		State: display.Ready,
		Displays: []display.Display{
			{Connector: "DP-4", Bus: 8, Brightness: 55, Max: 100},
		},
	}}

	exitCode := cli.Run([]string{"_display-discover"}, &stdout, &stderr, cli.Dependencies{DisplayService: service})

	if exitCode != 0 {
		t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	var result display.Result
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("decode output: %v", err)
	}
	if result.State != display.Ready || len(result.Displays) != 1 || result.Displays[0].Connector != "DP-4" {
		t.Fatalf("result = %#v", result)
	}
}

func TestInternalDisplayDiscoverReportsMissingService(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := cli.Run([]string{"_display-discover"}, &stdout, &stderr, cli.Dependencies{})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "display discovery unavailable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestInternalDisplaySetAppliesValue(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	service := &displayServiceStub{set: display.Result{State: display.Ready}}

	exitCode := cli.Run([]string{"_display-set", "all", "55"}, &stdout, &stderr, cli.Dependencies{DisplayService: service})

	if exitCode != 0 {
		t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if len(service.setCalls) != 1 || service.setCalls[0].connector != "all" || service.setCalls[0].value != 55 {
		t.Fatalf("set calls = %#v", service.setCalls)
	}
	var result display.Result
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("decode output: %v", err)
	}
	if result.State != display.Ready {
		t.Fatalf("result = %#v", result)
	}
}

func TestInternalDisplaySetRejectsInvalidValue(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{"above range", []string{"_display-set", "all", "101"}},
		{"negative", []string{"_display-set", "all", "-5"}},
		{"not a number", []string{"_display-set", "all", "bright"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			service := &displayServiceStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{DisplayService: service})

			if exitCode != 2 {
				t.Fatalf("exit code = %d, want usage failure", exitCode)
			}
			if len(service.setCalls) != 0 {
				t.Fatalf("set should not run, got %#v", service.setCalls)
			}
		})
	}
}

func TestSettingsActionTogglesWithPage(t *testing.T) {
	cases := []struct {
		name string
		args []string
		page string
	}{
		{name: "defaults to overview", args: []string{"settings"}, page: "overview"},
		{name: "opens audio page", args: []string{"settings", "audio"}, page: "audio"},
		{name: "opens display page", args: []string{"settings", "display"}, page: "display"},
		{name: "opens system page", args: []string{"settings", "system"}, page: "system"},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &controlStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{SettingsSurface: stub})

			if exitCode != 0 {
				t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
			}
			if got := stdout.String(); got != "settings toggled\n" {
				t.Fatalf("stdout = %q", got)
			}
			if len(stub.settingsPages) != 1 || stub.settingsPages[0] != testCase.page {
				t.Fatalf("pages = %v, want %q", stub.settingsPages, testCase.page)
			}
		})
	}
}

func TestSettingsActionRejectsInvalidUsage(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{"unknown page", []string{"settings", "teleport"}},
		{"extra argument", []string{"settings", "audio", "now"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &controlStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{SettingsSurface: stub})

			if exitCode != 2 {
				t.Fatalf("exit code = %d, want usage failure", exitCode)
			}
			if len(stub.settingsPages) != 0 {
				t.Fatalf("toggle should not run, got %v", stub.settingsPages)
			}
		})
	}
}

func TestSettingsActionReportsUnavailableSurface(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := cli.Run([]string{"settings"}, &stdout, &stderr, cli.Dependencies{})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want unavailable failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "settings unavailable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}

func TestLegacyControlNamesMapToSettingsPages(t *testing.T) {
	settings := &controlStub{}
	for _, args := range [][]string{{"control"}, {"control", "home"}, {"control", "settings"}} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		if code := cli.Run(args, &stdout, &stderr, cli.Dependencies{SettingsSurface: settings}); code != 0 {
			t.Fatalf("Run(%v) code = %d, stderr = %q", args, code, stderr.String())
		}
	}
	if !slices.Equal(settings.settingsPages, []string{"overview", "overview", "system"}) {
		t.Fatalf("pages = %v", settings.settingsPages)
	}
}

func TestHelpCommandsPrintCommandList(t *testing.T) {
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}
	for _, argument := range []string{"help", "--help", "-h"} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer

		exitCode := cli.Run([]string{argument}, &stdout, &stderr, dependencies)

		if exitCode != 0 {
			t.Fatalf("Run(%q) exit code = %d, stderr = %q", argument, exitCode, stderr.String())
		}
		output := stdout.String()
		for _, command := range []string{
			"config", "doctor", "keybinds", "launcher", "night-light", "reminder", "volume",
		} {
			if !strings.Contains(output, command) {
				t.Fatalf("help output missing %q:\n%s", command, output)
			}
		}
	}
}

func TestVersionCommandsPrintReleaseVersion(t *testing.T) {
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}
	for _, argument := range []string{"version", "--version"} {
		var stdout bytes.Buffer
		var stderr bytes.Buffer

		exitCode := cli.Run([]string{argument}, &stdout, &stderr, dependencies)

		if exitCode != 0 {
			t.Fatalf("Run(%q) exit code = %d, stderr = %q", argument, exitCode, stderr.String())
		}
		if got := stdout.String(); got != "mitishell v"+cli.Version+"\n" {
			t.Fatalf("Run(%q) stdout = %q, want %q", argument, got, "mitishell v"+cli.Version)
		}
	}
}

func TestUnknownCommandPointsToHelp(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
	}

	exitCode := cli.Run([]string{"bogus"}, &stdout, &stderr, dependencies)

	if exitCode != 2 {
		t.Fatalf("exit code = %d, want usage failure", exitCode)
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty", stdout.String())
	}
	if got := stderr.String(); !strings.Contains(got, `"bogus"`) || !strings.Contains(got, "mitishell help") {
		t.Fatalf("stderr = %q, want unknown command with help pointer", got)
	}
}
