import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

ShellRoot {
    PanelWindow {
        id: panel

        property real displayScale: Screen.devicePixelRatio > 0
            ? Screen.devicePixelRatio
            : 1.0
        property real designToLogical: 1.0 / displayScale
        property real uiScale: 2.0

        anchors.top: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        implicitHeight: Math.ceil(500 * designToLogical * uiScale)
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Math.max(1, Math.round(49 * designToLogical * uiScale))
        mask: Region { item: island }
        focusable: island.displayMode === "weatherPanel" ||
            island.displayMode === "wifiPanel" ||
            island.displayMode === "settingsPanel"

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        WeatherKeyState {
            id: weatherKeyState
        }

        SettingsService {
            id: settingsService
        }

        Item {
            id: island

            property real unit: panel.designToLogical * panel.uiScale
            property int notchWidth: 170
            property int collapsedVisualHeight: 44
            property int normalHeight: 48
            property int musicHeight: 132
            property int detailHeight: 360
            property int systemDetailHeight: 480
            property int settingsHeight: 460
            property int wallpaperHeight: 480
            property int weatherSetupHeight: 220
            property int weatherDetailHeight: 480
            property int bluetoothEventHeight: 96
            property int cornerRadius: 13

            property string selectedMode: "normal"
            property string transientMode: ""
            property string displayMode: transientMode !== "" ? transientMode : selectedMode
            property bool hoverHold: false
            property bool persistentNormal: settingsService.loaded &&
                settingsService.alwaysShowDateTime &&
                selectedMode === "normal" && transientMode === ""
            property bool expanded: persistentNormal || hover.hovered || hoverHold || transientMode !== ""

            property var battery: UPower.displayDevice
            property real batteryLevel: battery && battery.ready
                ? Math.max(0, Math.min(1, battery.percentage))
                : 0
            property bool batteryCharging: battery && battery.ready &&
                (battery.state === UPowerDeviceState.Charging ||
                 battery.state === UPowerDeviceState.PendingCharge)
            property bool batteryFull: battery && battery.ready &&
                (battery.state === UPowerDeviceState.FullyCharged || batteryLevel >= 0.95)
            property color batteryColor: batteryCharging || batteryFull
                ? "#30d158"
                : batteryLevel <= 0.20
                    ? "#ff453a"
                    : batteryLevel <= 0.30 ? "#ffd60a" : "#f2f2f7"
            property color batteryShellColor: !batteryCharging && batteryLevel <= 0.20
                ? "#ff453a"
                : "#d1d1d6"
            property int lastBatteryState: -1
            property int lastBatteryPercent: -1
            property string batteryEventText: "Battery"

            property var activePlayer: {
                var players = Mpris.players.values
                for (var i = 0; i < players.length; ++i) {
                    if (players[i].isPlaying)
                        return players[i]
                }
                return players.length > 0 ? players[0] : null
            }
            property bool musicSessionAvailable: activePlayer !== null &&
                ((activePlayer.trackTitle || "") !== "" || activePlayer.canControl)
            property bool musicPlaying: activePlayer !== null && activePlayer.isPlaying
            property string musicTitle: activePlayer
                ? (activePlayer.trackTitle || activePlayer.identity || "Now Playing")
                : ""
            property string musicArtist: activePlayer
                ? (activePlayer.trackArtist || activePlayer.trackAlbumArtist || "")
                : ""
            property string musicArtRaw: activePlayer && activePlayer.trackArtUrl
                ? activePlayer.trackArtUrl.toString()
                : ""
            property string cachedMusicArtUrl: ""
            property url musicArtSource: cachedMusicArtUrl
            property real musicPosition: 0
            property real musicLength: activePlayer && activePlayer.lengthSupported
                ? Math.max(0, activePlayer.length)
                : 0
            property real musicProgress: musicLength > 0
                ? Math.max(0, Math.min(1, musicPosition / musicLength))
                : 0
            property string musicEventKey: musicSessionAvailable
                ? musicTitle + "\u241f" + musicArtist + "\u241f" + musicArtRaw
                : ""
            property string lastMusicEventKey: ""
            property bool musicEventInitialized: false
            property bool playbackStateInitialized: false
            property bool lastMusicPlaying: false

            property int volumePercent: 0
            property bool volumeMuted: false
            property int lastVolumePercent: -1
            property bool lastVolumeMuted: false
            property bool audioRecoveryCooldown: false
            property int brightnessPercent: 0
            property int lastBrightnessPercent: -1

            property bool wifiAvailable: false
            property bool wifiEnabled: false
            property string wifiSsid: ""
            property string lastWifiSsid: ""
            property bool wifiInitialized: false
            property bool bluetoothAvailable: false
            property bool bluetoothPowered: false
            property string bluetoothDevice: ""
            property string lastBluetoothDevice: ""
            property bool bluetoothInitialized: false
            property string connectionEventLabel: "Bluetooth"
            property string bluetoothEventText: "Bluetooth"

            TextMetrics {
                id: wifiLabelMetrics
                text: island.wifiSsid !== "" ? island.wifiSsid : "Wi-Fi"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            TextMetrics {
                id: bluetoothLabelMetrics
                text: island.bluetoothDevice !== "" ? island.bluetoothDevice : "Bluetooth"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            TextMetrics {
                id: bluetoothEventMetrics
                text: island.bluetoothEventText
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            property real connectivityLeftWingTarget:
                Math.max(170, Math.min(520, wifiLabelMetrics.advanceWidth + 66))
            property real connectivityRightWingTarget:
                Math.max(170, Math.min(520, bluetoothLabelMetrics.advanceWidth + 66))
            property real bluetoothEventRightWingTarget:
                Math.max(180, Math.min(520, bluetoothEventMetrics.advanceWidth + 70))
            property real bluetoothEventWingTarget:
                Math.max(145, bluetoothEventRightWingTarget)

            function modeWidth(mode) {
                if (mode === "music")
                    return 570
                if (mode === "wallpaperPanel")
                    return 620
                if (mode === "systemPanel")
                    return 700
                if (mode === "system")
                    return 700
                if (mode === "weatherPanel" || mode === "settingsPanel")
                    return 560
                if (mode === "calendarPanel")
                    return 540
                if (mode === "wifiPanel" || mode === "bluetoothPanel" || mode === "soundPanel")
                    return 540
                if (mode === "volume" || mode === "brightness")
                    return 370
                if (mode === "battery")
                    return 420
                return 540
            }

            function modeHeight(mode) {
                if (mode === "music")
                    return musicHeight
                if (mode === "wallpaperPanel")
                    return wallpaperHeight
                if (mode === "systemPanel")
                    return systemDetailHeight
                if (mode === "weatherPanel")
                    return weatherKeyState.configured
                        ? weatherDetailHeight
                        : weatherSetupHeight
                if (mode === "settingsPanel")
                    return settingsHeight
                if (mode === "calendarPanel" || mode === "wifiPanel" || mode === "bluetoothPanel" || mode === "soundPanel")
                    return detailHeight
                if (mode === "bluetooth")
                    return bluetoothEventHeight
                return normalHeight
            }

            function symmetricWing(mode) {
                return Math.max(0, (modeWidth(mode) - notchWidth) / 2)
            }

            property real targetLeftWing: {
                if (!expanded)
                    return 0
                if (displayMode === "connectivity")
                    return connectivityLeftWingTarget
                if (displayMode === "bluetooth")
                    return bluetoothEventWingTarget
                if (displayMode === "battery")
                    return 190
                return symmetricWing(displayMode)
            }

            property real targetRightWing: {
                if (!expanded)
                    return 0
                if (displayMode === "connectivity")
                    return connectivityRightWingTarget
                if (displayMode === "bluetooth")
                    return bluetoothEventWingTarget
                if (displayMode === "battery")
                    return symmetricWing("battery")
                return symmetricWing(displayMode)
            }

            property real targetWidth: notchWidth + targetLeftWing + targetRightWing
            property real targetHeight: expanded ? modeHeight(displayMode) : collapsedVisualHeight
            property real targetCenterOffset: (targetRightWing - targetLeftWing) / 2
            property real centerOffset: expanded ? targetCenterOffset : 0

            property real designWidth: unit > 0 ? width / unit : width
            property real designHeight: unit > 0 ? height / unit : height
            property real actualLeftWing:
                Math.max(0, designWidth / 2 - notchWidth / 2 - centerOffset)
            property real actualRightWing:
                Math.max(0, designWidth - notchWidth - actualLeftWing)
            property real wingWidth: Math.min(actualLeftWing, actualRightWing)
            property bool largeMotion:
                targetHeight > normalHeight || designHeight > normalHeight + 1

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: centerOffset * unit
            width: targetWidth * unit
            height: targetHeight * unit

            function showTransient(mode, duration) {
                transientMode = mode
                transientTimer.interval = duration || 1850
                transientTimer.restart()
            }

            function showConnectionEvent(label, text, duration) {
                connectionEventLabel = label
                bluetoothEventText = text
                showTransient("bluetooth", duration || 2200)
            }

            function resetToNormal() {
                selectedMode = "normal"
            }

            function openSettings() {
                transientTimer.stop()
                transientMode = ""
                selectedMode = "settingsPanel"
            }

            function openWallpapers() {
                transientTimer.stop()
                transientMode = ""
                selectedMode = selectedMode === "wallpaperPanel"
                    ? "normal"
                    : "wallpaperPanel"
            }

            function cycleMode() {
                if (selectedMode === "normal")
                    selectedMode = "weather"
                else if (selectedMode === "weather")
                    selectedMode = musicPlaying ? "music" : "connectivity"
                else if (selectedMode === "music")
                    selectedMode = "connectivity"
                else if (selectedMode === "connectivity")
                    selectedMode = "soundPanel"
                else if (selectedMode === "soundPanel")
                    selectedMode = "system"
                else if (selectedMode === "system")
                    selectedMode = "normal"
                else if (selectedMode === "systemPanel")
                    selectedMode = "system"
                else
                    selectedMode = "normal"
            }

            function openConnectivity(kind) {
                transientTimer.stop()
                transientMode = ""
                selectedMode = kind === "bluetooth" ? "bluetoothPanel" : "wifiPanel"
            }

            onMusicPlayingChanged: {
                if (!playbackStateInitialized) {
                    playbackStateInitialized = true
                    lastMusicPlaying = musicPlaying
                    if (musicPlaying && musicSessionAvailable) {
                        musicEventInitialized = true
                        lastMusicEventKey = musicEventKey
                        refreshArtwork()
                        showTransient("music", 2600)
                    }
                    return
                }

                var wasPlaying = lastMusicPlaying
                lastMusicPlaying = musicPlaying

                if (musicPlaying !== wasPlaying && musicSessionAvailable) {
                    refreshArtwork()
                    showTransient("music", musicPlaying ? 2600 : 2200)
                }

                if (!musicPlaying && selectedMode === "music")
                    selectedMode = "normal"
            }

            onMusicEventKeyChanged: {
                if (!musicPlaying || musicEventKey === "")
                    return

                if (!musicEventInitialized) {
                    musicEventInitialized = true
                    lastMusicEventKey = musicEventKey
                    showTransient("music", 2600)
                    return
                }

                if (musicEventKey !== lastMusicEventKey) {
                    lastMusicEventKey = musicEventKey
                    refreshArtwork()
                    showTransient("music", 2600)
                }
            }

            onMusicArtRawChanged: refreshArtwork()

            function refreshArtwork() {
                cachedMusicArtUrl = ""
                if (artFetch.running)
                    artFetch.running = false

                var raw = musicArtRaw
                if (raw === "")
                    return

                artFetch.command = [
                    "bash",
                    "-lc",
                    "set -e; " +
                    "url=\"$1\"; " +
                    "dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell/art\"; " +
                    "mkdir -p \"$dir\"; " +
                    "key=$(printf '%s' \"$url\" | sha256sum | cut -d' ' -f1); " +
                    "for ext in jpg jpeg png webp gif bmp avif img; do out=\"$dir/$key.$ext\"; if [ -s \"$out\" ]; then printf 'file://%s' \"$out\"; exit 0; fi; done; " +
                    "tmp=\"$dir/$key.tmp.$$\"; " +
                    "case \"$url\" in " +
                    "http://*|https://*) command -v curl >/dev/null 2>&1 || exit 0; curl -LfsS --max-time 8 \"$url\" -o \"$tmp\" ;; " +
                    "file://*) src=\"${url#file://}\"; [ -r \"$src\" ] || exit 0; cp -- \"$src\" \"$tmp\" ;; " +
                    "/*) [ -r \"$url\" ] || exit 0; cp -- \"$url\" \"$tmp\" ;; " +
                    "*) exit 0 ;; esac; " +
                    "[ -s \"$tmp\" ] || { rm -f \"$tmp\"; exit 0; }; " +
                    "mime=$(file -Lb --mime-type \"$tmp\" 2>/dev/null || true); " +
                    "case \"$mime\" in " +
                    "image/jpeg) ext=jpg ;; image/png) ext=png ;; image/webp) ext=webp ;; image/gif) ext=gif ;; image/bmp) ext=bmp ;; image/avif) ext=avif ;; image/*) ext=img ;; *) rm -f \"$tmp\"; exit 0 ;; esac; " +
                    "out=\"$dir/$key.$ext\"; mv -f \"$tmp\" \"$out\"; printf 'file://%s' \"$out\"",
                    "notch-art",
                    raw
                ]
                artFetch.running = true
            }

            function consumeVolume(raw) {
                var match = raw.match(/Volume:\s*([0-9.]+)/)
                if (!match) {
                    if (!audioRecovery.running && !audioRecoveryCooldown) {
                        audioRecoveryCooldown = true
                        audioRecovery.running = true
                        audioRecoveryCooldownTimer.restart()
                    }
                    return
                }

                var percent = Math.max(
                    0,
                    Math.min(100, Math.round(parseFloat(match[1]) * 100))
                )
                var muted = raw.indexOf("[MUTED]") !== -1
                volumePercent = percent
                volumeMuted = muted

                if (lastVolumePercent < 0) {
                    lastVolumePercent = percent
                    lastVolumeMuted = muted
                    return
                }

                if (percent !== lastVolumePercent || muted !== lastVolumeMuted) {
                    lastVolumePercent = percent
                    lastVolumeMuted = muted
                    showTransient("volume", 1850)
                }
            }

            function consumeBrightness(raw) {
                var percent = parseInt(raw.trim())
                if (isNaN(percent))
                    return

                percent = Math.max(0, Math.min(100, percent))
                brightnessPercent = percent

                if (lastBrightnessPercent < 0) {
                    lastBrightnessPercent = percent
                    return
                }

                if (percent !== lastBrightnessPercent) {
                    lastBrightnessPercent = percent
                    showTransient("brightness", 1850)
                }
            }

            function consumeWifi(raw) {
                var lines = raw.trim().split("\n")
                var valid = lines.length > 0 && lines[0] !== ""
                var nextSsid = ""

                if (!valid) {
                    wifiAvailable = false
                    wifiEnabled = false
                } else {
                    wifiAvailable = true
                    wifiEnabled = lines[0] === "enabled"
                    nextSsid = lines.length > 1 ? lines[1].trim() : ""
                }

                wifiSsid = nextSsid

                if (!wifiInitialized) {
                    wifiInitialized = true
                    lastWifiSsid = nextSsid
                    if (nextSsid !== "")
                        showConnectionEvent("Wi-Fi", nextSsid, 2200)
                    return
                }

                if (nextSsid !== lastWifiSsid) {
                    if (nextSsid !== "")
                        showConnectionEvent("Wi-Fi", nextSsid, 2200)
                    else if (lastWifiSsid !== "")
                        showConnectionEvent("Wi-Fi", lastWifiSsid + " disconnected", 2200)
                    lastWifiSsid = nextSsid
                }
            }

            function consumeBluetooth(raw) {
                var lines = raw.trim().split("\n")
                var valid = lines.length > 0 && lines[0] !== ""
                var nextDevice = ""

                if (!valid) {
                    bluetoothAvailable = false
                    bluetoothPowered = false
                } else {
                    bluetoothAvailable = true
                    bluetoothPowered = lines[0] === "yes"
                    nextDevice = lines.length > 1
                        ? lines.slice(1).join(" ").trim()
                        : ""
                }

                bluetoothDevice = nextDevice

                if (!bluetoothInitialized) {
                    bluetoothInitialized = true
                    lastBluetoothDevice = nextDevice
                    if (nextDevice !== "")
                        showConnectionEvent("Bluetooth", nextDevice, 2200)
                    return
                }

                if (nextDevice !== lastBluetoothDevice) {
                    if (nextDevice !== "")
                        showConnectionEvent("Bluetooth", nextDevice, 2200)
                    else if (lastBluetoothDevice !== "")
                        showConnectionEvent(
                            "Bluetooth",
                            lastBluetoothDevice + " disconnected",
                            2200
                        )
                    lastBluetoothDevice = nextDevice
                }
            }

            function crossedBatteryThreshold(previous, current) {
                var thresholds = [80, 50, 20, 10, 5, 2]
                for (var i = 0; i < thresholds.length; ++i) {
                    if (previous > thresholds[i] && current <= thresholds[i])
                        return thresholds[i]
                }
                return -1
            }

            function checkBatteryState() {
                if (!battery || !battery.ready)
                    return

                var percent = Math.round(batteryLevel * 100)
                if (lastBatteryPercent < 0) {
                    lastBatteryPercent = percent
                } else {
                    if (!batteryCharging && percent < lastBatteryPercent) {
                        var threshold = crossedBatteryThreshold(lastBatteryPercent, percent)
                        if (threshold >= 0) {
                            batteryEventText = threshold <= 20 ? "Low Battery" : "Battery"
                            showTransient("battery", 2200)
                        }
                    }
                    lastBatteryPercent = percent
                }

                var state = battery.state
                if (lastBatteryState < 0) {
                    lastBatteryState = state
                    return
                }
                if (state === lastBatteryState)
                    return

                var wasCharging = lastBatteryState === UPowerDeviceState.Charging ||
                    lastBatteryState === UPowerDeviceState.PendingCharge
                var isCharging = state === UPowerDeviceState.Charging ||
                    state === UPowerDeviceState.PendingCharge

                if (isCharging && !wasCharging) {
                    batteryEventText = "Charging"
                    showTransient("battery", 1850)
                } else if (!isCharging && wasCharging) {
                    batteryEventText = "On Battery"
                    showTransient("battery", 1850)
                }

                lastBatteryState = state
            }

            HoverHandler {
                id: hover

                onHoveredChanged: {
                    if (hovered) {
                        hoverExitTimer.stop()
                        if (!island.hoverHold && island.transientMode === "")
                            island.resetToNormal()
                        island.hoverHold = true
                    } else {
                        hoverExitTimer.restart()
                    }
                }
            }

            MouseArea {
                z: 0
                x: island.actualLeftWing * island.unit
                y: 0
                width: island.notchWidth * island.unit
                height: island.normalHeight * island.unit
                acceptedButtons: Qt.LeftButton
                onClicked: function(mouse) {
                    var modifierMask = Qt.ShiftModifier |
                        Qt.ControlModifier |
                        Qt.AltModifier |
                        Qt.MetaModifier
                    if ((mouse.modifiers & modifierMask) !== 0)
                        island.openWallpapers()
                    else
                        island.cycleMode()
                }
            }

            Timer {
                id: hoverExitTimer
                interval: 900
                repeat: false
                onTriggered: {
                    island.hoverHold = false
                    if (island.transientMode === "")
                        island.resetToNormal()
                }
            }

            Timer {
                id: transientTimer
                interval: 1850
                repeat: false
                onTriggered: {
                    island.transientMode = ""
                    if (!hover.hovered && !island.hoverHold)
                        island.resetToNormal()
                }
            }

            Timer {
                id: audioRecoveryCooldownTimer
                interval: 700
                repeat: false
                onTriggered: island.audioRecoveryCooldown = false
            }

            Timer {
                interval: 750
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: island.checkBatteryState()
            }

            Timer {
                interval: 180
                repeat: true
                running: island.musicSessionAvailable &&
                    (island.musicPlaying || island.displayMode === "music")
                triggeredOnStart: true
                onTriggered: {
                    island.musicPosition = island.activePlayer &&
                        island.activePlayer.positionSupported
                        ? Math.max(0, island.activePlayer.position)
                        : 0
                }
            }

            Timer {
                interval: island.displayMode === "volume" ? 45 : 90
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: {
                    if (!volumeProbe.running)
                        volumeProbe.running = true
                }
            }

            Process {
                id: volumeProbe
                command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeVolume(text)
                }
            }

            FileView {
                id: volumeEventWatcher
                path: {
                    var base = Quickshell.env("XDG_CACHE_HOME")
                    if (!base || base === "")
                        base = (Quickshell.env("HOME") || "") + "/.cache"
                    return base + "/notch-quickshell/volume-event"
                }
                watchChanges: true

                onFileChanged: {
                    reload()
                    island.showTransient("volume", 1850)
                    if (!volumeProbe.running)
                        volumeProbe.running = true
                }
            }

            Process {
                id: audioRecovery
                command: [
                    "bash",
                    "-lc",
                    "command -v wpctl >/dev/null 2>&1 || exit 0; " +
                    "wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && exit 0; " +
                    "id=$(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -m1 -Eo '[0-9]+\\.' | tr -d '.'); " +
                    "[ -n \"$id\" ] && wpctl set-default \"$id\" >/dev/null 2>&1 || true"
                ]
                onRunningChanged: {
                    if (!running && !volumeProbe.running)
                        volumeProbe.running = true
                }
            }

            Timer {
                interval: island.displayMode === "brightness" ? 60 : 140
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: {
                    if (!brightnessProbe.running)
                        brightnessProbe.running = true
                }
            }

            Process {
                id: brightnessProbe
                command: [
                    "bash",
                    "-lc",
                    "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeBrightness(text)
                }
            }

            Timer {
                interval: 1800
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: {
                    if (!wifiProbe.running)
                        wifiProbe.running = true
                    if (!bluetoothProbe.running)
                        bluetoothProbe.running = true
                }
            }

            Process {
                id: wifiProbe
                command: [
                    "bash",
                    "-lc",
                    "command -v nmcli >/dev/null 2>&1 || exit 0; " +
                    "nmcli -t -f WIFI general 2>/dev/null | head -n1; " +
                    "dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2 == \"wifi\" && $3 == \"connected\" {print $1; exit}'); " +
                    "if [ -n \"$dev\" ]; then profile=$(nmcli -g GENERAL.CONNECTION device show \"$dev\" 2>/dev/null | head -n1); " +
                    "if [ -n \"$profile\" ] && [ \"$profile\" != \"--\" ]; then nmcli -g 802-11-wireless.ssid connection show \"$profile\" 2>/dev/null | head -n1; fi; fi"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeWifi(text)
                }
            }

            Process {
                id: bluetoothProbe
                command: [
                    "bash",
                    "-lc",
                    "command -v bluetoothctl >/dev/null 2>&1 || exit 0; " +
                    "powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'); printf '%s\\n' \"$powered\"; " +
                    "addr=$(bluetoothctl devices Connected 2>/dev/null | awk 'NR == 1 {print $2}'); " +
                    "if [ -n \"$addr\" ]; then info=$(bluetoothctl info \"$addr\" 2>/dev/null); " +
                    "alias=$(printf '%s\\n' \"$info\" | sed -n 's/^[[:space:]]*Alias: //p' | head -n1); " +
                    "name=$(printf '%s\\n' \"$info\" | sed -n 's/^[[:space:]]*Name: //p' | head -n1); " +
                    "label=\"${alias:-$name}\"; [ -n \"$label\" ] && printf '%s\\n' \"$label\"; fi"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeBluetooth(text)
                }
            }

            Process {
                id: artFetch
                stdout: StdioCollector {
                    onStreamFinished: {
                        var value = text.trim()
                        if (value !== "")
                            island.cachedMusicArtUrl = value
                    }
                }
            }

            Item {
                id: designSurface
                width: island.designWidth
                height: island.designHeight
                scale: island.unit
                transformOrigin: Item.TopLeft

                Shape {
                    anchors.fill: parent
                    antialiasing: true

                    ShapePath {
                        strokeWidth: -1
                        fillColor: "#000000"
                        startX: 0
                        startY: 0

                        PathLine { x: designSurface.width; y: 0 }
                        PathLine {
                            x: designSurface.width
                            y: designSurface.height - island.cornerRadius
                        }
                        PathQuad {
                            x: designSurface.width - island.cornerRadius
                            y: designSurface.height
                            controlX: designSurface.width
                            controlY: designSurface.height
                        }
                        PathLine {
                            x: island.cornerRadius
                            y: designSurface.height
                        }
                        PathQuad {
                            x: 0
                            y: designSurface.height - island.cornerRadius
                            controlX: 0
                            controlY: designSurface.height
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                NotchContent {
                    z: 1
                    anchors.fill: parent
                    displayMode: island.displayMode
                    expanded: island.expanded
                    wingWidth: island.wingWidth
                    leftWingWidth: island.actualLeftWing
                    rightWingWidth: island.actualRightWing
                    normalHeight: island.normalHeight
                    now: clock.date
                    battery: island.battery
                    batteryLevel: island.batteryLevel
                    batteryCharging: island.batteryCharging
                    batteryColor: island.batteryColor
                    batteryShellColor: island.batteryShellColor
                    batteryEventText: island.batteryEventText
                    musicPlaying: island.expanded && island.musicPlaying
                    musicSessionAvailable: island.musicSessionAvailable
                    activePlayer: island.activePlayer
                    musicTitle: island.musicTitle
                    musicArtist: island.musicArtist
                    musicArtSource: island.musicArtSource
                    musicPosition: island.musicPosition
                    musicLength: island.musicLength
                    musicProgress: island.musicProgress
                    volumePercent: island.volumePercent
                    volumeMuted: island.volumeMuted
                    brightnessPercent: island.brightnessPercent
                    wifiEnabled: island.wifiEnabled
                    wifiSsid: island.wifiSsid
                    bluetoothPowered: island.bluetoothPowered
                    bluetoothDevice: island.bluetoothDevice
                    connectionEventLabel: island.connectionEventLabel
                    bluetoothEventText: island.bluetoothEventText
                    detailPanelType: island.selectedMode === "bluetoothPanel"
                        ? "bluetooth"
                        : "wifi"

                    onWifiPanelRequested: island.openConnectivity("wifi")
                    onBluetoothPanelRequested: island.openConnectivity("bluetooth")
                    onCalendarRequested: {
                        transientTimer.stop()
                        island.transientMode = ""
                        island.selectedMode = "calendarPanel"
                    }
                    onWeatherPanelRequested: {
                        transientTimer.stop()
                        island.transientMode = ""
                        island.selectedMode = "weatherPanel"
                    }
                    onDetailBackRequested: island.selectedMode = "connectivity"
                    onCalendarBackRequested: island.selectedMode = "normal"
                    onWeatherBackRequested: island.selectedMode = "weather"
                    onStatusRefreshRequested: {
                        if (!volumeProbe.running)
                            volumeProbe.running = true
                        if (!wifiProbe.running)
                            wifiProbe.running = true
                        if (!bluetoothProbe.running)
                            bluetoothProbe.running = true
                    }
                }

                SystemMonitor {
                    id: systemMonitor
                    active: island.expanded &&
                        (island.displayMode === "system" || island.displayMode === "systemPanel")
                }

                SystemPanel {
                    z: 2
                    anchors.fill: parent
                    active: island.expanded &&
                        (island.displayMode === "system" || island.displayMode === "systemPanel")
                    detailMode: island.displayMode === "systemPanel"
                    leftWingWidth: island.actualLeftWing
                    rightWingWidth: island.actualRightWing
                    normalHeight: island.normalHeight
                    monitor: systemMonitor
                    onDetailRequested: {
                        transientTimer.stop()
                        island.transientMode = ""
                        island.selectedMode = "systemPanel"
                    }
                    onBackRequested: island.selectedMode = "system"
                }

                NormalSettingsOverlay {
                    z: 3
                    active: island.displayMode === "normal" && island.expanded
                    leftWingWidth: island.actualLeftWing
                    rightWingWidth: island.actualRightWing
                    normalHeight: island.normalHeight
                    now: clock.date
                    timeText: settingsService.timeText
                    dateText: settingsService.dateText
                    showBattery: settingsService.showBattery
                    battery: island.battery
                    batteryLevel: island.batteryLevel
                    batteryCharging: island.batteryCharging
                    batteryColor: island.batteryColor
                    batteryShellColor: island.batteryShellColor
                    onSettingsRequested: island.openSettings()
                    onCalendarRequested: {
                        transientTimer.stop()
                        island.transientMode = ""
                        island.selectedMode = "calendarPanel"
                    }
                }

                SettingsPanel {
                    z: 4
                    anchors.fill: parent
                    active: island.displayMode === "settingsPanel" && island.expanded
                    settings: settingsService
                    weatherConfigured: weatherKeyState.configured
                    onCloseRequested: island.selectedMode = "normal"
                    onCalendarRequested: island.selectedMode = "calendarPanel"
                    onWeatherRequested: island.selectedMode = "weatherPanel"
                }

                WallpaperPanel {
                    z: 5
                    anchors.fill: parent
                    active: island.displayMode === "wallpaperPanel" && island.expanded
                    onCloseRequested: island.selectedMode = "normal"
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: island.largeMotion ? 185 : 285
                    easing.type: Easing.OutBack
                    easing.overshoot: island.largeMotion ? 0.42 : 0.72
                }
            }

            Behavior on centerOffset {
                NumberAnimation {
                    duration: island.largeMotion ? 185 : 285
                    easing.type: Easing.OutBack
                    easing.overshoot: island.largeMotion ? 0.42 : 0.72
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: island.largeMotion ? 175 : 265
                    easing.type: island.largeMotion ? Easing.OutCubic : Easing.OutBack
                    easing.overshoot: 0.38
                }
            }
        }
    }
}
