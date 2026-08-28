import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

ShellRoot {
    PanelWindow {
        id: panel

        anchors {
            top: true
            left: true
            right: true
        }

        color: "transparent"

        // Large Music / Wi-Fi / Bluetooth views overlay the desktop. Plasma
        // only reserves the normal notch clearance.
        implicitHeight: 360
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 49

        mask: Region { item: island }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Item {
            id: island

            property int notchWidth: 170
            property int collapsedVisualHeight: 44
            property int normalHeight: 48
            property int musicHeight: 132
            property int connectivityPanelHeight: 360
            property int cornerRadius: 13

            property string selectedMode: "normal"
            property string transientMode: ""
            property string displayMode: transientMode !== "" ? transientMode : selectedMode
            property bool hoverHold: false
            property bool expanded: hover.hovered || hoverHold || transientMode !== ""

            // ---------- BATTERY ----------
            property var battery: UPower.displayDevice
            property real batteryLevel: battery && battery.ready
                ? Math.max(0, Math.min(1, battery.percentage)) : 0
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
                ? "#ff453a" : "#d1d1d6"
            property int lastBatteryState: -1
            property int lastBatteryPercent: -1
            property string batteryEventText: "Battery"

            // ---------- MEDIA ----------
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
                ? (activePlayer.trackTitle || activePlayer.identity || "Now Playing") : ""
            property string musicArtist: activePlayer
                ? (activePlayer.trackArtist || activePlayer.trackAlbumArtist || "") : ""
            property string musicArtRaw: activePlayer && activePlayer.trackArtUrl
                ? activePlayer.trackArtUrl.toString() : ""
            property string cachedMusicArtUrl: ""
            property url musicArtSource: cachedMusicArtUrl !== ""
                ? cachedMusicArtUrl : normalizeArtUrl(musicArtRaw)
            property real musicPosition: 0
            property real musicLength: activePlayer && activePlayer.lengthSupported
                ? Math.max(0, activePlayer.length) : 0
            property real musicProgress: musicLength > 0
                ? Math.max(0, Math.min(1, musicPosition / musicLength)) : 0
            property string musicEventKey: musicSessionAvailable
                ? musicTitle + "\u241f" + musicArtist + "\u241f" + musicArtRaw : ""
            property string lastMusicEventKey: ""
            property bool musicEventInitialized: false
            property bool playbackStateInitialized: false
            property bool lastMusicPlaying: false

            // ---------- VOLUME / BRIGHTNESS ----------
            property int volumePercent: 0
            property bool volumeMuted: false
            property int lastVolumePercent: -1
            property bool lastVolumeMuted: false
            property int brightnessPercent: 0
            property int lastBrightnessPercent: -1

            // ---------- CONNECTIVITY SUMMARY ----------
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
                if (!raw)
                    return ""
                var value = raw.toString()
                if (value === "")
                    return ""
                return value.charAt(0) === "/" ? "file://" + value : value
            }

            function modeWidth(mode) {
                if (mode === "music") return 530
                if (mode === "wifiPanel" || mode === "bluetoothPanel") return 540
                if (mode === "connectivity") return 510
                if (mode === "volume" || mode === "brightness") return 410
                if (mode === "battery") return 360
                if (mode === "bluetooth") return 460
                return 540
            }

            function modeHeight(mode) {
                if (mode === "music") return musicHeight
                if (mode === "wifiPanel" || mode === "bluetoothPanel") return connectivityPanelHeight
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

            // ---------- MODE / EVENT LOGIC ----------
            function showTransient(mode, duration) {
                transientMode = mode
                transientTimer.interval = duration || 1850
                transientTimer.restart()
            }

            function resetToNormal() {
                selectedMode = "normal"
            }

            function cycleMode() {
                if (selectedMode === "normal") {
                    selectedMode = musicPlaying ? "music" : "connectivity"
                } else if (selectedMode === "music") {
                    selectedMode = "connectivity"
                } else {
                    selectedMode = "normal"
                }
            }

            function openConnectivityPanel(kind) {
                transientTimer.stop()
                transientMode = ""
                selectedMode = kind === "bluetooth" ? "bluetoothPanel" : "wifiPanel"
                hoverHold = true
                Qt.callLater(function() { connectivityDetails.refreshCurrent(true) })
            }

            function formatTime(seconds) {
                if (!isFinite(seconds) || seconds < 0)
                    seconds = 0
                var total = Math.floor(seconds)
                var mins = Math.floor(total / 60)
                var secs = total % 60
                return mins + ":" + (secs < 10 ? "0" : "") + secs
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
                    showTransient("music", 2600)
                }
            }

            onMusicArtRawChanged: refreshArtwork()

            function refreshArtwork() {
                cachedMusicArtUrl = ""
                if (artFetch.running)
                    artFetch.running = false
                var raw = musicArtRaw
                if (raw.indexOf("http://") !== 0 && raw.indexOf("https://") !== 0)
                    return
                artFetch.command = [
                    "bash", "-lc",
                    "set -e; url=\"$1\"; command -v curl >/dev/null 2>&1 || exit 0; " +
                    "dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell/art\"; mkdir -p \"$dir\"; " +
                    "key=$(printf '%s' \"$url\" | sha256sum | cut -d' ' -f1); out=\"$dir/$key\"; " +
                    "if [ ! -s \"$out\" ]; then tmp=\"$out.tmp.$$\"; " +
                    "curl -LfsS --max-time 8 \"$url\" -o \"$tmp\" && mv \"$tmp\" \"$out\" || { rm -f \"$tmp\"; exit 0; }; fi; " +
                    "[ -s \"$out\" ] && printf 'file://%s' \"$out\"",
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
                if (isNaN(percent)) return
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
                if (lines.length === 0 || lines[0] === "") {
                    wifiAvailable = false
                    wifiEnabled = false
                    wifiSsid = ""
                    return
                }
                wifiAvailable = true
                wifiEnabled = lines[0] === "enabled"
                wifiSsid = lines.length > 1 ? lines[1].trim() : ""
            }

            function consumeBluetooth(raw) {
                var lines = raw.trim().split("\n")
                if (lines.length === 0 || lines[0] === "") {
                    bluetoothAvailable = false
                    bluetoothPowered = false
                    bluetoothDevice = ""
                    return
                }
                bluetoothAvailable = true
                bluetoothPowered = lines[0] === "yes"
                bluetoothDevice = lines.length > 1 ? lines.slice(1).join(" ").trim() : ""

                if (!bluetoothInitialized) {
                    bluetoothInitialized = true
                    lastBluetoothDevice = bluetoothDevice
                    return
                }
                if (bluetoothDevice !== lastBluetoothDevice) {
                    if (selectedMode !== "bluetoothPanel") {
                        if (bluetoothDevice !== "") {
                            bluetoothEventText = bluetoothDevice
                            showTransient("bluetooth", 1850)
                        } else if (lastBluetoothDevice !== "") {
                            bluetoothEventText = lastBluetoothDevice + " disconnected"
                            showTransient("bluetooth", 1850)
                        }
                    }
                    lastBluetoothDevice = bluetoothDevice
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
                if (!battery || !battery.ready) return
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
                if (state === lastBatteryState) return

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

            // ---------- POINTER ----------
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
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: island.normalHeight
                onClicked: island.cycleMode()
            }

            // ---------- TIMERS / PROBES ----------
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
                interval: 750
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: island.checkBatteryState()
            }

            Timer {
                interval: 180
                repeat: true
                running: island.musicPlaying || island.displayMode === "music"
                triggeredOnStart: true
                onTriggered: {
                    if (island.activePlayer && island.activePlayer.positionSupported)
                        island.musicPosition = Math.max(0, island.activePlayer.position)
                    else
                        island.musicPosition = 0
                }
            }

            Timer {
                interval: island.displayMode === "volume" ? 45 : 120
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: if (!volumeProbe.running) volumeProbe.running = true
            }

            Process {
                id: volumeProbe
                command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                stdout: StdioCollector { onStreamFinished: island.consumeVolume(text) }
            }

            Timer {
                interval: island.displayMode === "brightness" ? 60 : 140
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: if (!brightnessProbe.running) brightnessProbe.running = true
            }

            Process {
                id: brightnessProbe
                command: ["bash", "-lc", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'"]
                stdout: StdioCollector { onStreamFinished: island.consumeBrightness(text) }
            }

            Timer {
                interval: 1200
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: {
                    if (!wifiProbe.running) wifiProbe.running = true
                    if (!bluetoothProbe.running) bluetoothProbe.running = true
                }
            }

            Process {
                id: wifiProbe
                command: [
                    "bash", "-lc",
                    "command -v nmcli >/dev/null 2>&1 || exit 0; nmcli -t -f WIFI g 2>/dev/null; " +
                    "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -n1"
                ]
                stdout: StdioCollector { onStreamFinished: island.consumeWifi(text) }
            }

            Process {
                id: bluetoothProbe
                command: [
                    "bash", "-lc",
                    "command -v bluetoothctl >/dev/null 2>&1 || exit 0; " +
                    "bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'; " +
                    "bluetoothctl devices Connected 2>/dev/null | sed -n '1s/^Device [^ ]* //p'"
                ]
                stdout: StdioCollector { onStreamFinished: island.consumeBluetooth(text) }
            }

            Process {
                id: artFetch
                stdout: StdioCollector {
                    onStreamFinished: {
                        var value = text.trim()
                        if (value !== "") island.cachedMusicArtUrl = value
                    }
                }
            }

            // ---------- BLACK NOTCH SHAPE ----------
            Shape {
                id: notchShape
                anchors.fill: parent
                antialiasing: true

                ShapePath {
                    strokeWidth: -1
                    fillColor: "#000000"
                    startX: 0
                    startY: 0
                    PathLine { x: notchShape.width; y: 0 }
                    PathLine { x: notchShape.width; y: notchShape.height - island.cornerRadius }
                    PathQuad {
                        x: notchShape.width - island.cornerRadius
                        y: notchShape.height
                        controlX: notchShape.width
                        controlY: notchShape.height
                    }
                    PathLine { x: island.cornerRadius; y: notchShape.height }
                    PathQuad {
                        x: 0
                        y: notchShape.height - island.cornerRadius
                        controlX: 0
                        controlY: notchShape.height
                    }
                    PathLine { x: 0; y: 0 }
                }
            }

            Item {
                id: content
                anchors.fill: parent

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 19
                        top: parent.top
                        topMargin: 15
                    }
                    opacity: island.musicPlaying && !island.expanded ? 1 : 0
                    visible: opacity > 0.01
                    text: "♪"
                    color: "#c7c7cc"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                // ---------- NORMAL ----------
                Item {
                    id: normalMode
                    property bool active: island.displayMode === "normal" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    enabled: active
                    transformOrigin: Item.Top
                    Behavior on opacity { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

                    Item {
                        id: normalLeft
                        anchors { left: parent.left; top: parent.top }
                        width: island.wingWidth
                        height: island.normalHeight

                        Text {
                            id: normalTime
                            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: "white"
                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }

                        Item {
                            anchors { left: normalTime.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: island.batteryCharging ? 48 : 36
                            height: 18
                            visible: island.battery && island.battery.ready

                            Rectangle {
                                id: normalBatteryBody
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: 30
                                height: 15
                                radius: 3.5
                                color: "transparent"
                                border.width: 1
                                border.color: island.batteryShellColor
                                Behavior on border.color { ColorAnimation { duration: 180 } }

                                Rectangle {
                                    anchors { left: parent.left; leftMargin: 3; top: parent.top; topMargin: 3; bottom: parent.bottom; bottomMargin: 3 }
                                    width: Math.max(0, (normalBatteryBody.width - 6) * island.batteryLevel)
                                    radius: 1.7
                                    color: island.batteryColor
                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            Rectangle {
                                anchors { left: normalBatteryBody.right; leftMargin: 1; verticalCenter: parent.verticalCenter }
                                width: 3
                                height: 7
                                radius: 1.5
                                color: island.batteryShellColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 13 }
                        text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                        color: "#b8b8bd"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- MUSIC ----------
                Item {
                    id: musicMode
                    property bool active: island.displayMode === "music" && island.musicSessionAvailable && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.972
                    visible: opacity > 0.01
                    enabled: active
                    transformOrigin: Item.Top
                    Behavior on opacity { NumberAnimation { duration: 115; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 165; easing.type: Easing.OutBack; easing.overshoot: 0.32 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 12 }
                        spacing: 17

                        Text {
                            text: "‹"
                            color: island.activePlayer && island.activePlayer.canGoPrevious ? "white" : "#55555a"
                            font.pixelSize: 25
                            MouseArea { anchors.fill: parent; enabled: island.activePlayer && island.activePlayer.canGoPrevious; onClicked: island.activePlayer.previous() }
                        }
                        Text {
                            text: island.musicPlaying ? "Ⅱ" : "▶"
                            color: island.activePlayer && island.activePlayer.canTogglePlaying ? "white" : "#55555a"
                            font.pixelSize: island.musicPlaying ? 16 : 15
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; enabled: island.activePlayer && island.activePlayer.canTogglePlaying; onClicked: island.activePlayer.togglePlaying() }
                        }
                        Text {
                            text: "›"
                            color: island.activePlayer && island.activePlayer.canGoNext ? "white" : "#55555a"
                            font.pixelSize: 25
                            MouseArea { anchors.fill: parent; enabled: island.activePlayer && island.activePlayer.canGoNext; onClicked: island.activePlayer.next() }
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 17 }
                        text: island.musicPlaying
                            ? island.formatTime(island.musicPosition) + " / " + island.formatTime(island.musicLength)
                            : "Paused · " + island.formatTime(island.musicPosition) + " / " + island.formatTime(island.musicLength)
                        color: island.musicPlaying ? "#8e8e93" : "#b8b8bd"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item {
                        id: albumArt
                        anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 52 }
                        width: 68
                        height: 68

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "#1c1c1e"
                            Text { anchors.centerIn: parent; visible: artImage.status !== Image.Ready; text: "♪"; color: "#636366"; font.pixelSize: 25 }
                        }
                        Image {
                            id: artImage
                            anchors.fill: parent
                            anchors.margins: 2
                            source: island.musicArtSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            sourceSize.width: 160
                            sourceSize.height: 160
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.width: 3; border.color: "#000000" }
                    }

                    Item {
                        anchors { left: albumArt.right; leftMargin: 15; right: parent.right; rightMargin: 24; top: parent.top; topMargin: 53 }
                        height: 67
                        Text {
                            id: musicTitleText
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            text: island.musicTitle
                            color: "#f5f5f7"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; top: musicTitleText.bottom; topMargin: 3 }
                            text: island.musicArtist
                            color: "#8e8e93"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
                            height: 4
                            radius: 2
                            color: "#2c2c2e"
                            Rectangle {
                                width: parent.width * island.musicProgress
                                height: parent.height
                                radius: parent.radius
                                color: "#f2f2f7"
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.Linear } }
                            }
                        }
                    }
                }

                // ---------- CONNECTIVITY SUMMARY ----------
                Item {
                    id: connectivityMode
                    property bool active: island.displayMode === "connectivity" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    enabled: active
                    transformOrigin: Item.Top
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 185; easing.type: Easing.OutBack; easing.overshoot: 0.4 } }

                    Item {
                        anchors { left: parent.left; top: parent.top }
                        width: island.wingWidth
                        height: island.normalHeight
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                            width: 7; height: 7; radius: 3.5
                            color: island.wifiEnabled ? "#30d158" : "#636366"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 39; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: island.wifiSsid !== "" ? island.wifiSsid : "Wi-Fi"
                            color: "#e8e8ed"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: island.openConnectivityPanel("wifi")
                        }
                    }

                    Item {
                        anchors { right: parent.right; top: parent.top }
                        width: island.wingWidth
                        height: island.normalHeight
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                            width: 7; height: 7; radius: 3.5
                            color: island.bluetoothPowered ? "#30d158" : "#636366"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 39; verticalCenter: parent.verticalCenter }
                            text: island.bluetoothDevice !== "" ? island.bluetoothDevice : "Bluetooth"
                            color: "#e8e8ed"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: island.openConnectivityPanel("bluetooth")
                        }
                    }
                }

                // ---------- EXPANDED WI-FI / BLUETOOTH ----------
                ConnectivityPanel {
                    id: connectivityDetails
                    anchors.fill: parent
                    active: (island.displayMode === "wifiPanel" || island.displayMode === "bluetoothPanel") && island.expanded
                    panelType: island.selectedMode === "bluetoothPanel" ? "bluetooth" : "wifi"
                    wifiEnabled: island.wifiEnabled
                    bluetoothPowered: island.bluetoothPowered
                    onBackRequested: island.selectedMode = "connectivity"
                    onStatusRefreshRequested: {
                        if (!wifiProbe.running) wifiProbe.running = true
                        if (!bluetoothProbe.running) bluetoothProbe.running = true
                    }
                }

                // ---------- VOLUME ----------
                Item {
                    id: volumeMode
                    property bool active: island.displayMode === "volume" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    enabled: active
                    Behavior on opacity { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 145; easing.type: Easing.OutBack; easing.overshoot: 0.28 } }

                    Text { anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 15 }; text: island.volumeMuted ? "Muted" : "Volume"; color: "white"; font.pixelSize: 15; font.weight: Font.Medium }
                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
                        width: 104; height: 4; radius: 2; color: "#343438"
                        Rectangle {
                            width: parent.width * (island.volumeMuted ? 0 : island.volumePercent / 100)
                            height: parent.height; radius: parent.radius; color: "#f2f2f7"
                            Behavior on width { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text { anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 13 }; text: island.volumeMuted ? "—" : island.volumePercent; color: "#e8e8ed"; font.pixelSize: 17; font.weight: Font.Medium }
                }

                // ---------- BRIGHTNESS ----------
                Item {
                    id: brightnessMode
                    property bool active: island.displayMode === "brightness" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    enabled: active
                    Behavior on opacity { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 145; easing.type: Easing.OutBack; easing.overshoot: 0.28 } }

                    Text { anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 13 }; text: "☀"; color: "white"; font.pixelSize: 18 }
                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
                        width: 112; height: 4; radius: 2; color: "#343438"
                        Rectangle {
                            width: parent.width * (island.brightnessPercent / 100)
                            height: parent.height; radius: parent.radius; color: "#f2f2f7"
                            Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text { anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 13 }; text: island.brightnessPercent; color: "#e8e8ed"; font.pixelSize: 17; font.weight: Font.Medium }
                }

                // ---------- BATTERY POPUP ----------
                Item {
                    id: batteryMode
                    property bool active: island.displayMode === "battery" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                    Text {
                        anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 14 }
                        text: island.batteryEventText
                        color: island.batteryCharging ? "#30d158" : island.batteryLevel <= 0.20 ? "#ff453a" : "#e8e8ed"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 13 }
                        text: Math.round(island.batteryLevel * 100) + "%"
                        color: island.batteryColor
                        font.pixelSize: 17
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }

                // ---------- BLUETOOTH EVENT ----------
                Item {
                    id: bluetoothMode
                    property bool active: island.displayMode === "bluetooth" && island.expanded
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    scale: active ? 1 : 0.985
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                    Text { anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 15 }; text: "Bluetooth"; color: "#e8e8ed"; font.pixelSize: 15; font.weight: Font.Medium }
                    Text {
                        anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 15 }
                        width: island.wingWidth - 30
                        text: island.bluetoothEventText
                        color: "white"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }
            }

            // Apple-like spring motion. Large downward cards move faster.
            Behavior on width {
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
