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

type WttrClient struct {
	httpClient *http.Client
	endpoint   string
	now        func() time.Time
}

type wttrValue struct {
	Value string `json:"value"`
}

type wttrCurrent struct {
	FeelsLikeC   string `json:"FeelsLikeC"`
	FeelsLikeF   string `json:"FeelsLikeF"`
	Humidity     string `json:"humidity"`
	TempC        string `json:"temp_C"`
	TempF        string `json:"temp_F"`
	WeatherCode  string `json:"weatherCode"`
	WindspeedKph string `json:"windspeedKmph"`
	WindspeedMph string `json:"windspeedMiles"`
}

type wttrHour struct {
	Time        string `json:"time"`
	TempC       string `json:"tempC"`
	TempF       string `json:"tempF"`
	WeatherCode string `json:"weatherCode"`
}

type wttrDay struct {
	Date   string     `json:"date"`
	MaxC   string     `json:"maxtempC"`
	MaxF   string     `json:"maxtempF"`
	MinC   string     `json:"mintempC"`
	MinF   string     `json:"mintempF"`
	Hourly []wttrHour `json:"hourly"`
}

type wttrArea struct {
	AreaName []wttrValue `json:"areaName"`
	Region   []wttrValue `json:"region"`
	Country  []wttrValue `json:"country"`
}

type wttrPayload struct {
	Current []wttrCurrent `json:"current_condition"`
	Areas   []wttrArea    `json:"nearest_area"`
	Weather []wttrDay     `json:"weather"`
}

func NewWttrClient(client *http.Client, endpoint string, now func() time.Time) WttrClient {
	return WttrClient{httpClient: client, endpoint: endpoint, now: now}
}

func (client WttrClient) Fetch(ctx context.Context, location string, units Units) (Snapshot, error) {
	requestURL, err := url.Parse(client.endpoint)
	if err != nil {
		return Snapshot{}, fmt.Errorf("parse wttr.in endpoint: %w", err)
	}
	if location != "" {
		basePath := strings.TrimSuffix(requestURL.Path, "/")
		baseEscapedPath := strings.TrimSuffix(requestURL.EscapedPath(), "/")
		requestURL.Path = basePath + "/" + location
		requestURL.RawPath = baseEscapedPath + "/" + url.PathEscape(location)
	}
	query := requestURL.Query()
	query.Set("format", "j1")
	requestURL.RawQuery = query.Encode()

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return Snapshot{}, fmt.Errorf("create wttr.in request: %w", err)
	}
	response, err := client.httpClient.Do(request)
	if err != nil {
		return Snapshot{}, fmt.Errorf("request wttr.in forecast: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return Snapshot{}, fmt.Errorf("wttr.in returned %s", response.Status)
	}

	var raw json.RawMessage
	if err := json.NewDecoder(response.Body).Decode(&raw); err != nil {
		return Snapshot{}, fmt.Errorf("decode wttr.in response: %w", err)
	}
	var wrapper struct {
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(raw, &wrapper); err != nil {
		return Snapshot{}, fmt.Errorf("decode wttr.in response: %w", err)
	}
	if len(wrapper.Data) > 0 && string(wrapper.Data) != "null" {
		raw = wrapper.Data
	}
	var payload wttrPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return Snapshot{}, fmt.Errorf("decode wttr.in forecast: %w", err)
	}
	return normalizeWttr(payload, location, units, client.now())
}

func normalizeWttr(payload wttrPayload, location string, units Units, updatedAt time.Time) (Snapshot, error) {
	if len(payload.Current) == 0 {
		return Snapshot{}, fmt.Errorf("wttr.in response is missing current conditions")
	}
	if len(payload.Weather) < 3 {
		return Snapshot{}, fmt.Errorf("wttr.in response must contain three forecast days")
	}
	current := payload.Current[0]
	temperatureField, apparentField, windField := current.TempC, current.FeelsLikeC, current.WindspeedKph
	if units == Fahrenheit {
		temperatureField, apparentField, windField = current.TempF, current.FeelsLikeF, current.WindspeedMph
	}
	temperature, err := strictFloat("current temperature", temperatureField)
	if err != nil {
		return Snapshot{}, err
	}
	apparent, err := strictFloat("apparent temperature", apparentField)
	if err != nil {
		return Snapshot{}, err
	}
	humidity, err := strictInt("humidity", current.Humidity)
	if err != nil {
		return Snapshot{}, err
	}
	weatherCode, err := strictInt("current weather code", current.WeatherCode)
	if err != nil {
		return Snapshot{}, err
	}
	windSpeed, err := strictFloat("wind speed", windField)
	if err != nil {
		return Snapshot{}, err
	}

	hours := make([]Hour, 0, 24)
	days := make([]Day, 0, 3)
	for dayIndex := 0; dayIndex < 3; dayIndex++ {
		providerDay := payload.Weather[dayIndex]
		if _, err := time.Parse("2006-01-02", providerDay.Date); err != nil {
			return Snapshot{}, fmt.Errorf("wttr.in forecast date is invalid: %w", err)
		}
		if len(providerDay.Hourly) < 8 {
			return Snapshot{}, fmt.Errorf("wttr.in forecast day %s must contain eight hourly entries", providerDay.Date)
		}
		minimumField, maximumField := providerDay.MinC, providerDay.MaxC
		if units == Fahrenheit {
			minimumField, maximumField = providerDay.MinF, providerDay.MaxF
		}
		minimum, err := strictFloat("daily minimum", minimumField)
		if err != nil {
			return Snapshot{}, err
		}
		maximum, err := strictFloat("daily maximum", maximumField)
		if err != nil {
			return Snapshot{}, err
		}
		dayCode := 0
		for hourIndex := 0; hourIndex < 8; hourIndex++ {
			providerHour := providerDay.Hourly[hourIndex]
			clock, err := wttrClock(providerHour.Time)
			if err != nil {
				return Snapshot{}, err
			}
			hourTemperatureField := providerHour.TempC
			if units == Fahrenheit {
				hourTemperatureField = providerHour.TempF
			}
			hourTemperature, err := strictFloat("hourly temperature", hourTemperatureField)
			if err != nil {
				return Snapshot{}, err
			}
			providerCode, err := strictInt("hourly weather code", providerHour.WeatherCode)
			if err != nil {
				return Snapshot{}, err
			}
			normalizedCode := conditionCode(providerCode)
			if hourIndex == 4 {
				dayCode = normalizedCode
			}
			hours = append(hours, Hour{Time: providerDay.Date + "T" + clock, Temperature: hourTemperature, WeatherCode: normalizedCode})
		}
		days = append(days, Day{Date: providerDay.Date, Minimum: minimum, Maximum: maximum, WeatherCode: dayCode})
	}

	resolved := resolvedArea(payload.Areas)
	if resolved == "" {
		return Snapshot{}, fmt.Errorf("wttr.in response is missing the resolved location")
	}
	return Snapshot{
		UpdatedAt: updatedAt, Units: units, RequestedLocation: location,
		ResolvedLocation: resolved,
		Current:          Current{Temperature: temperature, Apparent: apparent, Humidity: humidity, WeatherCode: conditionCode(weatherCode), WindSpeed: windSpeed},
		Hourly:           hours, Daily: days,
	}, nil
}

func strictFloat(name, value string) (float64, error) {
	if strings.TrimSpace(value) == "" {
		return 0, fmt.Errorf("wttr.in response is missing %s", name)
	}
	parsed, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("wttr.in %s is invalid: %w", name, err)
	}
	if math.IsNaN(parsed) || math.IsInf(parsed, 0) {
		return 0, fmt.Errorf("wttr.in %s is not finite", name)
	}
	return parsed, nil
}

func strictInt(name, value string) (int, error) {
	if strings.TrimSpace(value) == "" {
		return 0, fmt.Errorf("wttr.in response is missing %s", name)
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("wttr.in %s is invalid: %w", name, err)
	}
	return parsed, nil
}

func wttrClock(value string) (string, error) {
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 0 || parsed > 2359 || parsed%100 >= 60 {
		return "", fmt.Errorf("wttr.in hourly time %q is invalid", value)
	}
	return fmt.Sprintf("%02d:%02d", parsed/100, parsed%100), nil
}

func conditionCode(code int) int {
	switch code {
	case 113:
		return 0
	case 116, 119, 122:
		return 2
	case 143, 248, 260:
		return 45
	case 179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377:
		return 71
	case 200, 386, 389, 392, 395:
		return 95
	default:
		return 61
	}
}

func resolvedArea(areas []wttrArea) string {
	if len(areas) == 0 {
		return ""
	}
	area := firstWttrValue(areas[0].AreaName)
	region := firstWttrValue(areas[0].Region)
	country := firstWttrValue(areas[0].Country)
	parts := []string{area, region}
	if !isUnitedStates(country) {
		parts = append(parts, country)
	}
	result := make([]string, 0, 3)
	seen := map[string]bool{}
	for _, value := range parts {
		key := strings.ToLower(value)
		if value == "" || seen[key] {
			continue
		}
		seen[key] = true
		result = append(result, value)
	}
	return strings.Join(result, ", ")
}

func firstWttrValue(values []wttrValue) string {
	if len(values) == 0 {
		return ""
	}
	return strings.TrimSpace(values[0].Value)
}

func isUnitedStates(country string) bool {
	switch strings.ToLower(country) {
	case "united states", "united states of america", "us", "usa":
		return true
	default:
		return false
	}
}
