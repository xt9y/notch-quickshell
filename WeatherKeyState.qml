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
            return base + "/notch-quickshell/weather-api-key"
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
            "file=\"${XDG_CONFIG_HOME:-$HOME/.config}/notch-quickshell/weather-api-key\"; " +
            "if [ -s \"$file\" ] && grep -q '[^[:space:]]' \"$file\" 2>/dev/null; then printf yes; else printf no; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.configured = text.trim() === "yes"
        }
    }
}
