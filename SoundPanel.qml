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

    component AudioRow: Item {
        id: row
        property string nodeId: ""
        property bool activeNode: false
        property string deviceName: ""
        signal selected(string id)

        width: ListView.view ? ListView.view.width : 0
        height: 34

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: rowHover.hovered ? "#161618" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: row.activeNode ? "#30d158" : "#48484a"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.deviceName
            color: row.activeNode ? "#f5f5f7" : "#d1d1d6"
            font.pixelSize: 13
            font.weight: row.activeNode ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.selected(row.nodeId)
        }

        HoverHandler { id: rowHover }
    }

    function consumeStatus(raw) {
        var outputs = []
        var inputs = []
        var lines = raw.split("\n")

        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "")
                continue

            var p = lines[i].split("\t")
            if (p.length < 4 || (p[0] !== "O" && p[0] !== "I"))
                continue

            var item = {
                nodeId: p[1],
                activeNode: p[2] === "1",
                deviceName: p.slice(3).join("\t").trim()
            }

            if (item.nodeId === "" || item.deviceName === "")
                continue

            if (p[0] === "O")
                outputs.push(item)
            else
                inputs.push(item)
        }

        function sortNodes(a, b) {
            if (a.activeNode !== b.activeNode)
                return a.activeNode ? -1 : 1
            return a.deviceName.localeCompare(b.deviceName)
        }

        outputs.sort(sortNodes)
        inputs.sort(sortNodes)

        outputModel.clear()
        inputModel.clear()
        for (var o = 0; o < outputs.length; ++o)
            outputModel.append(outputs[o])
        for (var j = 0; j < inputs.length; ++j)
            inputModel.append(inputs[j])
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
        text: "Output (" + outputModel.count + ")"
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
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        delegate: AudioRow {
            nodeId: model.nodeId
            activeNode: model.activeNode
            deviceName: model.deviceName
            onSelected: function(id) { root.selectNode(id) }
        }
    }

    Text {
        anchors.centerIn: outputList
        visible: outputModel.count === 0 && !statusProbe.running
        text: "No output devices"
        color: "#636366"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.right: outputList.right
        anchors.rightMargin: 2
        y: outputList.y + outputList.visibleArea.yPosition * outputList.height
        width: 2
        height: Math.max(12, outputList.visibleArea.heightRatio * outputList.height)
        radius: 1
        visible: outputList.contentHeight > outputList.height
        color: "#48484a"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 202
        text: "Input (" + inputModel.count + ")"
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
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        delegate: AudioRow {
            nodeId: model.nodeId
            activeNode: model.activeNode
            deviceName: model.deviceName
            onSelected: function(id) { root.selectNode(id) }
        }
    }

    Text {
        anchors.centerIn: inputList
        visible: inputModel.count === 0 && !statusProbe.running
        text: "No input devices"
        color: "#636366"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.right: inputList.right
        anchors.rightMargin: 2
        y: inputList.y + inputList.visibleArea.yPosition * inputList.height
        width: 2
        height: Math.max(12, inputList.visibleArea.heightRatio * inputList.height)
        radius: 1
        visible: inputList.contentHeight > inputList.height
        color: "#48484a"
    }

    Timer {
        interval: 1800
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
            "default_sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n '1s/^id \\([0-9][0-9]*\\),.*/\\1/p'); " +
            "default_source=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n '1s/^id \\([0-9][0-9]*\\),.*/\\1/p'); " +
            "if command -v pw-dump >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then " +
            "export DEFAULT_SINK_ID=\"$default_sink\" DEFAULT_SOURCE_ID=\"$default_source\"; " +
            "pw-dump 2>/dev/null | python3 -c 'import json,os,sys; data=json.load(sys.stdin); ds=os.getenv(\"DEFAULT_SINK_ID\",\"\"); di=os.getenv(\"DEFAULT_SOURCE_ID\",\"\"); [print(chr(9).join([(\"O\" if c==\"Audio/Sink\" else \"I\"),str(o.get(\"id\",\"\")),(\"1\" if str(o.get(\"id\",\"\"))==(ds if c==\"Audio/Sink\" else di) else \"0\"),label])) for o in data for p in [(o.get(\"info\",{}).get(\"props\",{}) or {})] for c in [str(p.get(\"media.class\",\"\"))] for label in [str(p.get(\"node.description\") or p.get(\"node.nick\") or p.get(\"device.description\") or p.get(\"node.name\") or \"Audio device\").replace(chr(9),\" \").replace(chr(10),\" \").strip()] if c in (\"Audio/Sink\",\"Audio/Source\") and label and not (c==\"Audio/Source\" and str(p.get(\"node.name\",\"\")).endswith(\".monitor\"))]' && exit 0; " +
            "fi; " +
            "wpctl status -n 2>/dev/null | awk '" +
            "/Sinks:/ {section=\"O\"; next} " +
            "/Sources:/ {section=\"I\"; next} " +
            "/Filters:|Streams:|Video:/ {section=\"\"; next} " +
            "section != \"\" && match($0, /[0-9]+\\./) { " +
            "id=substr($0, RSTART, RLENGTH-1); prefix=substr($0, 1, RSTART-1); " +
            "active=(index(prefix, \"*\") > 0 ? 1 : 0); " +
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
