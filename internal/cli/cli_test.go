package cli_test

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/cli"
)

type shellStub struct {
	pingErr   error
	reloadErr error
}

type doctorStub struct {
	checks []cli.Check
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
