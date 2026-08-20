package weather_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/weather"
)

func TestOpenMeteoRoundsCoordinatesAndNormalizesForecast(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if got := request.URL.Query().Get("latitude"); got != "40.7" {
			t.Errorf("latitude = %q", got)
		}
		if got := request.URL.Query().Get("longitude"); got != "-74" {
			t.Errorf("longitude = %q", got)
		}
		if got := request.URL.Query().Get("temperature_unit"); got != "fahrenheit" {
			t.Errorf("temperature_unit = %q", got)
		}
		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{
            "current":{"time":"2026-08-20T19:00","temperature_2m":75.2,"relative_humidity_2m":61,"apparent_temperature":76.1,"weather_code":2,"wind_speed_10m":8.5},
            "hourly":{"time":["2026-08-20T18:00","2026-08-20T19:00","2026-08-20T20:00"],"temperature_2m":[74,75.2,73],"weather_code":[1,2,3]},
            "daily":{"time":["2026-08-20","2026-08-21"],"temperature_2m_min":[66,64],"temperature_2m_max":[81,79],"weather_code":[2,3]}
        }`))
	}))
	defer server.Close()

	now := time.Date(2026, 8, 20, 23, 0, 0, 0, time.UTC)
	client := weather.NewOpenMeteoClient(server.Client(), server.URL, func() time.Time { return now })
	snapshot, err := client.Fetch(
		context.Background(),
		weather.Location{Latitude: 40.7128, Longitude: -74.006},
		weather.Fahrenheit,
	)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Current.Temperature != 75.2 || snapshot.Units != weather.Fahrenheit {
		t.Fatalf("current = %#v", snapshot.Current)
	}
	if len(snapshot.Hourly) != 2 || snapshot.Hourly[0].Time != "2026-08-20T19:00" {
		t.Fatalf("hourly = %#v", snapshot.Hourly)
	}
	if len(snapshot.Daily) != 2 || !snapshot.UpdatedAt.Equal(now) {
		t.Fatalf("snapshot = %#v", snapshot)
	}
}

func TestOpenMeteoRejectsMalformedProviderData(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{"current":{"temperature_2m":20}}`))
	}))
	defer server.Close()

	client := weather.NewOpenMeteoClient(server.Client(), server.URL, time.Now)
	if _, err := client.Fetch(context.Background(), weather.Location{}, weather.Celsius); err == nil {
		t.Fatal("Fetch() accepted malformed provider data")
	}
}
