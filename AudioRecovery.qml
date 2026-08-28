import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool initialized: false
    property bool bluetoothPowered: false
    property bool bluetoothAudioConnected: false
    property string connectedAddress: ""
    property string connectedName: ""
    property double reconnectBlockedUntil: 0

    width: 0
    height: 0
    visible: false

    function consumeState(raw) {
        var lines = raw.trim().split("\n")
        var powered = lines.length > 0 && lines[0] === "yes"
        var address = lines.length > 1 ? lines[1].trim() : ""
        var name = lines.length > 2 ? lines.slice(2).join(" ").trim() : ""
        var connected = powered && address !== ""

        if (!initialized) {
            initialized = true
            bluetoothPowered = powered
            bluetoothAudioConnected = connected
            connectedAddress = address
            connectedName = name

            if (connected)
                routeTimer.restart()
            else
                fallbackTimer.restart()
            return
        }

        var wasPowered = bluetoothPowered
        var wasConnected = bluetoothAudioConnected
        var oldAddress = connectedAddress

        bluetoothPowered = powered
        bluetoothAudioConnected = connected
        connectedAddress = address
        connectedName = name

        // Turning Bluetooth back on is an explicit request to make paired
        // devices usable again, so do not retain an old reconnect cooldown.
        if (!wasPowered && powered)
            reconnectBlockedUntil = 0

        if (connected) {
            // Route whenever a Bluetooth audio device appears or changes.
            if (!wasConnected || address !== oldAddress)
                routeTimer.restart()
        } else if (wasConnected) {
            // Give a deliberate/manual disconnect time to settle instead of
            // immediately fighting it with the auto-connect loop. BlueZ can
            // still accept a device-initiated reconnect during this window.
            reconnectBlockedUntil = Date.now() + 30000
            fallbackTimer.restart()
        }
    }

    Timer {
        interval: 900
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!stateProbe.running)
                stateProbe.running = true
        }
    }

    Process {
        id: stateProbe
        command: [
            "bash",
            "-lc",
            "command -v bluetoothctl >/dev/null 2>&1 || { printf 'no\\n'; exit 0; }; " +
            "powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'); " +
            "[ \"$powered\" = yes ] || { printf 'no\\n'; exit 0; }; " +
            "printf 'yes\\n'; " +
            "bluetoothctl devices Connected 2>/dev/null | while read -r tag addr rest; do " +
            "[ \"$tag\" = Device ] || continue; " +
            "info=$(bluetoothctl info \"$addr\" 2>/dev/null); " +
            "printf '%s\\n' \"$info\" | grep -Eiq 'UUID:.*(Audio Sink|Headset|Handsfree|Headset HS|Advanced Audio)' || continue; " +
            "alias=$(printf '%s\\n' \"$info\" | sed -n 's/^[[:space:]]*Alias: //p' | head -n1); " +
            "name=$(printf '%s\\n' \"$info\" | sed -n 's/^[[:space:]]*Name: //p' | head -n1); " +
            "printf '%s\\n%s\\n' \"$addr\" \"${alias:-$name}\"; break; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.consumeState(text)
        }
    }

    // A trusted, previously-paired Bluetooth audio device should behave like a
    // normal laptop headset: opening/wearing it is enough. Failed connect
    // attempts are harmless while it is in the case or out of range.
    Timer {
        interval: 6000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() >= root.reconnectBlockedUntil && !autoConnect.running)
                autoConnect.running = true
        }
    }

    Process {
        id: autoConnect
        command: [
            "bash",
            "-lc",
            "command -v bluetoothctl >/dev/null 2>&1 || exit 0; " +
            "powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'); " +
            "[ \"$powered\" = yes ] || exit 0; " +
            "bluetoothctl devices Paired 2>/dev/null | while read -r tag addr rest; do " +
            "[ \"$tag\" = Device ] || continue; " +
            "info=$(bluetoothctl info \"$addr\" 2>/dev/null); " +
            "printf '%s\\n' \"$info\" | grep -Eiq 'UUID:.*(Audio Sink|Headset|Handsfree|Headset HS|Advanced Audio)' || continue; " +
            "paired=$(printf '%s\\n' \"$info\" | awk '/Paired:/ {print $2; exit}'); " +
            "[ \"$paired\" = yes ] || continue; " +
            "trusted=$(printf '%s\\n' \"$info\" | awk '/Trusted:/ {print $2; exit}'); " +
            "[ \"$trusted\" = yes ] || bluetoothctl trust \"$addr\" >/dev/null 2>&1 || true; " +
            "connected=$(printf '%s\\n' \"$info\" | awk '/Connected:/ {print $2; exit}'); " +
            "[ \"$connected\" = yes ] && exit 0; " +
            "if command -v timeout >/dev/null 2>&1; then timeout 5 bluetoothctl connect \"$addr\" >/dev/null 2>&1 && exit 0; " +
            "else bluetoothctl connect \"$addr\" >/dev/null 2>&1 && exit 0; fi; done"
        ]
    }

    Timer {
        id: routeTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (routeProcess.running || root.connectedAddress === "")
                return
            routeProcess.environment = ({
                BT_ADDR: root.connectedAddress,
                BT_NAME: root.connectedName
            })
            routeProcess.running = true
        }
    }

    Process {
        id: routeProcess
        command: [
            "bash",
            "-lc",
            "command -v wpctl >/dev/null 2>&1 || exit 0; " +
            "addr=\"${BT_ADDR:-}\"; name=\"${BT_NAME:-}\"; key=$(printf '%s' \"$addr\" | tr ':' '_'); " +
            "get_id() { sed -n \"/$1:/,/$2:/p\" | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1; }; " +
            "for attempt in 1 2 3 4 5 6; do " +
            "plain=$(wpctl status -n 2>/dev/null || true); pretty=$(wpctl status 2>/dev/null || true); " +
            "sink=''; source=''; " +
            "if [ -n \"$key\" ]; then " +
            "sink=$(printf '%s\\n' \"$plain\" | sed -n '/Sinks:/,/Sources:/p' | grep -i \"$key\" | get_id Sinks Sources); " +
            "source=$(printf '%s\\n' \"$plain\" | sed -n '/Sources:/,/Filters:/p' | grep -i \"$key\" | get_id Sources Filters); fi; " +
            "if [ -z \"$sink\" ] && [ -n \"$name\" ]; then sink=$(printf '%s\\n' \"$pretty\" | sed -n '/Sinks:/,/Sources:/p' | grep -Fi \"$name\" | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); fi; " +
            "if [ -z \"$source\" ] && [ -n \"$name\" ]; then source=$(printf '%s\\n' \"$pretty\" | sed -n '/Sources:/,/Filters:/p' | grep -Fi \"$name\" | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); fi; " +
            "[ -n \"$sink\" ] || sink=$(printf '%s\\n' \"$plain\" | sed -n '/Sinks:/,/Sources:/p' | grep -i bluez | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "[ -n \"$source\" ] || source=$(printf '%s\\n' \"$plain\" | sed -n '/Sources:/,/Filters:/p' | grep -i bluez | grep -vi monitor | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "[ -n \"$sink\" ] && wpctl set-default \"$sink\" >/dev/null 2>&1 || true; " +
            "[ -n \"$source\" ] && wpctl set-default \"$source\" >/dev/null 2>&1 || true; " +
            "[ -n \"$sink\" ] && exit 0; sleep 0.35; done"
        ]
        onRunningChanged: if (!running)
            environment = ({})
    }

    Timer {
        id: fallbackTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!fallbackProcess.running)
                fallbackProcess.running = true
        }
    }

    Process {
        id: fallbackProcess
        command: [
            "bash",
            "-lc",
            "command -v wpctl >/dev/null 2>&1 || exit 0; " +
            "for attempt in 1 2 3 4; do " +
            "status=$(wpctl status -n 2>/dev/null || true); " +
            "sinks=$(printf '%s\\n' \"$status\" | sed -n '/Sinks:/,/Sources:/p' | grep -viE 'bluez|bluetooth|dummy|auto_null'); " +
            "sources=$(printf '%s\\n' \"$status\" | sed -n '/Sources:/,/Filters:/p' | grep -viE 'bluez|bluetooth|dummy|auto_null|monitor'); " +
            "sink=$(printf '%s\\n' \"$sinks\" | grep -F '*' | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "[ -n \"$sink\" ] || sink=$(printf '%s\\n' \"$sinks\" | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "source=$(printf '%s\\n' \"$sources\" | grep -F '*' | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "[ -n \"$source\" ] || source=$(printf '%s\\n' \"$sources\" | sed -n 's/^[^0-9]*\\([0-9][0-9]*\\)\\..*/\\1/p' | head -n1); " +
            "[ -n \"$sink\" ] && wpctl set-default \"$sink\" >/dev/null 2>&1 || true; " +
            "[ -n \"$source\" ] && wpctl set-default \"$source\" >/dev/null 2>&1 || true; " +
            "sleep 0.35; done"
        ]
    }
}
