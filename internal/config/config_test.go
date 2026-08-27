package config_test

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/config"
)

func TestMissingConfigUsesDefaultsWithoutCreatingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mitishell", "config.json")

	got, err := config.Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	want := config.Defaults()
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Load() = %#v, want %#v", got, want)
	}

	_, err = os.Stat(path)
	if !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("missing config was created or stat failed unexpectedly: %v", err)
	}
}

func TestLoadNormalizesMissingClockTimezones(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	contents := `{
  "version": 1,
  "bar": {"outputs":["*"],"height":36,"marginTop":6,"marginHorizontal":8,"showWindowTitle":true,"showMedia":true,"systemMetrics":"separate"},
  "clock": {"format":"24h","showDate":false},
  "weather": {"enabled":false,"units":"auto"},
  "calendar": {"showWeekNumbers":false},
  "motion": {"enabled":true,"reduced":false}
}`
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := config.Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if got.Clock.Timezones == nil || len(got.Clock.Timezones) != 0 {
		t.Fatalf("timezones = %#v, want empty array", got.Clock.Timezones)
	}
}

func TestWeatherLocationNormalizesAndValidates(t *testing.T) {
	cfg := config.Defaults()
	updated, err := config.SetField(cfg, "weather.location", "  New York  ")
	if err != nil {
		t.Fatal(err)
	}
	if updated.Weather.Location != "New York" {
		t.Fatalf("location = %q", updated.Weather.Location)
	}
	if got, err := config.GetField(updated, "weather.location"); err != nil || got != `"New York"` {
		t.Fatalf("get = %q, %v", got, err)
	}
	if _, err := config.SetField(cfg, "weather.location", "bad\nplace"); err == nil {
		t.Fatal("accepted control character")
	}
	if _, err := config.SetField(cfg, "weather.location", strings.Repeat("é", 81)); err == nil {
		t.Fatal("accepted more than 80 Unicode code points")
	}
}

func TestLoadReturnsValidatedConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	contents := `{
  "version": 1,
  "bar": {
    "outputs": ["DP-4"],
    "height": 40,
    "marginTop": 4,
    "marginHorizontal": 10,
    "showWindowTitle": false,
    "showMedia": true,
    "systemMetrics": "combined"
  },
  "clock": {
    "format": "24h-seconds",
    "showDate": true,
    "timezones": ["Europe/Berlin", "Pacific/Auckland"]
  },
  "calendar": {
    "showWeekNumbers": true
  },
  "weather": {
    "enabled": true,
    "units": "fahrenheit"
  },
  "motion": {
    "enabled": true,
    "reduced": true
  }
}`
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := config.Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	want := config.Config{
		Version: 1,
		Bar: config.Bar{
			Outputs:          []string{"DP-4"},
			Height:           40,
			MarginTop:        4,
			MarginHorizontal: 10,
			ShowMedia:        true,
			SystemMetrics:    "combined",
			Islands:          config.DefaultIslands(),
		},
		Clock: config.Clock{
			Format:    "24h-seconds",
			ShowDate:  true,
			Timezones: []string{"Europe/Berlin", "Pacific/Auckland"},
		},
		Calendar: config.Calendar{
			ShowWeekNumbers: true,
		},
		Weather: config.Weather{
			Enabled: true,
			Units:   "fahrenheit",
		},
		Motion: config.Motion{
			Enabled: true,
			Reduced: true,
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Load() = %#v, want %#v", got, want)
	}
}

func TestLoadFillsMissingClockSectionWithDefaults(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	contents := `{
  "version": 1,
  "bar": {"outputs": ["*"], "height": 36, "marginTop": 6, "marginHorizontal": 8, "showWindowTitle": true, "showMedia": true, "systemMetrics": "separate"},
  "calendar": {"showWeekNumbers": false},
  "weather": {"enabled": false, "units": "auto"},
  "motion": {"enabled": true, "reduced": false}
}`
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	got, err := config.Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	want := config.Defaults().Clock
	if !reflect.DeepEqual(got.Clock, want) {
		t.Fatalf("Load().Clock = %#v, want %#v", got.Clock, want)
	}
}

func TestLoadRejectsUnknownFields(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	contents := `{
  "version": 1,
  "bar": {
    "outputs": ["*"],
    "height": 36,
    "marginTop": 6,
    "marginHorizontal": 8,
    "showWindowTitle": true,
    "showMedia": true,
    "systemMetrics": "separate",
    "primaryOutput": "DP-4"
  },
  "weather": {"enabled": false, "units": "auto"},
  "motion": {"enabled": true, "reduced": false}
}`
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	if _, err := config.Load(path); err == nil {
		t.Fatal("Load() accepted an unknown field")
	}
}

func TestValidateRejectsWildcardMixedWithExplicitOutputs(t *testing.T) {
	cfg := config.Defaults()
	cfg.Bar.Outputs = []string{"*", "DP-4"}

	if err := config.Validate(cfg); err == nil {
		t.Fatal("Validate() accepted wildcard and explicit outputs together")
	}
}

func TestValidateRejectsInvalidValues(t *testing.T) {
	tests := map[string]func(*config.Config){
		"unsupported version": func(cfg *config.Config) { cfg.Version = 2 },
		"empty outputs":       func(cfg *config.Config) { cfg.Bar.Outputs = nil },
		"blank output":        func(cfg *config.Config) { cfg.Bar.Outputs = []string{""} },
		"duplicate output":    func(cfg *config.Config) { cfg.Bar.Outputs = []string{"DP-4", "DP-4"} },
		"short bar":           func(cfg *config.Config) { cfg.Bar.Height = 23 },
		"tall bar":            func(cfg *config.Config) { cfg.Bar.Height = 97 },
		"negative top margin": func(cfg *config.Config) { cfg.Bar.MarginTop = -1 },
		"large top margin":    func(cfg *config.Config) { cfg.Bar.MarginTop = 65 },
		"negative side margin": func(cfg *config.Config) {
			cfg.Bar.MarginHorizontal = -1
		},
		"large side margin": func(cfg *config.Config) { cfg.Bar.MarginHorizontal = 65 },
		"metrics mode":      func(cfg *config.Config) { cfg.Bar.SystemMetrics = "stacked" },
		"weather units":     func(cfg *config.Config) { cfg.Weather.Units = "kelvin" },
		"clock format":      func(cfg *config.Config) { cfg.Clock.Format = "swatch" },
		"blank timezone":    func(cfg *config.Config) { cfg.Clock.Timezones = []string{""} },
		"duplicate timezone": func(cfg *config.Config) {
			cfg.Clock.Timezones = []string{"Europe/Berlin", "Europe/Berlin"}
		},
		"unknown timezone": func(cfg *config.Config) { cfg.Clock.Timezones = []string{"Mars/Olympus"} },
		"too many timezones": func(cfg *config.Config) {
			cfg.Clock.Timezones = []string{
				"UTC", "Europe/Berlin", "Europe/London", "America/New_York",
				"America/Los_Angeles", "Asia/Tokyo", "Asia/Kolkata", "Australia/Sydney",
				"Pacific/Auckland",
			}
		},
	}

	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			cfg := config.Defaults()
			mutate(&cfg)
			if err := config.Validate(cfg); err == nil {
				t.Fatal("Validate() accepted invalid config")
			}
		})
	}
}

func TestWriteCreatesLoadablePrivateConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mitishell", "config.json")
	want := config.Defaults()
	want.Weather.Enabled = true

	if err := config.Write(path, want); err != nil {
		t.Fatalf("Write() error = %v", err)
	}

	got, err := config.Load(path)
	if err != nil {
		t.Fatalf("Load() after Write() error = %v", err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Load() after Write() = %#v, want %#v", got, want)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if gotMode := info.Mode().Perm(); gotMode != 0o600 {
		t.Fatalf("config permissions = %o, want 600", gotMode)
	}
}

func TestSetFieldUpdatesOnlyKnownTypedSetting(t *testing.T) {
	original := config.Defaults()

	updated, err := config.SetField(original, "bar.outputs", `["DP-4","HDMI-A-2"]`)
	if err != nil {
		t.Fatalf("SetField() error = %v", err)
	}

	if !reflect.DeepEqual(updated.Bar.Outputs, []string{"DP-4", "HDMI-A-2"}) {
		t.Fatalf("updated outputs = %#v", updated.Bar.Outputs)
	}
	if !reflect.DeepEqual(original.Bar.Outputs, []string{"*"}) {
		t.Fatalf("SetField() mutated original outputs = %#v", original.Bar.Outputs)
	}
	if updated.Bar.Height != original.Bar.Height {
		t.Fatal("SetField() changed an unrelated setting")
	}
}

func TestNormalizeIslandsDropsUnknownAndAppendsMissing(t *testing.T) {
	got := config.NormalizeIslands([]string{"weather", "bogus", "clock", "weather"})

	want := append(
		[]string{"weather", "clock"},
		config.DefaultIslands()[3:]...,
	)
	// DefaultIslands minus clock/weather, appended in default order.
	want = []string{"weather", "clock", "system", "audio", "keyboardLayout",
		"updates", "tray", "bluetooth", "control", "notifications",
		"reminders", "power"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("NormalizeIslands() = %#v, want %#v", got, want)
	}
}

func TestNormalizeIslandsEmptyBecomesDefault(t *testing.T) {
	got := config.NormalizeIslands(nil)
	if !reflect.DeepEqual(got, config.DefaultIslands()) {
		t.Fatalf("NormalizeIslands(nil) = %#v", got)
	}
}

func TestSetFieldNormalizesIslands(t *testing.T) {
	updated, err := config.SetField(
		config.Defaults(), "bar.islands", `["power","nope","clock"]`)
	if err != nil {
		t.Fatalf("SetField() error = %v", err)
	}

	first := updated.Bar.Islands[0]
	second := updated.Bar.Islands[1]
	if first != "power" || second != "clock" {
		t.Fatalf("islands order = %#v", updated.Bar.Islands)
	}
	if len(updated.Bar.Islands) != len(config.DefaultIslands()) {
		t.Fatalf("islands count = %d, want %d",
			len(updated.Bar.Islands), len(config.DefaultIslands()))
	}

	encoded, err := config.GetField(updated, "bar.islands")
	if err != nil {
		t.Fatalf("GetField() error = %v", err)
	}
	if !strings.Contains(encoded, `"power"`) || !strings.Contains(encoded, `"clock"`) {
		t.Fatalf("GetField() = %q", encoded)
	}
}

func TestSetAndGetKnownFields(t *testing.T) {
	tests := []struct {
		key   string
		value string
		want  string
	}{
		{key: "bar.height", value: "44", want: "44"},
		{key: "bar.marginTop", value: "12", want: "12"},
		{key: "bar.marginHorizontal", value: "14", want: "14"},
		{key: "bar.showWindowTitle", value: "false", want: "false"},
		{key: "bar.showMedia", value: "false", want: "false"},
		{key: "bar.systemMetrics", value: "combined", want: `"combined"`},
		{key: "weather.enabled", value: "true", want: "true"},
		{key: "weather.units", value: "celsius", want: `"celsius"`},
		{key: "clock.format", value: "12h-seconds", want: `"12h-seconds"`},
		{key: "clock.showDate", value: "true", want: "true"},
		{key: "clock.timezones", value: `["Europe/Berlin","UTC"]`, want: `["Europe/Berlin","UTC"]`},
		{key: "calendar.showWeekNumbers", value: "true", want: "true"},
		{key: "motion.enabled", value: "false", want: "false"},
		{key: "motion.reduced", value: "true", want: "true"},
	}

	for _, test := range tests {
		t.Run(test.key, func(t *testing.T) {
			updated, err := config.SetField(config.Defaults(), test.key, test.value)
			if err != nil {
				t.Fatalf("SetField() error = %v", err)
			}
			got, err := config.GetField(updated, test.key)
			if err != nil {
				t.Fatalf("GetField() error = %v", err)
			}
			if got != test.want {
				t.Fatalf("GetField() = %q, want %q", got, test.want)
			}
		})
	}
}

func TestSetFieldRejectsUnknownOrInvalidValues(t *testing.T) {
	tests := []struct {
		key   string
		value string
	}{
		{key: "bar.primaryOutput", value: "DP-4"},
		{key: "bar.height", value: "large"},
		{key: "bar.height", value: "10"},
		{key: "weather.enabled", value: "yes"},
		{key: "weather.units", value: "kelvin"},
		{key: "clock.format", value: "swatch"},
		{key: "clock.showDate", value: "maybe"},
		{key: "clock.timezones", value: "Europe/Berlin"},
		{key: "clock.timezones", value: `["Mars/Olympus"]`},
		{key: "calendar.showWeekNumbers", value: "sometimes"},
	}

	for _, test := range tests {
		t.Run(test.key+"="+test.value, func(t *testing.T) {
			if _, err := config.SetField(config.Defaults(), test.key, test.value); err == nil {
				t.Fatal("SetField() accepted an unknown field or invalid value")
			}
		})
	}
}

func TestPathUsesXDGConfigHome(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", root)

	want := filepath.Join(root, "mitishell", "config.json")
	got, err := config.Path()
	if err != nil {
		t.Fatalf("Path() error = %v", err)
	}
	if got != want {
		t.Fatalf("Path() = %q, want %q", got, want)
	}
}
