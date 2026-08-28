#!/usr/bin/env python3
import json
import math
import os
import sys
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta

TIMEOUT = 12


def get_json(url, params=None, optional=False):
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "notch-quickshell/1"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        if optional:
            return {}
        raise


def valid_weatherapi(data):
    return isinstance(data, dict) and bool(data.get("location")) and bool(data.get("current")) and not data.get("error")


def valid_openweather(data):
    if not isinstance(data, dict):
        return False
    try:
        code = int(data.get("cod", 0))
    except Exception:
        code = 0
    return code == 200 and bool(data.get("coord")) and bool(data.get("main"))


def locate_ip():
    providers = [
        ("https://ipwho.is/", "latitude", "longitude"),
        ("https://ipapi.co/json/", "latitude", "longitude"),
    ]
    for url, lat_key, lon_key in providers:
        data = get_json(url, optional=True)
        try:
            lat = float(data.get(lat_key))
            lon = float(data.get(lon_key))
            if math.isfinite(lat) and math.isfinite(lon):
                return lat, lon
        except Exception:
            pass
    raise RuntimeError("Could not determine location")


def wind_dir(degrees):
    names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    try:
        return names[int((float(degrees) + 22.5) // 45) % 8]
    except Exception:
        return ""


def local_dt(epoch, offset):
    return datetime.fromtimestamp(float(epoch), tz=timezone.utc) + timedelta(seconds=int(offset or 0))


def local_stamp(epoch, offset):
    return local_dt(epoch, offset).strftime("%Y-%m-%d %H:%M")


def clock_stamp(epoch, offset):
    return local_dt(epoch, offset).strftime("%I:%M %p").lstrip("0")


def normalize_openweather(current, forecast, air):
    offset = int((forecast.get("city") or {}).get("timezone", current.get("timezone", 0)) or 0)
    coord = current.get("coord") or {}
    weather = (current.get("weather") or [{}])[0]
    main = current.get("main") or {}
    wind = current.get("wind") or {}
    clouds = current.get("clouds") or {}
    rain = current.get("rain") or {}
    snow = current.get("snow") or {}

    air_quality = {}
    air_list = air.get("list") if isinstance(air, dict) else None
    if air_list:
        first = air_list[0] or {}
        components = first.get("components") or {}
        air_quality = dict(components)
        aqi = (first.get("main") or {}).get("aqi")
        if aqi is not None:
            air_quality["us-epa-index"] = aqi

    entries = forecast.get("list") or []
    grouped = defaultdict(list)
    for item in entries:
        epoch = item.get("dt", 0)
        grouped[local_dt(epoch, offset).strftime("%Y-%m-%d")].append(item)

    forecast_days = []
    remaining_hours = 8  # 8 x 3-hour entries = the next 24 hours.
    for date_key in sorted(grouped.keys()):
        items = grouped[date_key]
        temps = [float((i.get("main") or {}).get("temp", 0)) for i in items]
        humidities = [float((i.get("main") or {}).get("humidity", 0)) for i in items]
        wind_speeds = [float((i.get("wind") or {}).get("speed", 0)) * 3.6 for i in items]
        descriptions = [((i.get("weather") or [{}])[0].get("description") or "").strip().title() for i in items]
        pop_values = [float(i.get("pop", 0) or 0) for i in items]
        total_rain = sum(float((i.get("rain") or {}).get("3h", 0) or 0) for i in items)
        total_snow = sum(float((i.get("snow") or {}).get("3h", 0) or 0) for i in items)
        condition = Counter([d for d in descriptions if d]).most_common(1)
        condition_text = condition[0][0] if condition else ""

        hours = []
        for item in items:
            if remaining_hours <= 0:
                break
            i_main = item.get("main") or {}
            i_weather = (item.get("weather") or [{}])[0]
            i_wind = item.get("wind") or {}
            hours.append({
                "time": local_stamp(item.get("dt", 0), offset),
                "time_epoch": item.get("dt", 0),
                "temp_c": i_main.get("temp", 0),
                "feelslike_c": i_main.get("feels_like", 0),
                "condition": {"text": (i_weather.get("description") or "").title()},
                "chance_of_rain": round(float(item.get("pop", 0) or 0) * 100),
                "chance_of_snow": round(float(item.get("pop", 0) or 0) * 100) if (item.get("snow") or {}) else 0,
                "precip_mm": float((item.get("rain") or {}).get("3h", 0) or 0) + float((item.get("snow") or {}).get("3h", 0) or 0),
                "humidity": i_main.get("humidity", 0),
                "cloud": (item.get("clouds") or {}).get("all", 0),
                "wind_kph": float(i_wind.get("speed", 0) or 0) * 3.6,
                "wind_dir": wind_dir(i_wind.get("deg", 0)),
                "gust_kph": float(i_wind.get("gust", 0) or 0) * 3.6,
                "pressure_mb": i_main.get("pressure", 0),
                "vis_km": float(item.get("visibility", 0) or 0) / 1000.0,
                "uv": 0,
                "dewpoint_c": 0,
            })
            remaining_hours -= 1

        is_today = date_key == local_dt(current.get("dt", 0), offset).strftime("%Y-%m-%d")
        sys_data = current.get("sys") or {}
        astro = {
            "sunrise": clock_stamp(sys_data.get("sunrise", 0), offset) if is_today and sys_data.get("sunrise") else "",
            "sunset": clock_stamp(sys_data.get("sunset", 0), offset) if is_today and sys_data.get("sunset") else "",
            "moonrise": "",
            "moonset": "",
            "moon_phase": "",
            "moon_illumination": "",
        }
        forecast_days.append({
            "date": date_key,
            "day": {
                "condition": {"text": condition_text},
                "maxtemp_c": max(temps) if temps else 0,
                "mintemp_c": min(temps) if temps else 0,
                "avgtemp_c": sum(temps) / len(temps) if temps else 0,
                "maxwind_kph": max(wind_speeds) if wind_speeds else 0,
                "totalprecip_mm": total_rain + total_snow,
                "totalsnow_cm": total_snow / 10.0,
                "avghumidity": sum(humidities) / len(humidities) if humidities else 0,
                "daily_chance_of_rain": round(max(pop_values, default=0) * 100),
                "daily_chance_of_snow": round(max(pop_values, default=0) * 100) if total_snow > 0 else 0,
                "uv": 0,
            },
            "astro": astro,
            "hour": hours,
        })

    return {
        "location": {
            "name": current.get("name", ""),
            "region": "",
            "country": (current.get("sys") or {}).get("country", ""),
            "lat": coord.get("lat", 0),
            "lon": coord.get("lon", 0),
            "localtime": local_stamp(current.get("dt", 0), offset),
        },
        "current": {
            "last_updated_epoch": current.get("dt", 0),
            "temp_c": main.get("temp", 0),
            "feelslike_c": main.get("feels_like", 0),
            "condition": {"text": (weather.get("description") or "").title()},
            "humidity": main.get("humidity", 0),
            "cloud": clouds.get("all", 0),
            "wind_kph": float(wind.get("speed", 0) or 0) * 3.6,
            "wind_dir": wind_dir(wind.get("deg", 0)),
            "gust_kph": float(wind.get("gust", 0) or 0) * 3.6,
            "pressure_mb": main.get("pressure", 0),
            "precip_mm": float(rain.get("1h", rain.get("3h", 0)) or 0) + float(snow.get("1h", snow.get("3h", 0)) or 0),
            "vis_km": float(current.get("visibility", 0) or 0) / 1000.0,
            "uv": 0,
            "dewpoint_c": 0,
            "air_quality": air_quality,
        },
        "forecast": {"forecastday": forecast_days},
        "alerts": {"alert": []},
    }


def detect(key):
    weatherapi = get_json(
        "https://api.weatherapi.com/v1/current.json",
        {"key": key, "q": "auto:ip"},
        optional=True,
    )
    if valid_weatherapi(weatherapi):
        print("weatherapi")
        return 0

    try:
        lat, lon = locate_ip()
    except Exception:
        print("invalid")
        return 1

    openweather = get_json(
        "https://api.openweathermap.org/data/2.5/weather",
        {"lat": lat, "lon": lon, "appid": key, "units": "metric"},
        optional=True,
    )
    if valid_openweather(openweather):
        print("openweather")
        return 0

    print("invalid")
    return 1


def fetch_weather(provider, key):
    if provider == "weatherapi":
        data = get_json(
            "https://api.weatherapi.com/v1/forecast.json",
            {"key": key, "q": "auto:ip", "days": 3, "aqi": "yes", "alerts": "yes"},
        )
        if not valid_weatherapi(data):
            raise RuntimeError((data.get("error") or {}).get("message", "WeatherAPI request failed"))
        print(json.dumps(data, separators=(",", ":")))
        return

    if provider != "openweather":
        raise RuntimeError("Unknown weather provider")

    lat, lon = locate_ip()
    common = {"lat": lat, "lon": lon, "appid": key, "units": "metric"}
    current = get_json("https://api.openweathermap.org/data/2.5/weather", common)
    if not valid_openweather(current):
        raise RuntimeError(current.get("message", "OpenWeather request failed") if isinstance(current, dict) else "OpenWeather request failed")
    forecast = get_json("https://api.openweathermap.org/data/2.5/forecast", common)
    air = get_json(
        "https://api.openweathermap.org/data/2.5/air_pollution",
        {"lat": lat, "lon": lon, "appid": key},
        optional=True,
    )
    print(json.dumps(normalize_openweather(current, forecast, air), separators=(",", ":")))


def main():
    if len(sys.argv) < 2:
        return 2
    key = os.environ.get("WEATHER_API_KEY", "").strip()
    if not key:
        print("invalid" if sys.argv[1] == "detect" else "")
        return 1

    if sys.argv[1] == "detect":
        return detect(key)
    if sys.argv[1] == "fetch":
        if len(sys.argv) < 3:
            return 2
        try:
            fetch_weather(sys.argv[2], key)
            return 0
        except Exception as exc:
            print(json.dumps({"error": {"message": str(exc)}}))
            return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
