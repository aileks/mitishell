// Package fonts enumerates installed Nerd Font families. The shell's icons
// are Nerd Font glyphs, so the font picker only offers patched families;
// an unpatched family would render every icon as missing glyphs.
package fonts

import (
	"context"
	"fmt"
	"os/exec"
	"sort"
	"strings"
)

// Families filters fc-list output into the deduplicated, sorted list of
// installed Nerd Font families. fc-list prints one font file per line with
// comma-separated family aliases. Variant families such as
// "FiraCode Nerd Font Mono" collapse onto "FiraCode Nerd Font" when the
// plain family is installed too; a variant whose plain family is missing
// stays selectable so patched-only installs still offer the font.
func Families(fcListOutput string) []string {
	seen := make(map[string]struct{})
	for _, line := range strings.Split(fcListOutput, "\n") {
		for _, family := range strings.Split(line, ",") {
			family = strings.TrimSpace(family)
			if isNerdFamily(family) {
				seen[family] = struct{}{}
			}
		}
	}

	families := make([]string, 0, len(seen))
	for family := range seen {
		if base, variant := plainVariant(family); variant {
			if _, hasBase := seen[base]; hasBase {
				continue
			}
		}
		families = append(families, family)
	}
	sort.Strings(families)
	return families
}

func isNerdFamily(family string) bool {
	return strings.Contains(family, "Nerd Font") || strings.Contains(family, "NerdFont")
}

// plainVariant maps a variant family name to its plain family, for example
// "JetBrainsMono Nerd Font Mono" to "JetBrainsMono Nerd Font" and
// "JetBrainsMono NerdFontPropo" to "JetBrainsMono NerdFont". The second
// result reports whether the name names a variant at all.
func plainVariant(family string) (string, bool) {
	for _, suffix := range []string{" Propo", " Mono", "Propo", "Mono"} {
		if strings.HasSuffix(family, suffix) {
			return strings.TrimSuffix(family, suffix), true
		}
	}
	return "", false
}

type Runner interface {
	Output(ctx context.Context, name string, args ...string) (string, error)
}

type SystemRunner struct{}

func (SystemRunner) Output(ctx context.Context, name string, args ...string) (string, error) {
	output, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil {
		return string(output), fmt.Errorf("run %s: %w", name, err)
	}
	return string(output), nil
}

type Service struct {
	runner Runner
}

func NewService(runner Runner) *Service {
	return &Service{runner: runner}
}

// Families lists the installed Nerd Font families through fontconfig.
func (s *Service) Families(ctx context.Context) ([]string, error) {
	output, err := s.runner.Output(ctx, "fc-list", "--format", "%{family}\n")
	if err != nil {
		return nil, err
	}
	return Families(output), nil
}
