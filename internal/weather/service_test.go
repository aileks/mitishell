package weather_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/weather"
)

type locationStub struct {
	calls    int
	location weather.Location
	err      error
}

type forecastStub struct {
	calls    int
	snapshot weather.Snapshot
	err      error
}

type cacheStub struct {
	loadCalls int
	saveCalls int
	snapshot  weather.Snapshot
	err       error
}

func (stub *locationStub) Locate(context.Context) (weather.Location, error) {
	stub.calls++
	return stub.location, stub.err
}

func (stub *forecastStub) Fetch(context.Context, weather.Location, weather.Units) (weather.Snapshot, error) {
	stub.calls++
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

func TestDisabledWeatherDoesNotTouchLocationNetworkOrCache(t *testing.T) {
	location := &locationStub{}
	forecast := &forecastStub{}
	cache := &cacheStub{}
	service := weather.NewService(location, forecast, cache, time.Now)

	result := service.Snapshot(context.Background(), false, weather.Celsius)

	if result.State != weather.Disabled {
		t.Fatalf("state = %q, want disabled", result.State)
	}
	if location.calls != 0 || forecast.calls != 0 || cache.loadCalls != 0 || cache.saveCalls != 0 {
		t.Fatalf("disabled weather performed I/O: location=%d forecast=%d cache=%d/%d",
			location.calls, forecast.calls, cache.loadCalls, cache.saveCalls)
	}
}

func TestSuccessfulRefreshReturnsAndCachesNormalizedSnapshot(t *testing.T) {
	now := time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC)
	want := weather.Snapshot{UpdatedAt: now, Current: weather.Current{Temperature: 24.5}}
	location := &locationStub{location: weather.Location{Latitude: 40.7, Longitude: -74.0}}
	forecast := &forecastStub{snapshot: want}
	cache := &cacheStub{}
	service := weather.NewService(location, forecast, cache, func() time.Time { return now })

	result := service.Snapshot(context.Background(), true, weather.Celsius)

	if result.State != weather.Ready || result.Snapshot.Current.Temperature != 24.5 {
		t.Fatalf("result = %#v", result)
	}
	if cache.saveCalls != 1 {
		t.Fatalf("cache saves = %d, want 1", cache.saveCalls)
	}
}

func TestRefreshFailureUsesOnlyUnexpiredLastGoodData(t *testing.T) {
	now := time.Date(2026, 8, 20, 19, 0, 0, 0, time.UTC)
	location := &locationStub{err: errors.New("denied")}
	cache := &cacheStub{snapshot: weather.Snapshot{
		UpdatedAt: now.Add(-2 * time.Hour),
		Current:   weather.Current{Temperature: 21},
	}}
	service := weather.NewService(location, &forecastStub{}, cache, func() time.Time { return now })

	result := service.Snapshot(context.Background(), true, weather.Celsius)
	if result.State != weather.Stale || result.AgeMinutes != 120 {
		t.Fatalf("result = %#v", result)
	}

	cache.snapshot.UpdatedAt = now.Add(-7 * time.Hour)
	result = service.Snapshot(context.Background(), true, weather.Celsius)
	if result.State != weather.Unavailable || result.Snapshot.UpdatedAt.IsZero() == false {
		t.Fatalf("expired result = %#v", result)
	}
}
