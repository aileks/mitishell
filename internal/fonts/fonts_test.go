package fonts_test

import (
	"reflect"
	"strings"
	"testing"

	"github.com/aileks/mitishell/internal/fonts"
)

func TestFamiliesKeepsOnlyNerdFonts(t *testing.T) {
	output := strings.Join([]string{
		"Adwaita Sans",
		"AdwaitaMono Nerd Font,AdwaitaMono",
		"AdwaitaMono Nerd Font Mono,AdwaitaMono",
		"DejaVu Sans",
		"FiraCode Nerd Font",
		"JetBrainsMono Nerd Font Mono,JetBrainsMono",
		"Maple Mono",
		"Maple Mono NF",
	}, "\n")

	got := fonts.Families(output)
	want := []string{
		"AdwaitaMono Nerd Font",
		"AdwaitaMono Nerd Font Mono",
		"FiraCode Nerd Font",
		"JetBrainsMono Nerd Font Mono",
		"Maple Mono NF",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Families() = %#v, want %#v", got, want)
	}
}

func TestFamiliesKeepsWidthVariants(t *testing.T) {
	output := strings.Join([]string{
		"FiraCode Nerd Font",
		"FiraCode Nerd Font Mono",
		"FiraCode Nerd Font Propo",
		"SymbolsNerdFont",
		"SymbolsNerdFontPropo",
	}, "\n")

	got := fonts.Families(output)
	want := []string{
		"FiraCode Nerd Font",
		"FiraCode Nerd Font Mono",
		"FiraCode Nerd Font Propo",
		"SymbolsNerdFont",
		"SymbolsNerdFontPropo",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Families() = %#v, want %#v", got, want)
	}
}

func TestIsNerd(t *testing.T) {
	cases := map[string]bool{
		"AdwaitaMono Nerd Font Propo": true,
		"JetBrainsMono Nerd Font":     true,
		"SymbolsNerdFont":             true,
		"Maple Mono NF":               true,
		"Maple Mono NF CN":            true,
		"Maple Mono NL NF CN":         true,
		"Maple Mono":                  false,
		"Adwaita Mono":                false,
		"Adwaita Sans":                false,
		"Comic Sans":                  false,
		"":                            false,
	}
	for family, want := range cases {
		if got := fonts.IsNerd(family); got != want {
			t.Fatalf("IsNerd(%q) = %v, want %v", family, got, want)
		}
	}
}

func TestFamiliesSortsAndDeduplicates(t *testing.T) {
	output := strings.Join([]string{
		"Symbols Nerd Font",
		"JetBrainsMono Nerd Font",
		"Symbols Nerd Font",
		"",
	}, "\n")

	got := fonts.Families(output)
	want := []string{"JetBrainsMono Nerd Font", "Symbols Nerd Font"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("Families() = %#v, want %#v", got, want)
	}
}

func TestFamiliesHandlesEmptyOutput(t *testing.T) {
	if got := fonts.Families(""); len(got) != 0 {
		t.Fatalf("Families() = %#v, want empty", got)
	}
}

func TestAllFamiliesKeepsUnpatchedFamilies(t *testing.T) {
	output := strings.Join([]string{
		"Adwaita Sans",
		"AdwaitaMono Nerd Font,AdwaitaMono",
		"DejaVu Sans",
		"Adwaita Sans",
		"",
	}, "\n")

	got := fonts.AllFamilies(output)
	want := []string{
		"Adwaita Sans",
		"AdwaitaMono",
		"AdwaitaMono Nerd Font",
		"DejaVu Sans",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("AllFamilies() = %#v, want %#v", got, want)
	}
}

func TestAllFamiliesHandlesEmptyOutput(t *testing.T) {
	if got := fonts.AllFamilies(""); len(got) != 0 {
		t.Fatalf("AllFamilies() = %#v, want empty", got)
	}
}
