package reminders

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"time"
)

type Service struct {
	runner     Runner
	store      Store
	notifier   Notifier
	executable string
	now        func() time.Time
	newID      func() (string, error)
	dependency error
}

func NewService(runner Runner, store Store, notifier Notifier, executable string) Service {
	return Service{
		runner:     runner,
		store:      store,
		notifier:   notifier,
		executable: executable,
		now:        time.Now,
		newID:      randomID,
	}
}

func NewServiceForTest(
	runner Runner,
	store Store,
	notifier Notifier,
	executable string,
	now func() time.Time,
	newID func() (string, error),
) Service {
	return Service{
		runner: runner, store: store, notifier: notifier,
		executable: executable, now: now, newID: newID,
	}
}

func Unavailable(err error) Service {
	return Service{dependency: err, now: time.Now, newID: randomID}
}

func (service Service) Schedule(ctx context.Context, minutes int, customMessage string) (ActiveReminder, error) {
	if err := service.ready(); err != nil {
		return ActiveReminder{}, err
	}
	if minutes <= 0 || time.Duration(minutes) > time.Duration(1<<63-1)/time.Minute {
		return ActiveReminder{}, fmt.Errorf("minutes must be a positive whole number")
	}
	id, err := service.newID()
	if err != nil {
		return ActiveReminder{}, fmt.Errorf("create reminder id: %w", err)
	}
	now := service.now()
	message := customMessage
	if message == "" {
		message = fmt.Sprintf("Your %d minutes are up", minutes)
	}
	record := Record{
		Version:   recordVersion,
		ID:        id,
		Minutes:   minutes,
		Message:   message,
		Label:     message,
		CreatedAt: now.Unix(),
		FireAt:    now.Add(time.Duration(minutes) * time.Minute).Unix(),
	}
	if err := service.store.Save(record); err != nil {
		return ActiveReminder{}, err
	}
	if err := service.runner.Schedule(ctx, record, service.executable); err != nil {
		_ = service.store.Remove(record.ID)
		return ActiveReminder{}, err
	}
	return activeFromRecord(record, now), nil
}

func (service Service) List(ctx context.Context) ([]ActiveReminder, error) {
	if err := service.ready(); err != nil {
		return nil, err
	}
	records, err := service.store.LoadAll()
	if err != nil {
		return nil, err
	}
	now := service.now()
	active := make([]ActiveReminder, 0, len(records))
	for _, record := range records {
		if record.Pending || record.FireAt <= now.Unix() {
			continue
		}
		running, err := service.runner.Active(ctx, record.Unit())
		if err != nil {
			return nil, err
		}
		if !running {
			_ = service.store.Remove(record.ID)
			continue
		}
		active = append(active, activeFromRecord(record, now))
	}
	sort.Slice(active, func(left int, right int) bool {
		return active[left].FireAt < active[right].FireAt
	})
	return active, nil
}

func (service Service) Cancel(ctx context.Context, id string) (Record, error) {
	if err := service.ready(); err != nil {
		return Record{}, err
	}
	record, err := service.store.Load(id)
	if err != nil {
		return Record{}, err
	}
	if !record.Pending {
		if err := service.runner.Stop(ctx, record.Unit()); err != nil {
			return Record{}, err
		}
	}
	if err := service.store.Remove(record.ID); err != nil {
		return Record{}, err
	}
	return record, nil
}

func (service Service) Clear(ctx context.Context) (int, error) {
	if err := service.ready(); err != nil {
		return 0, err
	}
	records, err := service.store.LoadAll()
	if err != nil {
		return 0, err
	}
	for _, record := range records {
		if !record.Pending {
			if err := service.runner.Stop(ctx, record.Unit()); err != nil {
				return 0, err
			}
		}
	}
	if err := service.store.Clear(); err != nil {
		return 0, err
	}
	return len(records), nil
}

func (service Service) Fire(ctx context.Context, id string) error {
	if service.store == nil || service.notifier == nil {
		return fmt.Errorf("reminders unavailable")
	}
	record, err := service.store.Load(id)
	if err != nil {
		return err
	}
	if err := service.notifier.Deliver(ctx, record); err != nil {
		record.Pending = true
		if saveErr := service.store.Save(record); saveErr != nil {
			return errors.Join(err, saveErr)
		}
		return nil
	}
	return service.store.Remove(record.ID)
}

func (service Service) RecoverPending(ctx context.Context) (int, error) {
	if service.store == nil || service.notifier == nil {
		return 0, fmt.Errorf("reminders unavailable")
	}
	records, err := service.store.LoadAll()
	if err != nil {
		return 0, err
	}
	delivered := 0
	var deliveryError error
	for _, record := range records {
		if !record.Pending {
			continue
		}
		if err := service.notifier.Deliver(ctx, record); err != nil {
			deliveryError = err
			continue
		}
		if err := service.store.Remove(record.ID); err != nil {
			return delivered, err
		}
		delivered++
	}
	return delivered, deliveryError
}

func (service Service) Snapshot(ctx context.Context) Snapshot {
	if err := service.ready(); err != nil {
		return Snapshot{Available: false, Error: err.Error(), Reminders: []ActiveReminder{}}
	}
	_, recoveryErr := service.RecoverPending(ctx)
	active, err := service.List(ctx)
	if err != nil {
		return Snapshot{Available: false, Error: err.Error(), Reminders: []ActiveReminder{}}
	}
	snapshot := Snapshot{Available: true, Reminders: active}
	if recoveryErr != nil {
		snapshot.Warning = "A fired reminder is waiting for the notification server."
	}
	return snapshot
}

func (service Service) ready() error {
	if service.dependency != nil {
		return service.dependency
	}
	if service.runner == nil || service.store == nil || service.notifier == nil || service.executable == "" {
		return fmt.Errorf("reminders unavailable")
	}
	return nil
}

func activeFromRecord(record Record, now time.Time) ActiveReminder {
	remaining := record.FireAt - now.Unix()
	if remaining < 0 {
		remaining = 0
	}
	return ActiveReminder{
		ID:               record.ID,
		Minutes:          record.Minutes,
		Message:          record.Message,
		Label:            record.Label,
		FireAt:           record.FireAt,
		RemainingSeconds: remaining,
	}
}

func randomID() (string, error) {
	buffer := make([]byte, 8)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return hex.EncodeToString(buffer), nil
}
