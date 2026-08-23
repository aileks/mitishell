package cli_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/cli"
	"github.com/aileks/mitishell/internal/display"
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
	controlPages  []string
	err           error
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

func (stub *controlStub) ToggleControlCenter(page string) error {
	stub.controlPages = append(stub.controlPages, page)
	return stub.err
}

func (stub *displayServiceStub) Discover(context.Context) display.Result {
	return stub.discover
}

func (stub *displayServiceStub) Set(_ context.Context, connector string, value int) display.Result {
	stub.setCalls = append(stub.setCalls, displaySetCall{connector: connector, value: value})
	return stub.set
}

type capabilityStub struct {
	capabilities cli.Capabilities
}

type doctorStub struct {
	checks []cli.Check
}

type weatherStub struct {
	calls   int
	enabled bool
}

func (stub *weatherStub) Snapshot(
	_ context.Context,
	enabled bool,
	_ weather.Units,
) weather.Result {
	stub.calls++
	stub.enabled = enabled
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

func (stub capabilityStub) Detect() cli.Capabilities {
	return stub.capabilities
}

func TestInternalCapabilitiesReportsAvailableCompatibilityActions(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		Capabilities: capabilityStub{capabilities: cli.Capabilities{
			Power: false,
		}},
	}

	exitCode := cli.Run([]string{"_capabilities"}, &stdout, &stderr, dependencies)

	if exitCode != 0 {
		t.Fatalf("Run() exit code = %d, stderr = %q", exitCode, stderr.String())
	}
	if got := stdout.String(); got != "{\"power\":false}\n" {
		t.Fatalf("stdout = %q", got)
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
	if err := os.WriteFile(path, []byte(`{"version":2}`), 0o600); err != nil {
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
	if !strings.Contains(stdout.String(), `"version":1`) {
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

func TestDoctorReportsRequiredFailuresAndOptionalWarnings(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	dependencies := cli.Dependencies{
		ConfigPath: filepath.Join(t.TempDir(), "config.json"),
		Shell:      shellStub{},
		Doctor: doctorStub{checks: []cli.Check{
			{Name: "quickshell", Status: cli.StatusOK, Detail: "0.3.0"},
			{Name: "missioncenter", Status: cli.StatusWarning, Detail: "not found"},
			{Name: "hyprland", Status: cli.StatusFailure, Detail: "session unavailable"},
		}},
	}

	exitCode := cli.Run([]string{"doctor"}, &stdout, &stderr, dependencies)

	if exitCode == 0 {
		t.Fatal("Run() returned success despite required doctor failure")
	}
	want := "[ok] quickshell: 0.3.0\n[warn] missioncenter: not found\n[fail] hyprland: session unavailable\n"
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

func TestControlActionTogglesWithPage(t *testing.T) {
	cases := []struct {
		name string
		args []string
		page string
	}{
		{name: "defaults to home", args: []string{"control"}, page: "home"},
		{name: "opens audio page", args: []string{"control", "audio"}, page: "audio"},
		{name: "opens display page", args: []string{"control", "display"}, page: "display"},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &controlStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{ControlCenter: stub})

			if exitCode != 0 {
				t.Fatalf("exit code = %d, stderr = %q", exitCode, stderr.String())
			}
			if got := stdout.String(); got != "control center toggled\n" {
				t.Fatalf("stdout = %q", got)
			}
			if len(stub.controlPages) != 1 || stub.controlPages[0] != testCase.page {
				t.Fatalf("pages = %v, want %q", stub.controlPages, testCase.page)
			}
		})
	}
}

func TestControlActionRejectsInvalidUsage(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{"unknown page", []string{"control", "network"}},
		{"extra argument", []string{"control", "audio", "now"}},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			var stdout bytes.Buffer
			var stderr bytes.Buffer
			stub := &controlStub{}

			exitCode := cli.Run(testCase.args, &stdout, &stderr, cli.Dependencies{ControlCenter: stub})

			if exitCode != 2 {
				t.Fatalf("exit code = %d, want usage failure", exitCode)
			}
			if len(stub.controlPages) != 0 {
				t.Fatalf("toggle should not run, got %v", stub.controlPages)
			}
		})
	}
}

func TestControlActionReportsUnavailableCenter(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	exitCode := cli.Run([]string{"control"}, &stdout, &stderr, cli.Dependencies{})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want unavailable failure", exitCode)
	}
	if !strings.Contains(stderr.String(), "control center unavailable") {
		t.Fatalf("stderr = %q", stderr.String())
	}
}
