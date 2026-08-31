package desktopactions

import (
	"context"
	"os/exec"
	"slices"
	"testing"
	"time"
)

// Helper tools such as wl-copy fork a server that outlives the command and
// inherits its output descriptors; runCommand must not wait for it.
func TestRunCommandDoesNotWaitForForkedChildren(t *testing.T) {
	sleep, err := exec.LookPath("sleep")
	if err != nil {
		t.Skipf("sleep unavailable: %v", err)
	}
	start := time.Now()
	err = runCommand(context.Background(), nil, "sh", "-c", sleep+" 3 >/dev/null 2>&1 &")
	elapsed := time.Since(start)
	if err != nil {
		t.Fatalf("runCommand() error = %v", err)
	}
	if elapsed >= 1500*time.Millisecond {
		t.Fatalf("runCommand() blocked %v on the forked child", elapsed)
	}
}

func TestShellQuoteSurvivesSpacesAndQuotes(t *testing.T) {
	quoted := shellQuote("/home/test/Pictures/Screenshots/my 'shot'.png")
	want := "'/home/test/Pictures/Screenshots/my '\\''shot'\\''.png'"
	if quoted != want {
		t.Fatalf("shellQuote() = %s, want %s", quoted, want)
	}
}

func TestMonitorNamesSkipsDisabledOutputs(t *testing.T) {
	names := monitorNames(`[{"name":"DP-1","disabled":false},{"name":"HDMI-A-1","disabled":true}]`)
	if !slices.Equal(names, []string{"DP-1"}) {
		t.Fatalf("monitorNames() = %#v", names)
	}
	if got := monitorNames("not json"); len(got) != 0 {
		t.Fatalf("monitorNames(bad json) = %#v", got)
	}
}
