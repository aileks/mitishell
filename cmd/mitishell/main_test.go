package main

import "testing"

func TestExecutablePathUsesMitishellBinaryOverride(t *testing.T) {
	t.Setenv("MITISHELL_BIN", "/nix/store/example/bin/mitishell")

	path, err := executablePath()
	if err != nil {
		t.Fatalf("executablePath() error = %v", err)
	}
	if path != "/nix/store/example/bin/mitishell" {
		t.Fatalf("executablePath() = %q", path)
	}
}
