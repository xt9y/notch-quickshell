import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property string deviceName: ""
    signal routeChanged()

    visible: active && deviceName !== ""
    enabled: visible
    width: 26
    height: 28

    UiSymbols { id: symbols }

    Text {
        anchors.centerIn: parent
        text: symbols.audioRoute
        color: routeMouse.containsMouse ? "#d1d1d6" : "#636366"
        font.pixelSize: 10
        font.weight: Font.DemiBold
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: routeMouse
        anchors.fill: parent
        anchors.margins: -5
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (routeAction.running)
                return
            routeAction.environment = ({ BT_DEVICE_NAME: root.deviceName })
            routeAction.running = true
        }
    }

    Process {
        id: routeAction
        command: [
            "bash",
            "-lc",
            "name=\"$BT_DEVICE_NAME\"; [ -n \"$name\" ] || exit 0; " +
            "status=$(wpctl status -n 2>/dev/null || true); " +
            "sink=$(printf '%s\\n' \"$status\" | sed -n '/Sinks:/,/Sources:/p' | " +
            "awk -v needle=\"$name\" 'BEGIN { n=tolower(needle) } " +
            "index(tolower($0), n) && match($0, /[0-9]+\\./) { print substr($0,RSTART,RLENGTH-1); exit }'); " +
            "source=$(printf '%s\\n' \"$status\" | sed -n '/Sources:/,/Filters:/p' | " +
            "awk -v needle=\"$name\" 'BEGIN { n=tolower(needle) } " +
            "index(tolower($0), n) && match($0, /[0-9]+\\./) { print substr($0,RSTART,RLENGTH-1); exit }'); " +
            "[ -n \"$sink\" ] && wpctl set-default \"$sink\" >/dev/null 2>&1 || true; " +
            "[ -n \"$source\" ] && wpctl set-default \"$source\" >/dev/null 2>&1 || true"
        ]
        onRunningChanged: if (!running) {
            environment = ({})
            root.routeChanged()
        }
    }
}
