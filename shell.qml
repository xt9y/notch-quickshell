import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

ShellRoot {
    PanelWindow {
        id: panel
        anchors.top: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        implicitHeight: 380
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 49
        mask: Region { item: island }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Item {
            id: island
            property int notchWidth: 170
            property int collapsedVisualHeight: 44
            property int normalHeight: 48
            property int musicHeight: 132
            property int detailHeight: 360
            property int cornerRadius: 13

            property string selectedMode: "normal"
            property string transientMode: ""
            property string displayMode: transientMode !== "" ? transientMode : selectedMode
            property bool hoverHold: false
            property bool expanded: hover.hovered || hoverHold || transientMode !== ""

            property var battery: UPower.displayDevice
            property real batteryLevel: battery && battery.ready ? Math.max(0, Math.min(1, battery.percentage)) : 0
            property bool batteryCharging: battery && battery.ready && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
            property bool batteryFull: battery && battery.ready && (battery.state === UPowerDeviceState.FullyCharged || batteryLevel >= 0.95)
            property color batteryColor: batteryCharging || batteryFull ? "#30d158" : batteryLevel <= 0.20 ? "#ff453a" : batteryLevel <= 0.30 ? "#ffd60a" : "#f2f2f7"
            property color batteryShellColor: !batteryCharging && batteryLevel <= 0.20 ? "#ff453a" : "#d1d1d6"
            property int lastBatteryState: -1
            property int lastBatteryPercent: -1
            property string batteryEventText: "Battery"

            property var activePlayer: {
                var players = Mpris.players.values
                for (var i = 0; i < players.length; ++i) if (players[i].isPlaying) return players[i]
                return players.length > 0 ? players[0] : null
            }
            property bool musicSessionAvailable: activePlayer !== null && ((activePlayer.trackTitle || "") !== "" || activePlayer.canControl)
            property bool musicPlaying: activePlayer !== null && activePlayer.isPlaying
            property string musicTitle: activePlayer ? (activePlayer.trackTitle || activePlayer.identity || "Now Playing") : ""
            property string musicArtist: activePlayer ? (activePlayer.trackArtist || activePlayer.trackAlbumArtist || "") : ""
            property string musicArtRaw: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl.toString() : ""
            property string cachedMusicArtUrl: ""
            property url musicArtSource: cachedMusicArtUrl !== "" ? cachedMusicArtUrl : normalizeArtUrl(musicArtRaw)
            property real musicPosition: 0
            property real musicLength: activePlayer && activePlayer.lengthSupported ? Math.max(0, activePlayer.length) : 0
            property real musicProgress: musicLength > 0 ? Math.max(0, Math.min(1, musicPosition / musicLength)) : 0
            property string musicEventKey: musicSessionAvailable ? musicTitle + "\u241f" + musicArtist + "\u241f" + musicArtRaw : ""
            property string lastMusicEventKey: ""
            property bool musicEventInitialized: false
            property bool playbackStateInitialized: false
            property bool lastMusicPlaying: false

            property int volumePercent: 0
            property bool volumeMuted: false
            property int lastVolumePercent: -1
            property bool lastVolumeMuted: false
            property int brightnessPercent: 0
            property int lastBrightnessPercent: -1

            property bool wifiAvailable: false
            property bool wifiEnabled: false
            property string wifiSsid: ""
            property bool bluetoothAvailable: false
            property bool bluetoothPowered: false
            property string bluetoothDevice: ""
            property string lastBluetoothDevice: ""
            property bool bluetoothInitialized: false
            property string bluetoothEventText: "Bluetooth"

            function normalizeArtUrl(raw) {
                if (!raw) return ""
                var value = raw.toString()
                if (value === "") return ""
                return value.charAt(0) === "/" ? "file://" + value : value
            }
            function modeWidth(mode) {
                if (mode === "music") return 530
                if (mode === "wifiPanel" || mode === "bluetoothPanel") return 540
                if (mode === "connectivity") return 510
                if (mode === "volume" || mode === "brightness") return 410
                if (mode === "battery") return 420
                if (mode === "bluetooth") return 460
                return 540
            }
            function modeHeight(mode) {
                if (mode === "music") return musicHeight
                if (mode === "wifiPanel" || mode === "bluetoothPanel") return detailHeight
                return normalHeight
            }
            property real targetWidth: expanded ? modeWidth(displayMode) : notchWidth
            property real targetHeight: expanded ? modeHeight(displayMode) : collapsedVisualHeight
            property real wingWidth: (width - notchWidth) / 2
            property bool largeMotion: targetHeight > normalHeight || height > normalHeight + 1

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: targetWidth
            height: targetHeight

            function showTransient(mode, duration) {
                transientMode = mode
                transientTimer.interval = duration || 1850
                transientTimer.restart()
            }
            function resetToNormal() { selectedMode = "normal" }
            function cycleMode() {
                if (selectedMode === "normal") selectedMode = musicPlaying ? "music" : "connectivity"
                else if (selectedMode === "music") selectedMode = "connectivity"
                else selectedMode = "normal"
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
                if (!musicPlaying && selectedMode === "music") selectedMode = "normal"
            }
            onMusicEventKeyChanged: {
                if (!musicPlaying || musicEventKey === "") return
                if (!musicEventInitialized) {
                    musicEventInitialized = true
                    lastMusicEventKey = musicEventKey
                    showTransient("music", 2600)
                    return
                }
                if (musicEventKey !== lastMusicEventKey) {
                    lastMusicEventKey = musicEventKey
                    showTransient("music", 2600)
                }
            }
            onMusicArtRawChanged: refreshArtwork()

            function refreshArtwork() {
                cachedMusicArtUrl = ""
                if (artFetch.running) artFetch.running = false
                var raw = musicArtRaw
                if (raw.indexOf("http://") !== 0 && raw.indexOf("https://") !== 0) return
                artFetch.command = [
                    "bash", "-lc",
                    "set -e; url=\"$1\"; command -v curl >/dev/null 2>&1 || exit 0; dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell/art\"; mkdir -p \"$dir\"; key=$(printf '%s' \"$url\" | sha256sum | cut -d' ' -f1); out=\"$dir/$key\"; if [ ! -s \"$out\" ]; then tmp=\"$out.tmp.$$\"; curl -LfsS --max-time 8 \"$url\" -o \"$tmp\" && mv \"$tmp\" \"$out\" || { rm -f \"$tmp\"; exit 0; }; fi; [ -s \"$out\" ] && printf 'file://%s' \"$out\"",
                    "notch-art", raw
                ]
                artFetch.running = true
            }

            function consumeVolume(raw) {
                var match = raw.match(/Volume:\s*([0-9.]+)/)
                if (!match) return
                var percent = Math.max(0, Math.min(100, Math.round(parseFloat(match[1]) * 100)))
                var muted = raw.indexOf("[MUTED]") !== -1
                volumePercent = percent
                volumeMuted = muted
                if (lastVolumePercent < 0) { lastVolumePercent = percent; lastVolumeMuted = muted; return }
                if (percent !== lastVolumePercent || muted !== lastVolumeMuted) {
                    lastVolumePercent = percent
                    lastVolumeMuted = muted
                    showTransient("volume", 1850)
                }
            }
            function consumeBrightness(raw) {
                var percent = parseInt(raw.trim())
                if (isNaN(percent)) return
                percent = Math.max(0, Math.min(100, percent))
                brightnessPercent = percent
                if (lastBrightnessPercent < 0) { lastBrightnessPercent = percent; return }
                if (percent !== lastBrightnessPercent) { lastBrightnessPercent = percent; showTransient("brightness", 1850) }
            }
            function consumeWifi(raw) {
                var lines = raw.trim().split("\n")
                if (lines.length === 0 || lines[0] === "") { wifiAvailable = false; wifiEnabled = false; wifiSsid = ""; return }
                wifiAvailable = true
                wifiEnabled = lines[0] === "enabled"
                wifiSsid = lines.length > 1 ? lines[1].trim() : ""
            }
            function consumeBluetooth(raw) {
                var lines = raw.trim().split("\n")
                if (lines.length === 0 || lines[0] === "") { bluetoothAvailable = false; bluetoothPowered = false; bluetoothDevice = ""; return }
                bluetoothAvailable = true
                bluetoothPowered = lines[0] === "yes"
                bluetoothDevice = lines.length > 1 ? lines.slice(1).join(" ").trim() : ""
                if (!bluetoothInitialized) { bluetoothInitialized = true; lastBluetoothDevice = bluetoothDevice; return }
                if (bluetoothDevice !== lastBluetoothDevice) {
                    if (bluetoothDevice !== "") { bluetoothEventText = bluetoothDevice; showTransient("bluetooth", 1850) }
                    else if (lastBluetoothDevice !== "") { bluetoothEventText = lastBluetoothDevice + " disconnected"; showTransient("bluetooth", 1850) }
                    lastBluetoothDevice = bluetoothDevice
                }
            }
            function crossedBatteryThreshold(previous, current) {
                var thresholds = [80, 50, 20, 10, 5, 2]
                for (var i = 0; i < thresholds.length; ++i) if (previous > thresholds[i] && current <= thresholds[i]) return thresholds[i]
                return -1
            }
            function checkBatteryState() {
                if (!battery || !battery.ready) return
                var percent = Math.round(batteryLevel * 100)
                if (lastBatteryPercent < 0) lastBatteryPercent = percent
                else {
                    if (!batteryCharging && percent < lastBatteryPercent) {
                        var threshold = crossedBatteryThreshold(lastBatteryPercent, percent)
                        if (threshold >= 0) { batteryEventText = threshold <= 20 ? "Low Battery" : "Battery"; showTransient("battery", 2200) }
                    }
                    lastBatteryPercent = percent
                }
                var state = battery.state
                if (lastBatteryState < 0) { lastBatteryState = state; return }
                if (state === lastBatteryState) return
                var wasCharging = lastBatteryState === UPowerDeviceState.Charging || lastBatteryState === UPowerDeviceState.PendingCharge
                var isCharging = state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
                if (isCharging && !wasCharging) { batteryEventText = "Charging"; showTransient("battery", 1850) }
                else if (!isCharging && wasCharging) { batteryEventText = "On Battery"; showTransient("battery", 1850) }
                lastBatteryState = state
            }

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        hoverExitTimer.stop()
                        if (!island.hoverHold && island.transientMode === "") island.resetToNormal()
                        island.hoverHold = true
                    } else hoverExitTimer.restart()
                }
            }
            MouseArea {
                z: 0
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: island.notchWidth
                height: island.normalHeight
                onClicked: island.cycleMode()
            }
            Timer {
                id: hoverExitTimer
                interval: 900
                repeat: false
                onTriggered: { island.hoverHold = false; if (island.transientMode === "") island.resetToNormal() }
            }
            Timer {
                id: transientTimer
                interval: 1850
                repeat: false
                onTriggered: { island.transientMode = ""; if (!hover.hovered && !island.hoverHold) island.resetToNormal() }
            }
            Timer { interval: 750; repeat: true; running: true; triggeredOnStart: true; onTriggered: island.checkBatteryState() }
            Timer {
                interval: 180
                repeat: true
                running: island.musicSessionAvailable && (island.musicPlaying || island.displayMode === "music")
                triggeredOnStart: true
                onTriggered: island.musicPosition = island.activePlayer && island.activePlayer.positionSupported ? Math.max(0, island.activePlayer.position) : 0
            }
            Timer { interval: island.displayMode === "volume" ? 45 : 120; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!volumeProbe.running) volumeProbe.running = true }
            Process { id: volumeProbe; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]; stdout: StdioCollector { onStreamFinished: island.consumeVolume(text) } }
            Timer { interval: island.displayMode === "brightness" ? 60 : 140; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!brightnessProbe.running) brightnessProbe.running = true }
            Process { id: brightnessProbe; command: ["bash", "-lc", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'"]; stdout: StdioCollector { onStreamFinished: island.consumeBrightness(text) } }
            Timer {
                interval: 1800
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: { if (!wifiProbe.running) wifiProbe.running = true; if (!bluetoothProbe.running) bluetoothProbe.running = true }
            }
            Process { id: wifiProbe; command: ["bash", "-lc", "command -v nmcli >/dev/null 2>&1 || exit 0; nmcli -t -f WIFI g 2>/dev/null; nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -n1"]; stdout: StdioCollector { onStreamFinished: island.consumeWifi(text) } }
            Process { id: bluetoothProbe; command: ["bash", "-lc", "command -v bluetoothctl >/dev/null 2>&1 || exit 0; bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'; bluetoothctl devices Connected 2>/dev/null | sed -n '1s/^Device [^ ]* //p'"]; stdout: StdioCollector { onStreamFinished: island.consumeBluetooth(text) } }
            Process { id: artFetch; stdout: StdioCollector { onStreamFinished: { var value = text.trim(); if (value !== "") island.cachedMusicArtUrl = value } } }

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeWidth: -1
                    fillColor: "#000000"
                    startX: 0
                    startY: 0
                    PathLine { x: island.width; y: 0 }
                    PathLine { x: island.width; y: island.height - island.cornerRadius }
                    PathQuad { x: island.width - island.cornerRadius; y: island.height; controlX: island.width; controlY: island.height }
                    PathLine { x: island.cornerRadius; y: island.height }
                    PathQuad { x: 0; y: island.height - island.cornerRadius; controlX: 0; controlY: island.height }
                    PathLine { x: 0; y: 0 }
                }
            }

            NotchContent {
                z: 1
                anchors.fill: parent
                displayMode: island.displayMode
                expanded: island.expanded
                wingWidth: island.wingWidth
                normalHeight: island.normalHeight
                now: clock.date
                battery: island.battery
                batteryLevel: island.batteryLevel
                batteryCharging: island.batteryCharging
                batteryColor: island.batteryColor
                batteryShellColor: island.batteryShellColor
                batteryEventText: island.batteryEventText
                musicPlaying: island.musicPlaying
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
                bluetoothEventText: island.bluetoothEventText
                detailPanelType: island.selectedMode === "bluetoothPanel" ? "bluetooth" : "wifi"
                onWifiPanelRequested: island.openConnectivity("wifi")
                onBluetoothPanelRequested: island.openConnectivity("bluetooth")
                onDetailBackRequested: island.selectedMode = "connectivity"
                onStatusRefreshRequested: { if (!wifiProbe.running) wifiProbe.running = true; if (!bluetoothProbe.running) bluetoothProbe.running = true }
            }

            Behavior on width { NumberAnimation { duration: island.largeMotion ? 185 : 285; easing.type: Easing.OutBack; easing.overshoot: island.largeMotion ? 0.42 : 0.72 } }
            Behavior on height { NumberAnimation { duration: island.largeMotion ? 175 : 265; easing.type: island.largeMotion ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.38 } }
        }
    }
}
