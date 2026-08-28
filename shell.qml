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
        implicitHeight: 48
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
            property int notchHeight: 48
            property int collapsedVisualHeight: 44
            property int expandedWidth: 540
            property int cornerRadius: 13

            property string selectedMode: "normal"
            property string transientMode: ""
            property string displayMode: transientMode !== "" ? transientMode : selectedMode

            property bool expanded: hover.hovered || transientMode !== ""
            property real wingWidth: (width - notchWidth) / 2
            property real visualHeight: expanded ? notchHeight : collapsedVisualHeight

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

            // Media.
            property var activePlayer: {
                var players = Mpris.players.values
                for (var i = 0; i < players.length; ++i) {
                    if (players[i].isPlaying)
                        return players[i]
                }
                return players.length > 0 ? players[0] : null
            }
            property bool musicAvailable: activePlayer !== null &&
                (activePlayer.trackTitle !== "" || activePlayer.canControl)
            property bool musicPlaying: activePlayer !== null && activePlayer.isPlaying
            property string musicText: {
                if (!activePlayer)
                    return "No media"
                var title = activePlayer.trackTitle || activePlayer.identity || "Media"
                var artist = activePlayer.trackArtist || ""
                return artist !== "" ? title + " — " + artist : title
            }

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

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            width: expanded ? expandedWidth : notchWidth
            height: notchHeight

            function showTransient(mode) {
                transientMode = mode
                transientTimer.restart()
            }

            function cycleMode() {
                if (selectedMode === "normal")
                    selectedMode = "music"
                else if (selectedMode === "music")
                    selectedMode = "connectivity"
                else
                    selectedMode = "normal"
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
            }

            // Base click cycles Normal -> Music -> Connectivity.
            MouseArea {
                anchors.fill: parent
                onClicked: island.cycleMode()
            }

            Timer {
                id: transientTimer
                interval: 1700
                repeat: false
                onTriggered: island.transientMode = ""
            }

            Timer {
                interval: 750
                repeat: true
                running: true
                triggeredOnStart: true
                onTriggered: island.checkBatteryState()
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

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: island.visualHeight
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

            // All UI content lives in this one shared coordinate system.
            // Centering against this Item is stable across all modes and avoids
            // QtQuick Shape anchor-line quirks.
            Item {
                id: content
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: island.visualHeight

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 19
                        verticalCenter: parent.verticalCenter
                    }
                    visible: island.musicAvailable && !island.expanded
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
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth
                        height: parent.height

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
                            verticalCenter: parent.verticalCenter
                        }
                        text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                        color: "#b8b8bd"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                }

                // ---------- MUSIC ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "music" && island.expanded

                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 16

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
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth - 34
                        text: island.musicText
                        color: island.musicAvailable ? "#e8e8ed" : "#77777c"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // ---------- CONNECTIVITY ----------
                Item {
                    anchors.fill: parent
                    visible: island.displayMode === "connectivity" && island.expanded

                    Item {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth
                        height: parent.height

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
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth
                        height: parent.height

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

                    Item {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth
                        height: parent.height

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 24
                                verticalCenter: parent.verticalCenter
                            }
                            text: island.volumeMuted ? "Muted" : "Volume"
                            color: "white"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            width: 76
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
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            verticalCenter: parent.verticalCenter
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

                    Item {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth
                        height: parent.height

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 24
                                verticalCenter: parent.verticalCenter
                            }
                            text: "☀"
                            color: "white"
                            font.pixelSize: 18
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            width: 105
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
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 24
                            verticalCenter: parent.verticalCenter
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
                            verticalCenter: parent.verticalCenter
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
                            verticalCenter: parent.verticalCenter
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
                            verticalCenter: parent.verticalCenter
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
                            verticalCenter: parent.verticalCenter
                        }
                        width: island.wingWidth - 30
                        text: island.bluetoothEventText
                        color: "white"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }

            Behavior on visualHeight {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
