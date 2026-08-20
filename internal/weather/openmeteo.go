package weather

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

type OpenMeteoClient struct {
	httpClient *http.Client
	endpoint   string
	now        func() time.Time
}

type openMeteoResponse struct {
	Current struct {
		Time        string  `json:"time"`
		Temperature float64 `json:"temperature_2m"`
		Humidity    int     `json:"relative_humidity_2m"`
		Apparent    float64 `json:"apparent_temperature"`
		WeatherCode int     `json:"weather_code"`
		WindSpeed   float64 `json:"wind_speed_10m"`
	} `json:"current"`
	Hourly struct {
		Time        []string  `json:"time"`
		Temperature []float64 `json:"temperature_2m"`
		WeatherCode []int     `json:"weather_code"`
	} `json:"hourly"`
	Daily struct {
		Time        []string  `json:"time"`
		Minimum     []float64 `json:"temperature_2m_min"`
		Maximum     []float64 `json:"temperature_2m_max"`
		WeatherCode []int     `json:"weather_code"`
	} `json:"daily"`
}

func NewOpenMeteoClient(client *http.Client, endpoint string, now func() time.Time) OpenMeteoClient {
	return OpenMeteoClient{httpClient: client, endpoint: endpoint, now: now}
}

func (client OpenMeteoClient) Fetch(
	ctx context.Context,
	location Location,
	units Units,
) (Snapshot, error) {
	requestURL, err := url.Parse(client.endpoint)
	if err != nil {
		return Snapshot{}, fmt.Errorf("parse Open-Meteo endpoint: %w", err)
	}
	query := requestURL.Query()
	query.Set("latitude", decimal(roundCoordinate(location.Latitude)))
	query.Set("longitude", decimal(roundCoordinate(location.Longitude)))
	query.Set("timezone", "auto")
	query.Set("current", "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m")
	query.Set("hourly", "temperature_2m,weather_code")
	query.Set("daily", "temperature_2m_min,temperature_2m_max,weather_code")
	query.Set("forecast_days", "6")
	if units == Fahrenheit {
		query.Set("temperature_unit", "fahrenheit")
		query.Set("wind_speed_unit", "mph")
	}
	requestURL.RawQuery = query.Encode()

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return Snapshot{}, fmt.Errorf("create Open-Meteo request: %w", err)
	}
	response, err := client.httpClient.Do(request)
	if err != nil {
		return Snapshot{}, fmt.Errorf("request Open-Meteo forecast: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return Snapshot{}, fmt.Errorf("Open-Meteo returned %s", response.Status)
	}

	var payload openMeteoResponse
	decoder := json.NewDecoder(response.Body)
	if err := decoder.Decode(&payload); err != nil {
		return Snapshot{}, fmt.Errorf("decode Open-Meteo response: %w", err)
	}
	if err := validateOpenMeteo(payload); err != nil {
		return Snapshot{}, err
	}

	start := 0
	for index, value := range payload.Hourly.Time {
		if value >= payload.Current.Time {
			start = index
			break
		}
	}
	hourEnd := min(start+12, len(payload.Hourly.Time))
	hours := make([]Hour, 0, hourEnd-start)
	for index := start; index < hourEnd; index++ {
		hours = append(hours, Hour{
			Time: payload.Hourly.Time[index], Temperature: payload.Hourly.Temperature[index],
			WeatherCode: payload.Hourly.WeatherCode[index],
		})
	}
	dayEnd := min(5, len(payload.Daily.Time))
	days := make([]Day, 0, dayEnd)
	for index := 0; index < dayEnd; index++ {
		days = append(days, Day{
			Date: payload.Daily.Time[index], Minimum: payload.Daily.Minimum[index],
			Maximum: payload.Daily.Maximum[index], WeatherCode: payload.Daily.WeatherCode[index],
		})
	}

	return Snapshot{
		UpdatedAt: client.now(),
		Units:     units,
		Current: Current{
			Temperature: payload.Current.Temperature,
			Apparent:    payload.Current.Apparent,
			Humidity:    payload.Current.Humidity,
			WeatherCode: payload.Current.WeatherCode,
			WindSpeed:   payload.Current.WindSpeed,
		},
		Hourly: hours,
		Daily:  days,
	}, nil
}

func validateOpenMeteo(payload openMeteoResponse) error {
	if strings.TrimSpace(payload.Current.Time) == "" {
		return fmt.Errorf("Open-Meteo response is missing current time")
	}
	if len(payload.Hourly.Time) == 0 ||
		len(payload.Hourly.Time) != len(payload.Hourly.Temperature) ||
		len(payload.Hourly.Time) != len(payload.Hourly.WeatherCode) {
		return fmt.Errorf("Open-Meteo hourly forecast is malformed")
	}
	if len(payload.Daily.Time) == 0 ||
		len(payload.Daily.Time) != len(payload.Daily.Minimum) ||
		len(payload.Daily.Time) != len(payload.Daily.Maximum) ||
		len(payload.Daily.Time) != len(payload.Daily.WeatherCode) {
		return fmt.Errorf("Open-Meteo daily forecast is malformed")
	}
	return nil
}

func roundCoordinate(value float64) float64 {
	return math.Round(value*10) / 10
}

func decimal(value float64) string {
	return strconv.FormatFloat(value, 'f', -1, 64)
}
