package reminders_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/reminders"
)

var fixedNow = time.Unix(1_800_000_000, 0)

type runnerStub struct {
	scheduled []reminders.Record
	active    map[string]bool
	stopped   []string
	err       error
}

func (stub *runnerStub) Schedule(_ context.Context, record reminders.Record, _ string) error {
	stub.scheduled = append(stub.scheduled, record)
	if stub.active == nil {
		stub.active = map[string]bool{}
	}
	stub.active[record.Unit()] = true
	return stub.err
}

func (stub *runnerStub) Active(_ context.Context, unit string) (bool, error) {
	return stub.active[unit], stub.err
}

func (stub *runnerStub) Stop(_ context.Context, unit string) error {
	stub.stopped = append(stub.stopped, unit)
	delete(stub.active, unit)
	return stub.err
}

type notifierStub struct {
	delivered []reminders.Record
	err       error
}

func (stub *notifierStub) Deliver(_ context.Context, record reminders.Record) error {
	stub.delivered = append(stub.delivered, record)
	return stub.err
}

func serviceForTest(t *testing.T, runner *runnerStub, notifier *notifierStub) (reminders.Service, reminders.FileStore) {
	t.Helper()
	store := reminders.NewFileStore(filepath.Join(t.TempDir(), "reminders"))
	service := reminders.NewServiceForTest(
		runner,
		store,
		notifier,
		"/usr/bin/mitishell",
		func() time.Time { return fixedNow },
		func() (string, error) { return "0123456789abcdef", nil },
	)
	return service, store
}

func TestScheduleCreatesTimerAndPrivateMetadata(t *testing.T) {
	runner := &runnerStub{}
	service, store := serviceForTest(t, runner, &notifierStub{})
	active, err := service.Schedule(context.Background(), 5, "")
	if err != nil {
		t.Fatal(err)
	}
	if active.Message != "Your 5 minutes are up" || active.RemainingSeconds != 300 {
		t.Fatalf("active = %#v", active)
	}
	if len(runner.scheduled) != 1 || runner.scheduled[0].ID != active.ID {
		t.Fatalf("scheduled = %#v", runner.scheduled)
	}
	record, err := store.Load(active.ID)
	if err != nil {
		t.Fatal(err)
	}
	if record.FireAt != fixedNow.Add(5*time.Minute).Unix() || record.Pending {
		t.Fatalf("record = %#v", record)
	}
}

func TestListCancellationAndClearAll(t *testing.T) {
	runner := &runnerStub{}
	service, store := serviceForTest(t, runner, &notifierStub{})
	first, err := service.Schedule(context.Background(), 5, "Tea")
	if err != nil {
		t.Fatal(err)
	}
	service2 := reminders.NewServiceForTest(
		runner,
		store,
		&notifierStub{},
		"/usr/bin/mitishell",
		func() time.Time { return fixedNow },
		func() (string, error) { return "fedcba9876543210", nil },
	)
	second, err := service2.Schedule(context.Background(), 10, "Laundry")
	if err != nil {
		t.Fatal(err)
	}
	active, err := service.List(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(active) != 2 || active[0].ID != first.ID || active[1].ID != second.ID {
		t.Fatalf("active = %#v", active)
	}
	if _, err := service.Cancel(context.Background(), first.ID); err != nil {
		t.Fatal(err)
	}
	if !slices.Contains(runner.stopped, "mitishell-reminder-"+first.ID) {
		t.Fatalf("stopped = %v", runner.stopped)
	}
	count, err := service.Clear(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("cleared = %d", count)
	}
}

func TestFiringWaitsAndRecoversWhenNotificationServerReturns(t *testing.T) {
	runner := &runnerStub{}
	notifier := &notifierStub{err: reminders.ErrNotificationServerUnavailable}
	service, store := serviceForTest(t, runner, notifier)
	active, err := service.Schedule(context.Background(), 2, "Stretch")
	if err != nil {
		t.Fatal(err)
	}
	if err := service.Fire(context.Background(), active.ID); err != nil {
		t.Fatal(err)
	}
	record, err := store.Load(active.ID)
	if err != nil {
		t.Fatal(err)
	}
	if !record.Pending {
		t.Fatalf("record = %#v", record)
	}
	notifier.err = nil
	delivered, err := service.RecoverPending(context.Background())
	if err != nil || delivered != 1 {
		t.Fatalf("delivered=%d err=%v", delivered, err)
	}
	if _, err := store.Load(active.ID); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("pending metadata remains: %v", err)
	}
}

func TestFileStoreUsesPrivatePermissionsAndRejectsMalformedState(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "reminders")
	store := reminders.NewFileStore(directory)
	record := reminders.Record{
		Version: 1, ID: "0123456789abcdef", Minutes: 5,
		Message: "Tea", Label: "Tea",
		CreatedAt: fixedNow.Unix(), FireAt: fixedNow.Add(5 * time.Minute).Unix(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	directoryInfo, err := os.Stat(directory)
	if err != nil {
		t.Fatal(err)
	}
	fileInfo, err := os.Stat(filepath.Join(directory, record.ID+".json"))
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0o700 || fileInfo.Mode().Perm() != 0o600 {
		t.Fatalf("directory=%o file=%o", directoryInfo.Mode().Perm(), fileInfo.Mode().Perm())
	}
	malformedID := "fedcba9876543210"
	if err := os.WriteFile(
		filepath.Join(directory, malformedID+".json"),
		[]byte(`{"version":1,"id":"fedcba9876543210","extra":true}`),
		0o600,
	); err != nil {
		t.Fatal(err)
	}
	if _, err := store.LoadAll(); err == nil {
		t.Fatal("LoadAll accepted malformed metadata")
	}
}

type executorStub struct {
	name  string
	args  []string
	calls [][]string
	err   error
}

func (stub *executorStub) Run(_ context.Context, name string, arguments ...string) error {
	stub.name = name
	stub.args = append([]string(nil), arguments...)
	stub.calls = append(stub.calls, append([]string{name}, arguments...))
	return stub.err
}

func TestCommandRunnerUsesLiteralSystemdArguments(t *testing.T) {
	executor := &executorStub{}
	runner := reminders.NewCommandRunnerWithExecutor("/usr/bin/systemd-run", "/usr/bin/systemctl", executor)
	record := reminders.Record{
		Version: 1, ID: "0123456789abcdef", Minutes: 5,
		Message: "$(touch /tmp/nope)", Label: "$(touch /tmp/nope)",
		CreatedAt: fixedNow.Unix(), FireAt: fixedNow.Add(5 * time.Minute).Unix(),
	}
	if err := runner.Schedule(context.Background(), record, "/usr/bin/mitishell"); err != nil {
		t.Fatal(err)
	}
	wantTail := []string{"--", "/usr/bin/mitishell", "_reminder-fire", record.ID}
	if executor.name != "/usr/bin/systemd-run" ||
		!slices.Equal(executor.args[len(executor.args)-len(wantTail):], wantTail) {
		t.Fatalf("name=%q args=%q", executor.name, executor.args)
	}
	if slices.Contains(executor.args, record.Message) {
		t.Fatalf("message leaked into systemd arguments: %q", executor.args)
	}
}

type stopExecutorStub struct {
	calls int
}

func (stub *stopExecutorStub) Run(_ context.Context, _ string, _ ...string) error {
	stub.calls++
	if stub.calls == 2 {
		return reminders.ErrInactiveUnit
	}
	return nil
}

func TestCommandRunnerStopsTimerWhenServiceIsNotLoaded(t *testing.T) {
	executor := &stopExecutorStub{}
	runner := reminders.NewCommandRunnerWithExecutor("systemd-run", "systemctl", executor)
	if err := runner.Stop(context.Background(), "mitishell-reminder-0123456789abcdef"); err != nil {
		t.Fatal(err)
	}
	if executor.calls != 2 {
		t.Fatalf("calls = %d", executor.calls)
	}
}

type notificationCallerStub struct {
	notification reminders.Notification
	err          error
}

func (stub *notificationCallerStub) Notify(_ context.Context, notification reminders.Notification) error {
	stub.notification = notification
	return stub.err
}

func TestDBusNotifierMarksReminderTrafficNormalAndNonTransient(t *testing.T) {
	caller := &notificationCallerStub{}
	notifier := reminders.NewDBusNotifierWithCaller(caller)
	record := reminders.Record{Message: "Check the oven"}
	if err := notifier.Deliver(context.Background(), record); err != nil {
		t.Fatal(err)
	}
	urgency, ok := caller.notification.Hints["urgency"].Value().(byte)
	if !ok || urgency != 1 {
		t.Fatalf("urgency = %#v", caller.notification.Hints["urgency"].Value())
	}
	if caller.notification.Hints["x-mitishell-reminder"].Value() != true ||
		caller.notification.Hints["transient"].Value() != false ||
		caller.notification.ExpireTimeout != 8000 {
		t.Fatalf("notification = %#v", caller.notification)
	}
	if _, ok := caller.notification.Hints["desktop-entry"].Value().(string); !ok {
		t.Fatalf("desktop entry hint = %#v", caller.notification.Hints["desktop-entry"])
	}
}
