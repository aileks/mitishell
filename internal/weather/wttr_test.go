package weather_test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/aileks/mitishell/internal/weather"
)

func wttrFixture(t *testing.T, wrapped bool) []byte {
	t.Helper()
	hourly := make([]map[string]string, 8)
	for index := range hourly {
		hourly[index] = map[string]string{
			"time": fmt.Sprintf("%d", index*300), "tempC": "20", "tempF": "68", "weatherCode": "116",
		}
	}
	days := make([]map[string]any, 3)
	for index := range days {
		days[index] = map[string]any{
			"date": fmt.Sprintf("2026-08-%02d", 20+index), "maxtempC": "25", "maxtempF": "77",
			"mintempC": "15", "mintempF": "59", "hourly": hourly,
		}
	}
	payload := map[string]any{
		"current_condition": []map[string]string{{
			"FeelsLikeC": "21", "FeelsLikeF": "70", "humidity": "61", "temp_C": "22", "temp_F": "72",
			"weatherCode": "113", "windspeedKmph": "12", "windspeedMiles": "7.5",
		}},
		"nearest_area": []map[string]any{{
			"areaName": []map[string]string{{"value": "Long Island City"}},
			"region":   []map[string]string{{"value": "New York"}},
			"country":  []map[string]string{{"value": "United States"}},
		}},
		"weather": days,
	}
	if wrapped {
		payload = map[string]any{"data": payload}
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}

func TestWttrBuildsManualURLAndNormalizesRootPayload(t *testing.T) {
	var escapedPath string
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		escapedPath = request.URL.EscapedPath()
		if request.URL.Query().Get("format") != "j1" {
			t.Errorf("query = %q", request.URL.RawQuery)
		}
		_, _ = response.Write(wttrFixture(t, false))
	}))
	defer server.Close()
	now := time.Date(2026, 8, 20, 12, 0, 0, 0, time.UTC)
	snapshot, err := weather.NewWttrClient(server.Client(), server.URL, func() time.Time { return now }).Fetch(
		context.Background(), "New York/USA", weather.Celsius)
	if err != nil {
		t.Fatal(err)
	}
	if escapedPath != "/New%20York%2FUSA" || snapshot.ResolvedLocation != "Long Island City, New York" {
		t.Fatalf("path=%q snapshot=%#v", escapedPath, snapshot)
	}
	if snapshot.Current.WeatherCode != 0 || len(snapshot.Hourly) != 24 || len(snapshot.Daily) != 3 || snapshot.Hourly[0].Time != "2026-08-20T00:00" {
		t.Fatalf("snapshot = %#v", snapshot)
	}
}

func TestWttrAcceptsWrappedPayloadAndSelectsImperialUnits(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/" {
			t.Errorf("automatic path = %q", request.URL.Path)
		}
		_, _ = response.Write(wttrFixture(t, true))
	}))
	defer server.Close()
	snapshot, err := weather.NewWttrClient(server.Client(), server.URL, time.Now).Fetch(context.Background(), "", weather.Fahrenheit)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Current.Temperature != 72 || snapshot.Current.WindSpeed != 7.5 || snapshot.Hourly[0].Temperature != 68 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
}

func TestWttrRejectsMalformedPayload(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		payload := strings.Replace(string(wttrFixture(t, false)), `"humidity":"61"`, `"humidity":"wet"`, 1)
		_, _ = response.Write([]byte(payload))
	}))
	defer server.Close()
	if _, err := weather.NewWttrClient(server.Client(), server.URL, time.Now).Fetch(context.Background(), "", weather.Celsius); err == nil {
		t.Fatal("Fetch() accepted malformed numeric strings")
	}
}

func TestWttrNormalizesProviderConditionCodes(t *testing.T) {
	tests := []struct {
		provider string
		want     int
	}{{"248", 45}, {"308", 61}, {"338", 71}, {"389", 95}}
	for _, test := range tests {
		t.Run(test.provider, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
				payload := strings.Replace(string(wttrFixture(t, false)), `"weatherCode":"113"`, `"weatherCode":"`+test.provider+`"`, 1)
				_, _ = response.Write([]byte(payload))
			}))
			defer server.Close()
			snapshot, err := weather.NewWttrClient(server.Client(), server.URL, time.Now).Fetch(context.Background(), "", weather.Celsius)
			if err != nil {
				t.Fatal(err)
			}
			if snapshot.Current.WeatherCode != test.want {
				t.Fatalf("code = %d, want %d", snapshot.Current.WeatherCode, test.want)
			}
		})
	}
}
