package bluetooth

import (
	"context"
	"errors"
	"testing"
	"time"
)

type discoverySessionStub struct {
	startErr error
	started  chan struct{}
	closed   chan struct{}
}

func newDiscoverySessionStub(startErr error) *discoverySessionStub {
	return &discoverySessionStub{
		startErr: startErr,
		started:  make(chan struct{}),
		closed:   make(chan struct{}),
	}
}

func (stub *discoverySessionStub) Start(context.Context) error {
	close(stub.started)
	return stub.startErr
}

func (stub *discoverySessionStub) Close() {
	close(stub.closed)
}

func TestRunDiscoveryClosesSessionAfterStartFailure(t *testing.T) {
	startErr := errors.New("bluez unavailable")
	session := newDiscoverySessionStub(startErr)

	err := runDiscovery(context.Background(), session)

	if !errors.Is(err, startErr) {
		t.Fatalf("runDiscovery() error = %v, want %v", err, startErr)
	}
	select {
	case <-session.closed:
	default:
		t.Fatal("runDiscovery() did not close the failed session")
	}
}

func TestRunDiscoveryClosesSessionAfterCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	session := newDiscoverySessionStub(nil)
	result := make(chan error, 1)
	go func() {
		result <- runDiscovery(ctx, session)
	}()

	<-session.started
	cancel()

	select {
	case err := <-result:
		if err != nil {
			t.Fatalf("runDiscovery() error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("runDiscovery() did not stop after cancellation")
	}
	select {
	case <-session.closed:
	default:
		t.Fatal("runDiscovery() did not close the cancelled session")
	}
}
