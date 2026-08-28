import QtQuick
import Quickshell.Io

Item {
    id: root

    property string bluetoothDevice: ""
    property string lastBluetoothDevice: ""
    property bool initialized: false

    width: 0
    height: 0
    visible: false

    function scheduleRepair(delay) {
        repairTimer.interval = delay || 700
        repairTimer.restart()
    }

    onBluetoothDeviceChanged: {
        if (!initialized) {
            initialized = true
            lastBluetoothDevice = bluetoothDevice
            return
        }

        var disconnected = lastBluetoothDevice !== "" && bluetoothDevice === ""
        lastBluetoothDevice = bluetoothDevice
        if (disconnected)
            scheduleRepair(650)
    }

    Component.onCompleted: startupRepair.restart()

    Timer {
        id: startupRepair
        interval: 2600
        repeat: false
        onTriggered: root.scheduleRepair(0)
    }

    Timer {
        id: repairTimer
        interval: 700
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
            "[ -n \"$fallback\" ] && wpctl set-default \"$fallback\" >/dev/null 2>&1 || true"
        ]
    }
}
