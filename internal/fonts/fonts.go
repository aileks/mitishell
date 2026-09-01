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
// installed Nerd Font families, keeping every width variant (Mono, Propo)
// selectable. fc-list prints one font file per line with comma-separated
// family aliases.
func Families(fcListOutput string) []string {
	seen := make(map[string]struct{})
	for _, line := range strings.Split(fcListOutput, "\n") {
		for _, family := range strings.Split(line, ",") {
			family = strings.TrimSpace(family)
			if IsNerd(family) {
				seen[family] = struct{}{}
			}
		}
	}

	families := make([]string, 0, len(seen))
	for family := range seen {
		families = append(families, family)
	}
	sort.Strings(families)
	return families
}

// IsNerd reports whether a family name identifies a Nerd Font. The shell's
// icons are Nerd Font glyphs, so monospace slot values must pass this
// check. Some publishers, such as Maple Mono, tag their patched families
// with a standalone "NF" word instead of the full name.
func IsNerd(family string) bool {
	if strings.Contains(family, "Nerd Font") || strings.Contains(family, "NerdFont") {
		return true
	}
	for _, word := range strings.Fields(family) {
		if word == "NF" {
			return true
		}
	}
	return false
}

// AllFamilies returns the deduplicated, sorted list of every installed
// family, keeping comma-separated aliases as distinct entries. Standard
// text renders no icon glyphs, so the standard font picker can offer
// unpatched families.
func AllFamilies(fcListOutput string) []string {
	seen := make(map[string]struct{})
	for _, line := range strings.Split(fcListOutput, "\n") {
		for _, family := range strings.Split(line, ",") {
			family = strings.TrimSpace(family)
			if family == "" {
				continue
			}
			seen[family] = struct{}{}
		}
	}

	families := make([]string, 0, len(seen))
	for family := range seen {
		families = append(families, family)
	}
	sort.Strings(families)
	return families
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

// Catalog lists every installed family alongside the Nerd Font subset
// through one fontconfig query.
func (s *Service) Catalog(ctx context.Context) (families []string, nerdFamilies []string, err error) {
	output, err := s.runner.Output(ctx, "fc-list", "--format", "%{family}\n")
	if err != nil {
		return nil, nil, err
	}
	return AllFamilies(output), Families(output), nil
}
