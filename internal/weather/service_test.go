package weather_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/weather"
)

type forecastStub struct {
	calls    int
	location string
	snapshot weather.Snapshot
	err      error
}

type cacheStub struct {
	loadCalls int
	saveCalls int
	snapshot  weather.Snapshot
	err       error
}

func (stub *forecastStub) Fetch(_ context.Context, location string, _ weather.Units) (weather.Snapshot, error) {
	stub.calls++
	stub.location = location
	return stub.snapshot, stub.err
}

func (stub *cacheStub) Load() (weather.Snapshot, error) {
	stub.loadCalls++
	return stub.snapshot, stub.err
}

func (stub *cacheStub) Save(snapshot weather.Snapshot) error {
	stub.saveCalls++
	stub.snapshot = snapshot
	return stub.err
}

func TestDisabledWeatherDoesNotTouchNetworkOrCache(t *testing.T) {
	forecast := &forecastStub{}
	cache := &cacheStub{}
	service := weather.NewService(forecast, cache, time.Now)
	result := service.Snapshot(context.Background(), false, "Oslo", weather.Celsius)
	if result.State != weather.Disabled || forecast.calls != 0 || cache.loadCalls != 0 || cache.saveCalls != 0 {
		t.Fatalf("disabled result = %#v, calls=%d/%d/%d", result, forecast.calls, cache.loadCalls, cache.saveCalls)
	}
}

func TestSuccessfulRefreshReturnsAndCachesQuery(t *testing.T) {
	now := time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC)
	forecast := &forecastStub{snapshot: weather.Snapshot{Current: weather.Current{Temperature: 24.5}}}
	cache := &cacheStub{}
	service := weather.NewService(forecast, cache, func() time.Time { return now })
	result := service.Snapshot(context.Background(), true, "New York", weather.Fahrenheit)
	if result.State != weather.Ready || forecast.location != "New York" || cache.saveCalls != 1 {
		t.Fatalf("result = %#v, forecast=%#v cache=%#v", result, forecast, cache)
	}
	if result.Snapshot.RequestedLocation != "New York" || result.Snapshot.Units != weather.Fahrenheit || !result.Snapshot.UpdatedAt.Equal(now) {
		t.Fatalf("snapshot = %#v", result.Snapshot)
	}
}

func TestRefreshFailureUsesOnlyMatchingUnexpiredCache(t *testing.T) {
	now := time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC)
	forecast := &forecastStub{err: errors.New("offline")}
	cache := &cacheStub{snapshot: weather.Snapshot{
		UpdatedAt: now.Add(-2 * time.Hour), Units: weather.Celsius,
		RequestedLocation: "Oslo", Current: weather.Current{Temperature: 21},
	}}
	service := weather.NewService(forecast, cache, func() time.Time { return now })

	result := service.Snapshot(context.Background(), true, "Oslo", weather.Celsius)
	if result.State != weather.Stale || result.AgeMinutes != 120 {
		t.Fatalf("matching result = %#v", result)
	}
	result = service.Snapshot(context.Background(), true, "Bergen", weather.Celsius)
	if result.State != weather.Unavailable {
		t.Fatalf("location mismatch result = %#v", result)
	}
	result = service.Snapshot(context.Background(), true, "Oslo", weather.Fahrenheit)
	if result.State != weather.Unavailable {
		t.Fatalf("unit mismatch result = %#v", result)
	}
	cache.snapshot.UpdatedAt = now.Add(-7 * time.Hour)
	result = service.Snapshot(context.Background(), true, "Oslo", weather.Celsius)
	if result.State != weather.Unavailable {
		t.Fatalf("expired result = %#v", result)
	}
}

func TestOldAutomaticCacheRemainsCompatible(t *testing.T) {
	now := time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC)
	service := weather.NewService(
		&forecastStub{err: errors.New("offline")},
		&cacheStub{snapshot: weather.Snapshot{UpdatedAt: now.Add(-time.Hour), Units: weather.Celsius}},
		func() time.Time { return now },
	)
	if result := service.Snapshot(context.Background(), true, "", weather.Celsius); result.State != weather.Stale {
		t.Fatalf("result = %#v", result)
	}
}
