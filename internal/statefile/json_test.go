package statefile_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/aileks/mitishell/internal/statefile"
)

type fixture struct {
	Value string `json:"value"`
}

func TestJSONAtomicallyReplacesPrivateState(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "private")
	path := filepath.Join(directory, "state.json")
	file := statefile.NewJSON(path, "test state")

	if err := file.Save(fixture{Value: "before"}); err != nil {
		t.Fatal(err)
	}
	before, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := file.Save(fixture{Value: "after"}); err != nil {
		t.Fatal(err)
	}
	after, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if os.SameFile(before, after) {
		t.Fatal("Save rewrote the existing file instead of atomically replacing it")
	}

	loaded := fixture{}
	found, err := file.Load(&loaded)
	if err != nil || !found || loaded.Value != "after" {
		t.Fatalf("found=%v state=%#v err=%v", found, loaded, err)
	}
	directoryInfo, err := os.Stat(directory)
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0o700 || after.Mode().Perm() != 0o600 {
		t.Fatalf("directory mode=%o file mode=%o",
			directoryInfo.Mode().Perm(), after.Mode().Perm())
	}
	temporaryFiles, err := filepath.Glob(filepath.Join(directory, ".mitishell-state-*.tmp"))
	if err != nil {
		t.Fatal(err)
	}
	if len(temporaryFiles) != 0 {
		t.Fatalf("temporary files remain: %v", temporaryFiles)
	}
}

func TestJSONMissingAndClear(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	file := statefile.NewJSON(path, "test state")
	loaded := fixture{Value: "unchanged"}
	found, err := file.Load(&loaded)
	if err != nil || found || loaded.Value != "unchanged" {
		t.Fatalf("found=%v state=%#v err=%v", found, loaded, err)
	}
	if err := file.Clear(); err != nil {
		t.Fatal(err)
	}
}
