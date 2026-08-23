package power_test

import (
	"context"
	"errors"
	"testing"

	"github.com/aileks/mitishell/internal/power"
)

type callerStub struct {
	canSuspend   string
	canHibernate string
	suspendErr   error
	calls        []string
}

func (stub *callerStub) CanSuspend(context.Context) (string, error) {
	return stub.canSuspend, nil
}

func (stub *callerStub) CanHibernate(context.Context) (string, error) {
	return stub.canHibernate, nil
}

func (stub *callerStub) Suspend(context.Context) error {
	stub.calls = append(stub.calls, "suspend")
	return stub.suspendErr
}

func (stub *callerStub) Hibernate(context.Context) error {
	stub.calls = append(stub.calls, "hibernate")
	return nil
}

func (stub *callerStub) Reboot(context.Context) error {
	stub.calls = append(stub.calls, "reboot")
	return nil
}

func (stub *callerStub) PowerOff(context.Context) error {
	stub.calls = append(stub.calls, "poweroff")
	return nil
}

func (stub *callerStub) LockSession(context.Context) error {
	stub.calls = append(stub.calls, "lock")
	return nil
}

func TestCapabilitiesOnlyOfferWorkingActions(t *testing.T) {
	cases := []struct {
		name          string
		canSuspend    string
		canHibernate  string
		wantSuspend   bool
		wantHibernate bool
	}{
		{"both available", "yes", "yes", true, true},
		{"hibernate missing", "yes", "no", true, false},
		{"auth challenge still available", "challenge", "no", false, false},
	}
	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			service := power.NewService(&callerStub{
				canSuspend:   testCase.canSuspend,
				canHibernate: testCase.canHibernate,
			})

			capabilities, err := service.Capabilities(context.Background())

			if err != nil {
				t.Fatalf("Capabilities() error = %v", err)
			}
			if capabilities.Suspend != testCase.wantSuspend ||
				capabilities.Hibernate != testCase.wantHibernate {
				t.Fatalf("capabilities = %#v", capabilities)
			}
		})
	}
}

func TestRunDispatchesEachAction(t *testing.T) {
	cases := map[power.Action]string{
		power.Lock:      "lock",
		power.Suspend:   "suspend",
		power.Hibernate: "hibernate",
		power.Reboot:    "reboot",
		power.Shutdown:  "poweroff",
	}
	for action, want := range cases {
		stub := &callerStub{}
		service := power.NewService(stub)

		if err := service.Run(context.Background(), action); err != nil {
			t.Fatalf("Run(%s) error = %v", action, err)
		}
		if len(stub.calls) != 1 || stub.calls[0] != want {
			t.Fatalf("Run(%s) calls = %v, want [%s]", action, stub.calls, want)
		}
	}
}

func TestRunRejectsUnknownActions(t *testing.T) {
	stub := &callerStub{}
	service := power.NewService(stub)

	if err := service.Run(context.Background(), power.Action("restart")); err == nil {
		t.Fatal("Run accepted an unknown action")
	}
	if len(stub.calls) != 0 {
		t.Fatalf("unknown action reached logind: %v", stub.calls)
	}
}

func TestCapabilityFailureSurfaces(t *testing.T) {
	service := power.NewService(&failingCaller{&callerStub{}})
	if _, err := service.Capabilities(context.Background()); err == nil {
		t.Fatal("Capabilities hid a logind failure")
	}
}

type failingCaller struct{ *callerStub }

func (stub failingCaller) CanSuspend(context.Context) (string, error) {
	return "", errors.New("logind unreachable")
}
