package nightlight_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/nightlight"
)

type response struct {
	output string
	err    error
}

type runnerStub struct {
	path      string
	pathErr   error
	responses []response
	calls     [][]string
	wait      bool
}

func (runner *runnerStub) LookPath(string) (string, error) {
	return runner.path, runner.pathErr
}

func (runner *runnerStub) Output(ctx context.Context, name string, args ...string) (string, error) {
	runner.calls = append(runner.calls, append([]string{name}, args...))
	if runner.wait {
		<-ctx.Done()
		return "", ctx.Err()
	}
	if len(runner.responses) == 0 {
		return "", errors.New("unexpected call")
	}
	result := runner.responses[0]
	runner.responses = runner.responses[1:]
	return result.output, result.err
}

func TestSnapshotReportsEnabledStateAndKelvin(t *testing.T) {
	runner := &runnerStub{path: "/usr/bin/hyprctl", responses: []response{
		{output: "false\n"},
		{output: "4500\n"},
	}}
	result := nightlight.NewService(runner).Snapshot(context.Background())
	if !result.Available || !result.Enabled || result.TemperatureKelvin != 4500 || result.Error != "" {
		t.Fatalf("result = %#v", result)
	}
	wantCalls := "hyprsunset identity get|hyprsunset temperature"
	gotCalls := strings.Join([]string{
		strings.Join(runner.calls[0][1:], " "),
		strings.Join(runner.calls[1][1:], " "),
	}, "|")
	if gotCalls != wantCalls {
		t.Fatalf("calls = %q, want %q", gotCalls, wantCalls)
	}
}

func TestSnapshotMapsIdentityTrueToOff(t *testing.T) {
	runner := &runnerStub{path: "hyprctl", responses: []response{
		{output: "true"},
		{output: "6000"},
	}}
	result := nightlight.NewService(runner).Snapshot(context.Background())
	if !result.Available || result.Enabled || result.TemperatureKelvin != 6000 {
		t.Fatalf("result = %#v", result)
	}
}

func TestSnapshotRejectsMissingStoppedAndMalformedState(t *testing.T) {
	t.Run("missing hyprctl", func(t *testing.T) {
		result := nightlight.NewService(&runnerStub{pathErr: errors.New("missing")}).Snapshot(context.Background())
		if result.Available || !strings.Contains(result.Error, "hyprctl not found") {
			t.Fatalf("result = %#v", result)
		}
	})
	t.Run("stopped hyprsunset", func(t *testing.T) {
		result := nightlight.NewService(&runnerStub{
			path:      "hyprctl",
			responses: []response{{err: errors.New("Couldn't connect to /run/user/1000/hypr/example/.hyprsunset.sock")}},
		}).Snapshot(context.Background())
		if result.Available || result.Error != "hyprsunset unavailable: hyprsunset is not running" {
			t.Fatalf("result = %#v", result)
		}
	})
	for name, responses := range map[string][]response{
		"identity":    {{output: "maybe"}},
		"temperature": {{output: "false"}, {output: "hot"}},
		"range":       {{output: "false"}, {output: "999"}},
	} {
		t.Run(name, func(t *testing.T) {
			result := nightlight.NewService(&runnerStub{
				path: "hyprctl", responses: responses,
			}).Snapshot(context.Background())
			if result.Available || result.Error == "" {
				t.Fatalf("result = %#v", result)
			}
		})
	}
}

func TestSnapshotTimesOut(t *testing.T) {
	result := nightlight.NewService(&runnerStub{
		path: "hyprctl", wait: true,
	}).Snapshot(context.Background())
	if result.Available || !strings.Contains(result.Error, "timed out") {
		t.Fatalf("result = %#v", result)
	}
}

func TestOnAndOffAreIdempotent(t *testing.T) {
	for name, action := range map[string]nightlight.Action{
		"on":  nightlight.On,
		"off": nightlight.Off,
	} {
		t.Run(name, func(t *testing.T) {
			enabled := action == nightlight.On
			identity := "true"
			temperature := "6000"
			if enabled {
				identity = "false"
				temperature = "4800"
			}
			runner := &runnerStub{path: "hyprctl", responses: []response{
				{output: identity}, {output: temperature},
			}}
			result, err := nightlight.NewService(runner).Apply(context.Background(), action)
			if err != nil || result.Enabled != enabled || len(runner.calls) != 2 {
				t.Fatalf("result=%#v err=%v calls=%v", result, err, runner.calls)
			}
		})
	}
}

func TestToggleAppliesOppositeIdentityAndReturnsFreshState(t *testing.T) {
	runner := &runnerStub{path: "hyprctl", responses: []response{
		{output: "true"}, {output: "4200"},
		{output: "ok"},
		{output: "ok"},
		{output: "false"}, {output: "4800"},
	}}
	result, err := nightlight.NewService(runner).Apply(context.Background(), nightlight.Toggle)
	if err != nil || !result.Enabled || result.TemperatureKelvin != 4800 {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	if got := strings.Join(runner.calls[2][1:], " "); got != "hyprsunset temperature 4800" {
		t.Fatalf("temperature call = %q", got)
	}
	if got := strings.Join(runner.calls[3][1:], " "); got != "hyprsunset identity false" {
		t.Fatalf("identity call = %q", got)
	}
}

func TestOnCorrectsEnabledTemperature(t *testing.T) {
	runner := &runnerStub{path: "hyprctl", responses: []response{
		{output: "false"}, {output: "6000"},
		{output: "ok"},
		{output: "false"}, {output: "4800"},
	}}
	result, err := nightlight.NewService(runner).Apply(context.Background(), nightlight.On)
	if err != nil || !result.Enabled || result.TemperatureKelvin != 4800 {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	if got := strings.Join(runner.calls[2][1:], " "); got != "hyprsunset temperature 4800" {
		t.Fatalf("temperature call = %q", got)
	}
	if len(runner.calls) != 5 {
		t.Fatalf("calls = %v", runner.calls)
	}
}

func TestOffSetsIdentityTrue(t *testing.T) {
	runner := &runnerStub{path: "hyprctl", responses: []response{
		{output: "false"}, {output: "3800"},
		{output: "ok"},
		{output: "true"}, {output: "3800"},
	}}
	result, err := nightlight.NewService(runner).Apply(context.Background(), nightlight.Off)
	if err != nil || result.Enabled {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	if got := strings.Join(runner.calls[2][1:], " "); got != "hyprsunset identity true" {
		t.Fatalf("action call = %q", got)
	}
}

func TestActionFailureReturnsUnavailable(t *testing.T) {
	runner := &runnerStub{path: "hyprctl", responses: []response{
		{output: "true"}, {output: "4500"},
		{err: errors.New("socket disappeared")},
	}}
	result, err := nightlight.NewService(runner).Apply(context.Background(), nightlight.On)
	if err == nil || result.Available || !strings.Contains(result.Error, "socket disappeared") {
		t.Fatalf("result=%#v err=%v", result, err)
	}
}

func TestInvalidActionDoesNotRunCommands(t *testing.T) {
	runner := &runnerStub{path: "hyprctl"}
	if _, err := nightlight.NewService(runner).Apply(context.Background(), "warm"); err == nil {
		t.Fatal("Apply accepted invalid action")
	}
	if len(runner.calls) != 0 {
		t.Fatalf("calls = %v", runner.calls)
	}
}
