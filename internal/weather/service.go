package weather

import (
	"context"
	"fmt"
	"time"
)

const staleLimit = 6 * time.Hour

type State string

const (
	Disabled    State = "disabled"
	Ready       State = "ready"
	Stale       State = "stale"
	Unavailable State = "unavailable"
)

type Units string

const (
	Celsius    Units = "celsius"
	Fahrenheit Units = "fahrenheit"
)

type Location struct {
	Latitude  float64
	Longitude float64
}

type Current struct {
	Temperature float64 `json:"temperature"`
	Apparent    float64 `json:"apparent"`
	Humidity    int     `json:"humidity"`
	WeatherCode int     `json:"weatherCode"`
	WindSpeed   float64 `json:"windSpeed"`
}

type Hour struct {
	Time        string  `json:"time"`
	Temperature float64 `json:"temperature"`
	WeatherCode int     `json:"weatherCode"`
}

type Day struct {
	Date        string  `json:"date"`
	Minimum     float64 `json:"minimum"`
	Maximum     float64 `json:"maximum"`
	WeatherCode int     `json:"weatherCode"`
}

type Snapshot struct {
	UpdatedAt time.Time `json:"updatedAt"`
	Units     Units     `json:"units"`
	Current   Current   `json:"current"`
	Hourly    []Hour    `json:"hourly"`
	Daily     []Day     `json:"daily"`
}

type Result struct {
	State      State    `json:"state"`
	AgeMinutes int      `json:"ageMinutes"`
	Snapshot   Snapshot `json:"snapshot"`
	Error      string   `json:"error,omitempty"`
}

type LocationProvider interface {
	Locate(context.Context) (Location, error)
}

type ForecastProvider interface {
	Fetch(context.Context, Location, Units) (Snapshot, error)
}

type Cache interface {
	Load() (Snapshot, error)
	Save(Snapshot) error
}

type Service struct {
	location LocationProvider
	forecast ForecastProvider
	cache    Cache
	now      func() time.Time
}

func NewService(
	location LocationProvider,
	forecast ForecastProvider,
	cache Cache,
	now func() time.Time,
) Service {
	return Service{location: location, forecast: forecast, cache: cache, now: now}
}

func (service Service) Snapshot(ctx context.Context, enabled bool, units Units) Result {
	if !enabled {
		return Result{State: Disabled}
	}

	location, err := service.location.Locate(ctx)
	if err == nil {
		var snapshot Snapshot
		snapshot, err = service.forecast.Fetch(ctx, location, units)
		if err == nil {
			if snapshot.UpdatedAt.IsZero() {
				snapshot.UpdatedAt = service.now()
			}
			snapshot.Units = units
			result := Result{State: Ready, Snapshot: snapshot}
			if saveErr := service.cache.Save(snapshot); saveErr != nil {
				result.Error = fmt.Sprintf("cache weather: %v", saveErr)
			}
			return result
		}
	}

	failure := err
	cached, cacheErr := service.cache.Load()
	if cacheErr == nil {
		age := service.now().Sub(cached.UpdatedAt)
		if age >= 0 && age <= staleLimit {
			return Result{
				State:      Stale,
				AgeMinutes: int(age.Round(time.Minute) / time.Minute),
				Snapshot:   cached,
				Error:      failure.Error(),
			}
		}
	}

	message := failure.Error()
	if cacheErr != nil {
		message = fmt.Sprintf("%s; cached weather unavailable: %v", message, cacheErr)
	}
	return Result{State: Unavailable, Error: message}
}
