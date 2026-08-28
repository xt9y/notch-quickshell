import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool bluetoothInitialized: false
    property bool bluetoothConnected: false

    width: 0
    height: 0
    visible: false

    function scheduleRepair(delay) {
        repairTimer.interval = delay === undefined ? 650 : delay
        repairTimer.restart()
    }

    function consumeBluetooth(raw) {
        var connected = raw.trim() === "yes"

        if (!bluetoothInitialized) {
            bluetoothInitialized = true
            bluetoothConnected = connected
            return
        }

        var wasConnected = bluetoothConnected
        bluetoothConnected = connected
        if (wasConnected && !connected)
            scheduleRepair(500)
    }

    Component.onCompleted: startupRepair.restart()

    Timer {
        id: startupRepair
        interval: 2400
        repeat: false
        onTriggered: root.scheduleRepair(0)
    }

    Timer {
        interval: 700
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!bluetoothProbe.running)
                bluetoothProbe.running = true
        }
    }

    Process {
        id: bluetoothProbe
        command: [
            "bash",
            "-lc",
            "if command -v bluetoothctl >/dev/null 2>&1 && bluetoothctl devices Connected 2>/dev/null | grep -q '^Device '; then printf 'yes'; else printf 'no'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.consumeBluetooth(text)
        }
    }

    Timer {
        id: repairTimer
        interval: 650
        repeat: false
        onTriggered: {
            if (!repairProcess.running)
                repairProcess.running = true
        }
    }

    Process {
        id: repairProcess
        command: [
            "bash",
            "-lc",
            "command -v wpctl >/dev/null 2>&1 || exit 0; " +
            "if command -v bluetoothctl >/dev/null 2>&1 && bluetoothctl devices Connected 2>/dev/null | grep -q '^Device '; then exit 0; fi; " +
            "info=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null || true); " +
            "current=$(printf '%s\\n' \"$info\" | sed -n '1s/^id \\([0-9][0-9]*\\),.*/\\1/p'); " +
            "if [ -n \"$current\" ] && ! printf '%s\\n' \"$info\" | grep -Eiq 'bluez|bluetooth'; then " +
            "wpctl set-default \"$current\" >/dev/null 2>&1 || true; exit 0; fi; " +
            "fallback=$(wpctl status -n 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -viE 'bluez|bluetooth|dummy|auto_null' | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "if [ -n \"$fallback\" ]; then wpctl set-default \"$fallback\" >/dev/null 2>&1 || true; fi"
        ]
    }
}
