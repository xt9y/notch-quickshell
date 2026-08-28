import QtQuick
import QtQml.Models
import Quickshell.Io

Item {
    id: root

    property bool active: false
    signal backRequested()
    signal statusRefreshRequested()

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.975
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    UiSymbols { id: symbols }
    ListModel { id: outputModel }
    ListModel { id: inputModel }

    Behavior on opacity {
        NumberAnimation { duration: 125; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 175
            easing.type: Easing.OutBack
            easing.overshoot: 0.35
        }
    }

    function consumeStatus(raw) {
        outputModel.clear()
        inputModel.clear()

        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "")
                continue
            var p = lines[i].split("\t")
            if (p.length < 4)
                continue

            var item = {
                nodeId: p[1],
                activeNode: p[2] === "1",
                deviceName: p.slice(3).join("\t").trim()
            }

            if (item.deviceName === "")
                continue
            if (p[0] === "O")
                outputModel.append(item)
            else if (p[0] === "I")
                inputModel.append(item)
        }
    }

    function refresh() {
        if (active && !statusProbe.running)
            statusProbe.running = true
    }

    function selectNode(id) {
        if (id === "" || selectAction.running)
            return
        selectAction.command = ["wpctl", "set-default", id]
        selectAction.running = true
    }

    onActiveChanged: if (active)
        Qt.callLater(root.refresh)

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48

        Text {
            id: backGlyph
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: symbols.back
            color: "#d1d1d6"
            font.pixelSize: 22
            font.weight: Font.Medium
        }

        Text {
            anchors.left: backGlyph.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: "Sound"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 120
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 23
            anchors.verticalCenter: parent.verticalCenter
            text: symbols.refresh
            color: "#8e8e93"
            font.pixelSize: 13
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: header.bottom
        height: 1
        color: "#242426"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 62
        text: "Output"
        color: "#8e8e93"
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    ListView {
        id: outputList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 82
        height: 108
        clip: true
        spacing: 2
        model: outputModel

        delegate: Item {
            width: outputList.width
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: outputHover.hovered ? "#161618" : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: model.activeNode ? "#30d158" : "#48484a"
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: model.deviceName
                color: model.activeNode ? "#f5f5f7" : "#d1d1d6"
                font.pixelSize: 13
                font.weight: model.activeNode ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectNode(model.nodeId)
            }

            HoverHandler { id: outputHover }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 202
        text: "Input"
        color: "#8e8e93"
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    ListView {
        id: inputList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 222
        height: 120
        clip: true
        spacing: 2
        model: inputModel

        delegate: Item {
            width: inputList.width
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: inputHover.hovered ? "#161618" : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: model.activeNode ? "#30d158" : "#48484a"
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: model.deviceName
                color: model.activeNode ? "#f5f5f7" : "#d1d1d6"
                font.pixelSize: 13
                font.weight: model.activeNode ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectNode(model.nodeId)
            }

            HoverHandler { id: inputHover }
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProbe
        command: [
            "bash",
            "-lc",
            "command -v wpctl >/dev/null 2>&1 || exit 0; " +
            "wpctl status -n 2>/dev/null | awk '" +
            "/Sinks:/ {section=\"O\"; next} " +
            "/Sources:/ {section=\"I\"; next} " +
            "/Filters:|Streams:|Video:/ {section=\"\"; next} " +
            "section != \"\" && match($0, /[0-9]+\\./) { " +
            "id=substr($0, RSTART, RLENGTH-1); " +
            "prefix=substr($0, 1, RSTART-1); active=(index(prefix, \"*\") > 0 ? 1 : 0); " +
            "name=substr($0, RSTART+RLENGTH); sub(/^[[:space:]]*/, \"\", name); " +
            "sub(/[[:space:]]+\\[[^]]*\\][[:space:]]*$/, \"\", name); " +
            "if (name != \"\") printf \"%s\\t%s\\t%s\\t%s\\n\", section, id, active, name; }'"
        ]
        stdout: StdioCollector { onStreamFinished: root.consumeStatus(text) }
    }

    Process {
        id: selectAction
        onRunningChanged: if (!running) {
            root.refresh()
            root.statusRefreshRequested()
        }
    }
}
