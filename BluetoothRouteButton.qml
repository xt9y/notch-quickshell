import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property string deviceName: ""
    signal routeChanged()

    visible: active && deviceName !== ""
    enabled: visible
    width: 34
    height: 28

    UiSymbols { id: symbols }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: routeMouse.containsMouse ? "#2c2c2e" : "#1c1c1e"
        border.width: 1
        border.color: "#343438"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
        anchors.centerIn: parent
        text: symbols.audioRoute
        color: "#b8b8bd"
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: routeMouse
        anchors.fill: parent
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
