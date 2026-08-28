import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool loaded: false
    property bool alwaysShowDateTime: false
    property bool use24HourTime: true
    property bool showBattery: true
    property string timeZone: ""
    property string timeZoneError: ""
    property string timeText: ""
    property string dateText: ""

    property string pendingTimeZone: ""

    width: 0
    height: 0
    visible: false

    function boolValue(value, fallback) {
        var v = (value || "").trim().toLowerCase()
        if (v === "1" || v === "true" || v === "yes")
            return true
        if (v === "0" || v === "false" || v === "no")
            return false
        return fallback
    }

    function save() {
        if (!loaded || saveProcess.running)
            return
        saveProcess.environment = ({
            NOTCH_ALWAYS: alwaysShowDateTime ? "1" : "0",
            NOTCH_24H: use24HourTime ? "1" : "0",
            NOTCH_BATTERY: showBattery ? "1" : "0",
            NOTCH_TZ: timeZone
        })
        saveProcess.running = true
    }

    function setAlwaysShowDateTime(value) {
        alwaysShowDateTime = value
        save()
    }

    function setUse24HourTime(value) {
        use24HourTime = value
        save()
        refreshClock()
    }

    function setShowBattery(value) {
        showBattery = value
        save()
    }

    function setTimeZone(value) {
        var zone = (value || "").trim()
        timeZoneError = ""
        if (zone === "") {
            timeZone = ""
            save()
            refreshClock()
            return
        }
        if (timeZoneValidation.running)
            return
        pendingTimeZone = zone
        timeZoneValidation.environment = ({ NOTCH_TZ: zone })
        timeZoneValidation.running = true
    }

    function resetDefaults() {
        alwaysShowDateTime = false
        use24HourTime = true
        showBattery = true
        timeZone = ""
        timeZoneError = ""
        save()
        refreshClock()
    }

    function refreshClock() {
        if (!loaded || clockProcess.running)
            return
        clockProcess.environment = ({
            NOTCH_TZ: timeZone,
            NOTCH_24H: use24HourTime ? "1" : "0"
        })
        clockProcess.running = true
    }

    Component.onCompleted: loadProcess.running = true

    Timer {
        interval: 15000
        repeat: true
        running: root.loaded
        triggeredOnStart: false
        onTriggered: root.refreshClock()
    }

    Process {
        id: loadProcess
        command: [
            "bash",
            "-lc",
            "file=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell/settings\"; " +
            "[ -r \"$file\" ] || exit 0; cat \"$file\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i]
                    var split = line.indexOf("=")
                    if (split < 0)
                        continue
                    var key = line.substring(0, split)
                    var value = line.substring(split + 1)
                    if (key === "alwaysShowDateTime")
                        root.alwaysShowDateTime = root.boolValue(value, false)
                    else if (key === "use24HourTime")
                        root.use24HourTime = root.boolValue(value, true)
                    else if (key === "showBattery")
                        root.showBattery = root.boolValue(value, true)
                    else if (key === "timeZone")
                        root.timeZone = value.trim()
                }
                root.loaded = true
                Qt.callLater(root.refreshClock)
            }
        }
    }

    Process {
        id: saveProcess
        command: [
            "bash",
            "-lc",
            "set -e; umask 077; " +
            "dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell\"; mkdir -p \"$dir\"; " +
            "tmp=\"$dir/settings.tmp.$$\"; " +
            "printf 'alwaysShowDateTime=%s\\nuse24HourTime=%s\\nshowBattery=%s\\ntimeZone=%s\\n' " +
            "\"$NOTCH_ALWAYS\" \"$NOTCH_24H\" \"$NOTCH_BATTERY\" \"$NOTCH_TZ\" > \"$tmp\"; " +
            "mv -f \"$tmp\" \"$dir/settings\""
        ]
        onRunningChanged: if (!running)
            environment = ({})
    }

    Process {
        id: timeZoneValidation
        command: [
            "bash",
            "-lc",
            "z=\"$NOTCH_TZ\"; " +
            "case \"$z\" in *..*|/*) printf no; exit 0 ;; esac; " +
            "[ -f \"/usr/share/zoneinfo/$z\" ] && printf yes || printf no"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var ok = text.trim() === "yes"
                if (ok) {
                    root.timeZone = root.pendingTimeZone
                    root.timeZoneError = ""
                    root.save()
                    Qt.callLater(root.refreshClock)
                } else {
                    root.timeZoneError = "Unknown time zone"
                }
                root.pendingTimeZone = ""
            }
        }
        onRunningChanged: if (!running)
            environment = ({})
    }

    Process {
        id: clockProcess
        command: [
            "bash",
            "-lc",
            "if [ \"$NOTCH_24H\" = 1 ]; then fmt='%H:%M'; else fmt='%I:%M %p'; fi; " +
            "if [ -n \"$NOTCH_TZ\" ]; then " +
            "TZ=\"$NOTCH_TZ\" date \"+$fmt\\t%a, %-d %b\"; " +
            "else date \"+$fmt\\t%a, %-d %b\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                var split = line.indexOf("\t")
                if (split >= 0) {
                    root.timeText = line.substring(0, split)
                    root.dateText = line.substring(split + 1)
                }
            }
        }
        onRunningChanged: if (!running)
            environment = ({})
    }
}
