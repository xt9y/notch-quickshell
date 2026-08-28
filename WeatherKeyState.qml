import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool configured: false

    width: 0
    height: 0
    visible: false

    function check() {
        if (!checkProcess.running)
            checkProcess.running = true
    }

    Component.onCompleted: root.check()

    Timer {
        interval: root.configured ? 5000 : 600
        repeat: true
        running: true
        onTriggered: root.check()
    }

    FileView {
        path: {
            var base = Quickshell.env("XDG_CONFIG_HOME")
            if (!base || base === "")
                base = (Quickshell.env("HOME") || "") + "/.config"
            return base + "/notch-quickshell/weather-provider"
        }
        watchChanges: true
        onFileChanged: {
            reload()
            root.check()
        }
    }

    Process {
        id: checkProcess
        command: [
            "bash",
            "-lc",
            "dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell\"; " +
            "key=''; provider=''; " +
            "[ -r \"$dir/weather-api-key\" ] && key=$(cat \"$dir/weather-api-key\"); " +
            "[ -r \"$dir/weather-provider\" ] && provider=$(cat \"$dir/weather-provider\"); " +
            "if [ -n \"$key\" ] && { [ \"$provider\" = weatherapi ] || [ \"$provider\" = openweather ]; }; then printf yes; else printf no; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.configured = text.trim() === "yes"
        }
    }
}
