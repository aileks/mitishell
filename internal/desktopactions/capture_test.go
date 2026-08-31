package desktopactions

import (
	"context"
	"os/exec"
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
