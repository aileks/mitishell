package display_test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/aileks/mitishell/internal/display"
)

// recordingRunner captures invocations; probe runs connectors in parallel,
// so calls are guarded for the race detector.
type recordingRunner struct {
	mutex   sync.Mutex
	calls   [][]string
	respond func(args []string) (string, error)
}

func (runner *recordingRunner) run(_ context.Context, args ...string) (string, error) {
	runner.mutex.Lock()
	runner.calls = append(runner.calls, args)
	runner.mutex.Unlock()
	return runner.respond(args)
}

func (runner *recordingRunner) invocations() [][]string {
	runner.mutex.Lock()
	defer runner.mutex.Unlock()
	copied := make([][]string, len(runner.calls))
	copy(copied, runner.calls)
	return copied
}

func luminance(value int, max int) func(args []string) (string, error) {
	return func([]string) (string, error) {
		return fmt.Sprintf("VCP 10 C %d %d\n", value, max), nil
	}
}

func luminanceRunner(value int, max int) display.Runner {
	respond := luminance(value, max)
	return func(_ context.Context, _ ...string) (string, error) {
		return respond(nil)
	}
}

func busOf(call []string) string {
	for index, arg := range call {
		if arg == "--bus" && index+1 < len(call) {
			return call[index+1]
		}
	}
	return ""
}

func isGetvcp(call []string) bool {
	return slicesContains(call, "getvcp")
}

func isSetvcp(call []string) bool {
	return slicesContains(call, "setvcp")
}

func setvcpValue(call []string) string {
	for index, arg := range call {
		if arg == "setvcp" && index+2 < len(call) {
			return call[index+2]
		}
	}
	return ""
}

func slicesContains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func writeConnector(t *testing.T, root string, name string, status string, bus int) {
	t.Helper()
	directory := filepath.Join(root, "card0-"+name)
	if err := os.MkdirAll(directory, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, "status"), []byte(status), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(fmt.Sprintf("i2c-%d", bus), filepath.Join(directory, "ddc")); err != nil {
		t.Fatal(err)
	}
}

func cachePath(t *testing.T) string {
	return filepath.Join(t.TempDir(), "mitishell", "displays.json")
}

func TestDiscoverProbesConnectedConnectorsAndSkipsTheRest(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	writeConnector(t, root, "DP-5", "disconnected", 9)
	writeConnector(t, root, "HDMI-A-2", "connected", 11)
	if err := os.MkdirAll(filepath.Join(root, "card0"), 0o755); err != nil {
		t.Fatal(err)
	}
	runner := &recordingRunner{respond: func(args []string) (string, error) {
		if busOf(args) == "11" {
			return "", errors.New("ddcutil getvcp: DDC communication failed")
		}
		return luminance(55, 100)(args)
	}}
	service := display.NewService(runner.run, root, display.NewFileCache(cachePath(t)))

	result := service.Discover(context.Background())

	if result.State != display.Ready {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if len(result.Displays) != 1 {
		t.Fatalf("displays = %#v", result.Displays)
	}
	got := result.Displays[0]
	want := display.Display{Connector: "DP-4", Bus: 8, Brightness: 55, Max: 100}
	if got != want {
		t.Fatalf("display = %#v, want %#v", got, want)
	}
	if !strings.Contains(result.Error, "HDMI-A-2") {
		t.Fatalf("error should mention the dropped connector: %q", result.Error)
	}
	probed := map[string]bool{}
	for _, call := range runner.invocations() {
		if isGetvcp(call) {
			probed[busOf(call)] = true
		}
	}
	if !probed["8"] || !probed["11"] || probed["9"] {
		t.Fatalf("probed buses = %v", probed)
	}
}

func TestDiscoverReusesCacheWhileMappingMatches(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	first := &recordingRunner{respond: luminance(55, 100)}
	path := cachePath(t)
	service := display.NewService(first.run, root, display.NewFileCache(path))
	if result := service.Discover(context.Background()); result.State != display.Ready {
		t.Fatalf("first discover state = %q, error = %q", result.State, result.Error)
	}

	second := &recordingRunner{respond: func([]string) (string, error) {
		return "", errors.New("should not probe")
	}}
	cached := display.NewService(second.run, root, display.NewFileCache(path))

	result := cached.Discover(context.Background())

	if result.State != display.Ready {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if len(result.Displays) != 1 || result.Displays[0].Brightness != 55 {
		t.Fatalf("displays = %#v", result.Displays)
	}
	if calls := second.invocations(); len(calls) != 0 {
		t.Fatalf("expected no probing, got %v", calls)
	}
}

func TestDiscoverReprobesWhenMappingChanges(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	path := cachePath(t)
	runner := &recordingRunner{respond: luminance(55, 100)}
	service := display.NewService(runner.run, root, display.NewFileCache(path))
	if result := service.Discover(context.Background()); result.State != display.Ready {
		t.Fatalf("first discover state = %q, error = %q", result.State, result.Error)
	}

	writeConnector(t, root, "DP-6", "connected", 12)
	result := service.Discover(context.Background())

	if result.State != display.Ready {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if len(result.Displays) != 2 {
		t.Fatalf("displays = %#v", result.Displays)
	}
	if result.Displays[0].Connector != "DP-4" || result.Displays[1].Connector != "DP-6" {
		t.Fatalf("displays not sorted by connector: %#v", result.Displays)
	}
}

func TestDiscoverNormalizesAndRoundsNonHundredRanges(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	runner := &recordingRunner{respond: luminance(115, 120)}
	service := display.NewService(runner.run, root, display.NewFileCache(cachePath(t)))

	result := service.Discover(context.Background())

	if result.State != display.Ready {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if result.Displays[0].Brightness != 96 || result.Displays[0].Max != 120 {
		t.Fatalf("display = %#v, want 96 of 120", result.Displays[0])
	}
}

func TestDiscoverReportsUnavailableWithoutDdcutil(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	service := display.NewService(
		display.UnavailableRunner(fmt.Errorf("%w: not found", display.ErrUnavailable)),
		root,
		display.NewFileCache(cachePath(t)),
	)

	result := service.Discover(context.Background())

	if result.State != display.Unavailable {
		t.Fatalf("state = %q", result.State)
	}
	if !strings.Contains(result.Error, "ddcutil unavailable") {
		t.Fatalf("error = %q", result.Error)
	}
}

func TestDiscoverReportsMissingSysfsRoot(t *testing.T) {
	service := display.NewService(
		luminanceRunner(55, 100),
		filepath.Join(t.TempDir(), "missing"),
		display.NewFileCache(cachePath(t)),
	)

	result := service.Discover(context.Background())

	if result.State != display.Unavailable {
		t.Fatalf("state = %q", result.State)
	}
	if !strings.Contains(result.Error, "read connectors") {
		t.Fatalf("error = %q", result.Error)
	}
}

func TestSetWritesScaledValuesToEveryDisplay(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	writeConnector(t, root, "HDMI-A-2", "connected", 11)
	runner := &recordingRunner{respond: func(args []string) (string, error) {
		if isGetvcp(args) && busOf(args) == "8" {
			return luminance(55, 100)(args)
		}
		return luminance(60, 120)(args)
	}}
	path := cachePath(t)
	service := display.NewService(runner.run, root, display.NewFileCache(path))

	result := service.Set(context.Background(), "all", 60)

	if result.State != display.Ready || result.Error != "" {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	for _, item := range result.Displays {
		if item.Brightness != 60 {
			t.Fatalf("display %#v not updated", item)
		}
	}
	writes := map[string]string{}
	for _, call := range runner.invocations() {
		if isSetvcp(call) {
			writes[busOf(call)] = setvcpValue(call)
		}
	}
	if writes["8"] != "60" || writes["11"] != "72" {
		t.Fatalf("setvcp writes = %v, want 60 on bus 8 and 72 on bus 11", writes)
	}
	cached, err := display.NewFileCache(path).Load()
	if err != nil || len(cached) != 2 {
		t.Fatalf("cached displays = %#v, error = %v", cached, err)
	}
	for _, item := range cached {
		if item.Brightness != 60 {
			t.Fatalf("cache not updated: %#v", cached)
		}
	}
}

func TestSetClampsRequestedValue(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	runner := &recordingRunner{respond: func(args []string) (string, error) {
		if isSetvcp(args) {
			return "", nil
		}
		return luminance(55, 100)(args)
	}}
	service := display.NewService(runner.run, root, display.NewFileCache(cachePath(t)))

	high := service.Set(context.Background(), "all", 150)
	if high.State != display.Ready || high.Displays[0].Brightness != 100 {
		t.Fatalf("result = %#v", high)
	}
	for _, call := range runner.invocations() {
		if isSetvcp(call) && setvcpValue(call) != "100" {
			t.Fatalf("unclamped setvcp call: %v", call)
		}
	}

	low := service.Set(context.Background(), "all", 0)
	if low.State != display.Ready || low.Displays[0].Brightness != 1 {
		t.Fatalf("result = %#v, brightness never goes fully dark", low)
	}
	for _, call := range runner.invocations() {
		if isSetvcp(call) && setvcpValue(call) != "1" && setvcpValue(call) != "100" {
			t.Fatalf("setvcp outside clamp range: %v", call)
		}
	}
}

func TestSetReportsUnknownConnector(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	runner := &recordingRunner{respond: luminance(55, 100)}
	service := display.NewService(runner.run, root, display.NewFileCache(cachePath(t)))

	result := service.Set(context.Background(), "DP-9", 50)

	if result.State != display.Unavailable {
		t.Fatalf("state = %q", result.State)
	}
	if !strings.Contains(result.Error, "DP-9") {
		t.Fatalf("error = %q", result.Error)
	}
}

func TestSetRetriesOnceAfterStaleBusFailure(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	path := cachePath(t)
	var mutex sync.Mutex
	attempts := 0
	runner := &recordingRunner{respond: func(args []string) (string, error) {
		if isGetvcp(args) {
			return luminance(55, 100)(args)
		}
		mutex.Lock()
		defer mutex.Unlock()
		attempts++
		if attempts == 1 {
			return "", errors.New("ddcutil setvcp: invalid bus")
		}
		return "", nil
	}}
	service := display.NewService(runner.run, root, display.NewFileCache(path))
	if result := service.Discover(context.Background()); result.State != display.Ready {
		t.Fatalf("discover state = %q, error = %q", result.State, result.Error)
	}

	result := service.Set(context.Background(), "all", 70)

	if result.State != display.Ready || result.Error != "" {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if result.Displays[0].Brightness != 70 {
		t.Fatalf("display = %#v", result.Displays[0])
	}
	setvcpCount := 0
	for _, call := range runner.invocations() {
		if isSetvcp(call) {
			setvcpCount++
		}
	}
	if setvcpCount != 2 {
		t.Fatalf("setvcp attempts = %d, want one failure plus one retry", setvcpCount)
	}
	cached, err := display.NewFileCache(path).Load()
	if err != nil || len(cached) != 1 || cached[0].Brightness != 70 {
		t.Fatalf("cached displays = %#v, error = %v", cached, err)
	}
}

func TestSetMergesSingleConnectorIntoCache(t *testing.T) {
	root := t.TempDir()
	writeConnector(t, root, "DP-4", "connected", 8)
	writeConnector(t, root, "HDMI-A-2", "connected", 11)
	runner := &recordingRunner{respond: func(args []string) (string, error) {
		if isSetvcp(args) {
			return "", nil
		}
		return luminance(55, 100)(args)
	}}
	path := cachePath(t)
	service := display.NewService(runner.run, root, display.NewFileCache(path))
	if result := service.Discover(context.Background()); result.State != display.Ready {
		t.Fatalf("discover state = %q, error = %q", result.State, result.Error)
	}

	result := service.Set(context.Background(), "HDMI-A-2", 40)

	if result.State != display.Ready || result.Error != "" {
		t.Fatalf("state = %q, error = %q", result.State, result.Error)
	}
	if len(result.Displays) != 2 {
		t.Fatalf("result should keep the full display list: %#v", result.Displays)
	}
	cached, err := display.NewFileCache(path).Load()
	if err != nil || len(cached) != 2 {
		t.Fatalf("cached displays = %#v, error = %v", cached, err)
	}
	for _, item := range cached {
		if item.Connector == "DP-4" && item.Brightness != 55 {
			t.Fatalf("untouched display changed: %#v", cached)
		}
		if item.Connector == "HDMI-A-2" && item.Brightness != 40 {
			t.Fatalf("target display not updated: %#v", cached)
		}
	}
}
