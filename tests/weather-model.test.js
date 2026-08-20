const test = require("node:test");
const assert = require("node:assert/strict");

const WeatherModel = require("../shell/lib/WeatherModel.js");

test("WMO codes map to stable display categories", () => {
    assert.equal(WeatherModel.condition(0).key, "clear");
    assert.equal(WeatherModel.condition(3).key, "cloudy");
    assert.equal(WeatherModel.condition(45).key, "fog");
    assert.equal(WeatherModel.condition(61).key, "rain");
    assert.equal(WeatherModel.condition(75).key, "snow");
    assert.equal(WeatherModel.condition(95).key, "storm");
    assert.equal(WeatherModel.condition(999).key, "unknown");
});

test("weather values use compact normalized labels", () => {
    assert.equal(WeatherModel.temperature(21.6), "22°");
    assert.equal(WeatherModel.temperature(Number.NaN), "--°");
    assert.equal(WeatherModel.hour("2026-08-20T09:00"), "09:00");
    assert.equal(WeatherModel.hour("malformed"), "--:--");
});
