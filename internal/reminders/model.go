package reminders

import (
	"fmt"
	"regexp"
)

const recordVersion = 1

var safeID = regexp.MustCompile(`^[0-9a-f]{16}$`)

type Record struct {
	Version   int    `json:"version"`
	ID        string `json:"id"`
	Minutes   int    `json:"minutes"`
	Message   string `json:"message"`
	Label     string `json:"label"`
	CreatedAt int64  `json:"createdAt"`
	FireAt    int64  `json:"fireAt"`
	Pending   bool   `json:"pending"`
}

func (record Record) Unit() string {
	return "mitishell-reminder-" + record.ID
}

func (record Record) validate() error {
	if record.Version != recordVersion {
		return fmt.Errorf("unsupported reminder metadata version %d", record.Version)
	}
	if !safeID.MatchString(record.ID) {
		return fmt.Errorf("invalid reminder id %q", record.ID)
	}
	if record.Minutes <= 0 || record.Message == "" || record.Label == "" {
		return fmt.Errorf("invalid reminder metadata")
	}
	if record.CreatedAt <= 0 || record.FireAt <= record.CreatedAt {
		return fmt.Errorf("invalid reminder timing")
	}
	return nil
}

type ActiveReminder struct {
	ID               string `json:"id"`
	Minutes          int    `json:"minutes"`
	Message          string `json:"message"`
	Label            string `json:"label"`
	FireAt           int64  `json:"fireAt"`
	RemainingSeconds int64  `json:"remainingSeconds"`
}

type Snapshot struct {
	Available bool             `json:"available"`
	Error     string           `json:"error,omitempty"`
	Warning   string           `json:"warning,omitempty"`
	Reminders []ActiveReminder `json:"reminders"`
}
