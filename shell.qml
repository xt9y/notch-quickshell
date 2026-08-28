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

        // Keep enough layer-surface space for the double-height music view,
        // but reserve only the normal notch height so opening Music overlays
        // the desktop instead of pushing windows downward.
        implicitHeight: 96
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 49

        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Item {
            id: island

            property int notchWidth: 170
            property int collapsedVisualHeight: 44
            property int normalHeight: 48
            property int musicHeight: 96
            property int cornerRadius: 13

            property string selectedMode: "normal"
            property string transientMode: ""
            property string displayMode: transientMode !== "" ? transientMode : selectedMode

            // Battery / charger state.
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
                : batteryLevel <= 0.15
                    ? "#ff453a"
                    : batteryLevel <= 0.30
                        ? "#ffd60a"
                        : "#f2f2f7"
            property int lastBatteryState: -1
            property string batteryEventText: "Battery"

            // Only expose the media page while something is actively playing.
            property var activePlayer: {
                var players = Mpris.players.values
                for (var i = 0; i < players.length; ++i) {
                    if (players[i].isPlaying)
                        return players[i]
                }
                return null
            }
            property bool musicPlaying: activePlayer !== null && activePlayer.isPlaying
            property string musicTitle: activePlayer
                ? (activePlayer.trackTitle || activePlayer.identity || "Now Playing")
                : ""
            property string musicArtist: activePlayer
                ? (activePlayer.trackArtist || activePlayer.trackAlbumArtist || "")
                : ""
            property string musicArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
            property real musicPosition: 0
            property real musicLength: activePlayer && activePlayer.lengthSupported
                ? Math.max(0, activePlayer.length)
                : 0
            property real musicProgress: musicLength > 0
                ? Math.max(0, Math.min(1, musicPosition / musicLength))
                : 0

            // Read-only volume and brightness observation.
            property int volumePercent: 0
            property bool volumeMuted: false
            property int lastVolumePercent: -1
            property bool lastVolumeMuted: false
            property int brightnessPercent: 0
            property int lastBrightnessPercent: -1

            // Connectivity.
            property bool wifiAvailable: false
            property bool wifiEnabled: false
            property string wifiSsid: ""
            property bool bluetoothAvailable: false
            property bool bluetoothPowered: false
            property string bluetoothDevice: ""
            property string lastBluetoothDevice: ""
            property bool bluetoothInitialized: false
            property string bluetoothEventText: "Bluetooth"

            property bool expanded: hover.hovered || transientMode !== ""

            function modeWidth(mode) {
                if (mode === "music")
                    return 520
                if (mode === "connectivity")
                    return 450
                if (mode === "volume" || mode === "brightness")
                    return 410
                if (mode === "battery")
                    return 360
                if (mode === "bluetooth")
                    return 460
                return 540
            }

            function modeHeight(mode) {
                return mode === "music" ? musicHeight : normalHeight
            }

            property real targetWidth: expanded ? modeWidth(displayMode) : notchWidth
            property real targetHeight: expanded ? modeHeight(displayMode) : collapsedVisualHeight
            property real wingWidth: (width - notchWidth) / 2

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            width: targetWidth
            height: targetHeight

            // If playback stops while Music is open, immediately return to the
            // clock page. A stopped/paused player is never shown as a Music page.
            onMusicPlayingChanged: {
                if (!musicPlaying && selectedMode === "music")
                    selectedMode = "normal"
            }

            function showTransient(mode) {
                transientMode = mode
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

            function formatTime(seconds) {
                if (!isFinite(seconds) || seconds < 0)
                    seconds = 0
                var total = Math.floor(seconds)
                var mins = Math.floor(total / 60)
                var secs = total % 60
                return mins + ":" + (secs < 10 ? "0" : "") + secs
            }

            function consumeVolume(raw) {
                var match = raw.match(/Volume:\s*([0-9.]+)/)
                if (!match)
                    return

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
                    showTransient("volume")
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
                    showTransient("brightness")
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
                    if (bluetoothDevice !== "") {
                        bluetoothEventText = bluetoothDevice
                        showTransient("bluetooth")
                    } else if (lastBluetoothDevice !== "") {
                        bluetoothEventText = lastBluetoothDevice + " disconnected"
                        showTransient("bluetooth")
                    }
                    lastBluetoothDevice = bluetoothDevice
                }
            }

            function checkBatteryState() {
                if (!battery || !battery.ready)
                    return

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
                    showTransient("battery")
                } else if (!isCharging && wasCharging) {
                    batteryEventText = "On Battery"
                    showTransient("battery")
                }

                lastBatteryState = state
            }

            HoverHandler {
                id: hover

                // Every fresh hover starts from the date/time page, regardless
                // of which page was last clicked during the previous hover.
                onHoveredChanged: {
                    if (!hovered && island.transientMode === "")
                        island.resetToNormal()
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: island.cycleMode()
            }

            Timer {
                id: transientTimer
                interval: 1700
                repeat: false
                onTriggered: {
                    island.transientMode = ""
                    if (!hover.hovered)
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

            // MPRIS position is intentionally sampled while a track is playing;
            // the property itself is not guaranteed to emit updates continuously.
            Timer {
                interval: 250
                repeat: true
                running: island.musicPlaying
                triggeredOnStart: true
                onTriggered: {
                    if (island.activePlayer && island.activePlayer.positionSupported)
                        island.musicPosition = Math.max(0, island.activePlayer.position)
                    else
                        island.musicPosition = 0
                }
            }

            Timer {
                interval: 500
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: if (!volumeProbe.running) volumeProbe.running = true
            }

            Process {
                id: volumeProbe
                command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeVolume(text)
                }
            }

            Timer {
                interval: 600
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: if (!brightnessProbe.running) brightnessProbe.running = true
            }

            Process {
                id: brightnessProbe
                command: [
                    "bash", "-lc",
                    "cur=$(brightnessctl g 2>/dev/null) || exit 0; max=$(brightnessctl m 2>/dev/null) || exit 0; [ \"$max\" -gt 0 ] && echo $((cur * 100 / max))"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeBrightness(text)
                }
            }

            Timer {
                interval: 2200
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
                    "command -v nmcli >/dev/null 2>&1 || exit 0; nmcli -t -f WIFI g 2>/dev/null; nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -n1"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeWifi(text)
                }
            }

            Process {
                id: bluetoothProbe
                command: [
                    "bash", "-lc",
                    "command -v bluetoothctl >/dev/null 2>&1 || exit 0; bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'; bluetoothctl devices Connected 2>/dev/null | sed -n '1s/^Device [^ ]* //p'"
                ]
                stdout: StdioCollector {
                    onStreamFinished: island.consumeBluetooth(text)
                }
            }

            Process {
                id: wifiToggle
                onRunningChanged: if (!running && !wifiProbe.running) wifiProbe.running = true
            }

            Process {
                id: bluetoothToggle
                onRunningChanged: if (!running && !bluetoothProbe.running) bluetoothProbe.running = true
            }

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

                // Tiny music affordance is only visible while audio is actually
                // playing, never merely because a paused MPRIS player exists.
                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 19
                        verticalCenter: parent.verticalCenter
                    }
                    visible: island.musicPlaying && !island.expanded
                    text: "♪"
                    color: "#c7c7cc"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                // ---------- NORMAL ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "normal" && island.expanded

                    Item {
                        id: normalLeft
                        anchors {
                            left: parent.left
                            top: parent.top
                        }
                        width: island.wingWidth
                        height: island.normalHeight

                        Text {
                            id: normalTime
                            anchors {
                                left: parent.left
                                leftMargin: 24
                                verticalCenter: parent.verticalCenter
                            }
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: "white"
                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }

                        Item {
                            anchors {
                                left: normalTime.right
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            width: island.batteryCharging ? 48 : 36
                            height: 18
                            visible: island.battery && island.battery.ready

                            Rectangle {
                                id: normalBatteryBody
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 30
                                height: 15
                                radius: 3.5
                                color: "transparent"
                                border.width: 1
                                border.color: "#d1d1d6"

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        leftMargin: 3
                                        top: parent.top
                                        topMargin: 3
                                        bottom: parent.bottom
                                        bottomMargin: 3
                                    }
                                    width: Math.max(0, (normalBatteryBody.width - 6) * island.batteryLevel)
                                    radius: 1.7
                                    color: island.batteryColor
                                }
                            }

                            Rectangle {
                                anchors {
                                    left: normalBatteryBody.right
                                    leftMargin: 1
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 3
                                height: 7
                                radius: 1.5
                                color: "#d1d1d6"
                            }
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: (island.normalHeight - implicitHeight) / 2
                        }
                        text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                        color: "#b8b8bd"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- MUSIC / MEDIAMATE STYLE ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "music" && island.musicPlaying && island.expanded

                    // Top row stays aligned with the normal 48px notch.
                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            top: parent.top
                            topMargin: 12
                        }
                        spacing: 17

                        Text {
                            text: "‹"
                            color: island.activePlayer && island.activePlayer.canGoPrevious ? "white" : "#55555a"
                            font.pixelSize: 25
                            MouseArea {
                                anchors.fill: parent
                                enabled: island.activePlayer && island.activePlayer.canGoPrevious
                                onClicked: island.activePlayer.previous()
                            }
                        }

                        Text {
                            text: island.musicPlaying ? "Ⅱ" : "▶"
                            color: island.activePlayer && island.activePlayer.canTogglePlaying ? "white" : "#55555a"
                            font.pixelSize: island.musicPlaying ? 16 : 15
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                enabled: island.activePlayer && island.activePlayer.canTogglePlaying
                                onClicked: island.activePlayer.togglePlaying()
                            }
                        }

                        Text {
                            text: "›"
                            color: island.activePlayer && island.activePlayer.canGoNext ? "white" : "#55555a"
                            font.pixelSize: 25
                            MouseArea {
                                anchors.fill: parent
                                enabled: island.activePlayer && island.activePlayer.canGoNext
                                onClicked: island.activePlayer.next()
                            }
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: 17
                        }
                        text: island.formatTime(island.musicPosition) + " / " + island.formatTime(island.musicLength)
                        color: "#8e8e93"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    // Rounded album art. The Canvas clips the source to an exact
                    // rounded path without adding a Qt graphical-effects dependency.
                    Item {
                        id: albumArt
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            bottom: parent.bottom
                            bottomMargin: 8
                        }
                        width: 52
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: "#1c1c1e"

                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: "#636366"
                                font.pixelSize: 22
                            }
                        }

                        Canvas {
                            id: albumCanvas
                            anchors.fill: parent
                            property string sourceUrl: island.musicArtUrl

                            onSourceUrlChanged: {
                                if (sourceUrl !== "")
                                    loadImage(sourceUrl)
                                requestPaint()
                            }

                            onImageLoaded: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (sourceUrl === "" || !isImageLoaded(sourceUrl))
                                    return

                                var r = 10
                                ctx.save()
                                ctx.beginPath()
                                ctx.moveTo(r, 0)
                                ctx.lineTo(width - r, 0)
                                ctx.quadraticCurveTo(width, 0, width, r)
                                ctx.lineTo(width, height - r)
                                ctx.quadraticCurveTo(width, height, width - r, height)
                                ctx.lineTo(r, height)
                                ctx.quadraticCurveTo(0, height, 0, height - r)
                                ctx.lineTo(0, r)
                                ctx.quadraticCurveTo(0, 0, r, 0)
                                ctx.closePath()
                                ctx.clip()
                                ctx.drawImage(sourceUrl, 0, 0, width, height)
                                ctx.restore()
                            }
                        }
                    }

                    Item {
                        anchors {
                            left: albumArt.right
                            leftMargin: 14
                            right: parent.right
                            rightMargin: 24
                            bottom: parent.bottom
                            bottomMargin: 8
                        }
                        height: 52

                        Text {
                            id: musicTitleText
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            text: island.musicTitle
                            color: "#f5f5f7"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: musicTitleText.bottom
                                topMargin: 2
                            }
                            text: island.musicArtist
                            color: "#8e8e93"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                bottomMargin: 3
                            }
                            height: 4
                            radius: 2
                            color: "#2c2c2e"

                            Rectangle {
                                width: parent.width * island.musicProgress
                                height: parent.height
                                radius: parent.radius
                                color: "#f2f2f7"
                            }
                        }
                    }
                }

                // ---------- CONNECTIVITY ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "connectivity" && island.expanded

                    Item {
                        anchors {
                            left: parent.left
                            top: parent.top
                        }
                        width: island.wingWidth
                        height: island.normalHeight

                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: 24
                                verticalCenter: parent.verticalCenter
                            }
                            width: 7
                            height: 7
                            radius: 3.5
                            color: island.wifiEnabled ? "#30d158" : "#636366"
                        }

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 39
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            text: island.wifiSsid !== "" ? island.wifiSsid : "Wi-Fi"
                            color: "#e8e8ed"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: island.wifiAvailable && !wifiToggle.running
                            onClicked: {
                                wifiToggle.command = ["nmcli", "radio", "wifi", island.wifiEnabled ? "off" : "on"]
                                wifiToggle.running = true
                            }
                        }
                    }

                    Item {
                        anchors {
                            right: parent.right
                            top: parent.top
                        }
                        width: island.wingWidth
                        height: island.normalHeight

                        Rectangle {
                            anchors {
                                right: parent.right
                                rightMargin: 24
                                verticalCenter: parent.verticalCenter
                            }
                            width: 7
                            height: 7
                            radius: 3.5
                            color: island.bluetoothPowered ? "#30d158" : "#636366"
                        }

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 12
                                right: parent.right
                                rightMargin: 39
                                verticalCenter: parent.verticalCenter
                            }
                            text: island.bluetoothDevice !== "" ? island.bluetoothDevice : "Bluetooth"
                            color: "#e8e8ed"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: island.bluetoothAvailable && !bluetoothToggle.running
                            onClicked: {
                                bluetoothToggle.command = ["bluetoothctl", "power", island.bluetoothPowered ? "off" : "on"]
                                bluetoothToggle.running = true
                            }
                        }
                    }
                }

                // ---------- TEMPORARY VOLUME ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "volume" && island.expanded

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            top: parent.top
                            topMargin: 15
                        }
                        text: island.volumeMuted ? "Muted" : "Volume"
                        color: "white"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: 22
                        }
                        width: 104
                        height: 4
                        radius: 2
                        color: "#343438"

                        Rectangle {
                            width: parent.width * (island.volumeMuted ? 0 : island.volumePercent / 100)
                            height: parent.height
                            radius: parent.radius
                            color: "#f2f2f7"
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: 13
                        }
                        text: island.volumeMuted ? "—" : island.volumePercent + "%"
                        color: "#e8e8ed"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- TEMPORARY BRIGHTNESS ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "brightness" && island.expanded

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            top: parent.top
                            topMargin: 13
                        }
                        text: "☀"
                        color: "white"
                        font.pixelSize: 18
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: parent.top
                            topMargin: 22
                        }
                        width: 112
                        height: 4
                        radius: 2
                        color: "#343438"

                        Rectangle {
                            width: parent.width * (island.brightnessPercent / 100)
                            height: parent.height
                            radius: parent.radius
                            color: "#f2f2f7"
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: 13
                        }
                        text: island.brightnessPercent + "%"
                        color: "#e8e8ed"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- TEMPORARY BATTERY ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "battery" && island.expanded

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            top: parent.top
                            topMargin: 14
                        }
                        text: island.batteryEventText
                        color: island.batteryCharging ? "#30d158" : "#e8e8ed"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: 13
                        }
                        text: Math.round(island.batteryLevel * 100) + "%"
                        color: island.batteryColor
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- TEMPORARY BLUETOOTH ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "bluetooth" && island.expanded

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            top: parent.top
                            topMargin: 15
                        }
                        text: "Bluetooth"
                        color: "#e8e8ed"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            top: parent.top
                            topMargin: 15
                        }
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

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.10
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
