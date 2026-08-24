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
	UpdatedAt         time.Time `json:"updatedAt"`
	Units             Units     `json:"units"`
	RequestedLocation string    `json:"requestedLocation"`
	ResolvedLocation  string    `json:"resolvedLocation"`
	Current           Current   `json:"current"`
	Hourly            []Hour    `json:"hourly"`
	Daily             []Day     `json:"daily"`
}

type Result struct {
	State      State    `json:"state"`
	AgeMinutes int      `json:"ageMinutes"`
	Snapshot   Snapshot `json:"snapshot"`
	Error      string   `json:"error,omitempty"`
}

type ForecastProvider interface {
	Fetch(context.Context, string, Units) (Snapshot, error)
}

type Cache interface {
	Load() (Snapshot, error)
	Save(Snapshot) error
}

type Service struct {
	forecast ForecastProvider
	cache    Cache
	now      func() time.Time
}

func NewService(
	forecast ForecastProvider,
	cache Cache,
	now func() time.Time,
) Service {
	return Service{forecast: forecast, cache: cache, now: now}
}

func (service Service) Snapshot(ctx context.Context, enabled bool, location string, units Units) Result {
	if !enabled {
		return Result{State: Disabled}
	}

	snapshot, err := service.forecast.Fetch(ctx, location, units)
	if err == nil {
		if snapshot.UpdatedAt.IsZero() {
			snapshot.UpdatedAt = service.now()
		}
		snapshot.Units = units
		snapshot.RequestedLocation = location
		result := Result{State: Ready, Snapshot: snapshot}
		if saveErr := service.cache.Save(snapshot); saveErr != nil {
			result.Error = fmt.Sprintf("cache weather: %v", saveErr)
		}
		return result
	}

	cached, cacheErr := service.cache.Load()
	if cacheErr == nil && cached.RequestedLocation == location && cached.Units == units {
		age := service.now().Sub(cached.UpdatedAt)
		if age >= 0 && age <= staleLimit {
			return Result{
				State:      Stale,
				AgeMinutes: int(age.Round(time.Minute) / time.Minute),
				Snapshot:   cached,
				Error:      err.Error(),
			}
		}
	}

	message := err.Error()
	if cacheErr != nil {
		message = fmt.Sprintf("%s; cached weather unavailable: %v", message, cacheErr)
	} else if cached.RequestedLocation != location || cached.Units != units {
		message = fmt.Sprintf("%s; cached weather belongs to another location or unit system", message)
	}
	return Result{State: Unavailable, Error: message}
}
