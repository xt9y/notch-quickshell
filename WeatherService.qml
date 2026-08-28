import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool keyLoaded: false
    property string apiKey: ""
    property string pendingKey: ""
    property bool loading: false
    property bool ready: false
    property string errorText: ""
    property date lastUpdated: new Date(0)

    property string locationName: ""
    property string locationRegion: ""
    property string locationCountry: ""
    property string localTime: ""

    property real tempC: 0
    property real feelsLikeC: 0
    property string conditionText: ""
    property int rainChance: 0
    property int humidity: 0
    property int cloud: 0
    property real windKph: 0
    property string windDir: ""
    property real gustKph: 0
    property real pressureMb: 0
    property real precipMm: 0
    property real visibilityKm: 0
    property real uv: 0
    property real dewpointC: 0

    property var forecastDays: []
    property var hourlyForecast: []
    property var alerts: []
    property var airQuality: ({})

    width: 0
    height: 0
    visible: false

    function number(value, fallback) {
        var n = Number(value)
        return isFinite(n) ? n : (fallback === undefined ? 0 : fallback)
    }

    function saveApiKey(value) {
        var key = (value || "").trim()
        if (key === "" || saveKey.running)
            return

        pendingKey = key
        saveKey.environment = ({ WEATHER_API_KEY: key })
        saveKey.running = true
    }

    function clearApiKey() {
        if (clearKey.running)
            return
        clearKey.running = true
    }

    function refresh() {
        if (!keyLoaded || apiKey === "" || weatherFetch.running)
            return

        loading = true
        errorText = ""
        weatherFetch.environment = ({ WEATHER_API_KEY: apiKey })
        weatherFetch.running = true
    }

    function consumeWeather(raw) {
        var text = (raw || "").trim()
        if (text === "") {
            errorText = "Weather request failed"
            return
        }

        var data
        try {
            data = JSON.parse(text)
        } catch (e) {
            errorText = "Weather response could not be read"
            return
        }

        if (data.error) {
            errorText = data.error.message || "Weather API error"
            return
        }

        if (!data.location || !data.current) {
            errorText = "Weather response is incomplete"
            return
        }

        locationName = data.location.name || ""
        locationRegion = data.location.region || ""
        locationCountry = data.location.country || ""
        localTime = data.location.localtime || ""

        var current = data.current
        tempC = number(current.temp_c)
        feelsLikeC = number(current.feelslike_c)
        conditionText = current.condition && current.condition.text
            ? current.condition.text
            : ""
        humidity = Math.round(number(current.humidity))
        cloud = Math.round(number(current.cloud))
        windKph = number(current.wind_kph)
        windDir = current.wind_dir || ""
        gustKph = number(current.gust_kph)
        pressureMb = number(current.pressure_mb)
        precipMm = number(current.precip_mm)
        visibilityKm = number(current.vis_km)
        uv = number(current.uv)
        dewpointC = number(current.dewpoint_c)
        airQuality = current.air_quality || ({})

        var days = []
        var hours = []
        var forecast = data.forecast && data.forecast.forecastday
            ? data.forecast.forecastday
            : []
        var nowEpoch = number(current.last_updated_epoch, Date.now() / 1000)

        for (var i = 0; i < forecast.length; ++i) {
            var sourceDay = forecast[i]
            var day = sourceDay.day || ({})
            var astro = sourceDay.astro || ({})

            days.push({
                date: sourceDay.date || "",
                condition: day.condition && day.condition.text ? day.condition.text : "",
                maxC: number(day.maxtemp_c),
                minC: number(day.mintemp_c),
                avgC: number(day.avgtemp_c),
                maxWindKph: number(day.maxwind_kph),
                totalPrecipMm: number(day.totalprecip_mm),
                totalSnowCm: number(day.totalsnow_cm),
                avgHumidity: Math.round(number(day.avghumidity)),
                rainChance: Math.round(number(day.daily_chance_of_rain)),
                snowChance: Math.round(number(day.daily_chance_of_snow)),
                uv: number(day.uv),
                sunrise: astro.sunrise || "",
                sunset: astro.sunset || "",
                moonrise: astro.moonrise || "",
                moonset: astro.moonset || "",
                moonPhase: astro.moon_phase || "",
                moonIllumination: astro.moon_illumination || ""
            })

            var dayHours = sourceDay.hour || []
            for (var h = 0; h < dayHours.length; ++h) {
                var hour = dayHours[h]
                var epoch = number(hour.time_epoch)
                if (epoch + 1800 < nowEpoch || hours.length >= 24)
                    continue

                hours.push({
                    time: hour.time || "",
                    tempC: number(hour.temp_c),
                    feelsLikeC: number(hour.feelslike_c),
                    condition: hour.condition && hour.condition.text ? hour.condition.text : "",
                    rainChance: Math.round(number(hour.chance_of_rain)),
                    snowChance: Math.round(number(hour.chance_of_snow)),
                    precipMm: number(hour.precip_mm),
                    humidity: Math.round(number(hour.humidity)),
                    cloud: Math.round(number(hour.cloud)),
                    windKph: number(hour.wind_kph),
                    windDir: hour.wind_dir || "",
                    gustKph: number(hour.gust_kph),
                    pressureMb: number(hour.pressure_mb),
                    visibilityKm: number(hour.vis_km),
                    uv: number(hour.uv),
                    dewpointC: number(hour.dewpoint_c)
                })
            }
        }

        forecastDays = days
        hourlyForecast = hours
        alerts = data.alerts && data.alerts.alert ? data.alerts.alert : []
        rainChance = days.length > 0 ? days[0].rainChance : 0
        ready = true
        errorText = ""
        lastUpdated = new Date()
    }

    Component.onCompleted: keyLoad.running = true

    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: root.apiKey !== ""
        onTriggered: root.refresh()
    }

    Process {
        id: keyLoad
        command: [
            "bash",
            "-lc",
            "file=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell/weather-api-key\"; " +
            "[ -r \"$file\" ] && cat \"$file\" || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.apiKey = text.trim()
                root.keyLoaded = true
                if (root.apiKey !== "")
                    Qt.callLater(root.refresh)
            }
        }
    }

    Process {
        id: saveKey
        command: [
            "bash",
            "-lc",
            "set -e; umask 077; " +
            "dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell\"; " +
            "mkdir -p \"$dir\"; printf '%s' \"$WEATHER_API_KEY\" > \"$dir/weather-api-key\""
        ]
        onRunningChanged: if (!running) {
            environment = ({})
            if (root.pendingKey !== "") {
                root.apiKey = root.pendingKey
                root.pendingKey = ""
                root.keyLoaded = true
                root.ready = false
                Qt.callLater(root.refresh)
            }
        }
    }

    Process {
        id: clearKey
        command: [
            "bash",
            "-lc",
            "rm -f \"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell/weather-api-key\""
        ]
        onRunningChanged: if (!running) {
            root.apiKey = ""
            root.pendingKey = ""
            root.ready = false
            root.errorText = ""
            root.forecastDays = []
            root.hourlyForecast = []
            root.alerts = []
            root.airQuality = ({})
        }
    }

    Process {
        id: weatherFetch
        command: [
            "bash",
            "-lc",
            "command -v curl >/dev/null 2>&1 || exit 0; " +
            "curl -fsS --max-time 15 --get 'https://api.weatherapi.com/v1/forecast.json' " +
            "--data-urlencode \"key=$WEATHER_API_KEY\" " +
            "--data-urlencode 'q=auto:ip' " +
            "--data-urlencode 'days=3' " +
            "--data-urlencode 'aqi=yes' " +
            "--data-urlencode 'alerts=yes'"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.consumeWeather(text)
        }
        onRunningChanged: if (!running) {
            environment = ({})
            root.loading = false
        }
    }
}
