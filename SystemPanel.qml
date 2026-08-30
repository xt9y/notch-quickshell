import QtQuick

Item {
    id: root

    property bool active: false
    property bool detailMode: false
    property real leftWingWidth: 185
    property real rightWingWidth: 185
    property int normalHeight: 48
    property var monitor: null

    signal detailRequested()
    signal backRequested()

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.985
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    UiSymbols { id: symbols }

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

    function pct(value) {
        return Math.max(0, Math.min(100, Number(value) || 0))
    }

    component CompactMeter: Item {
        id: meter
        property string label: "RAM"
        property real percent: 0
        property string valueText: "0B"
        property color accent: "#30d158"
        signal clicked()

        height: root.normalHeight

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -7
            text: meter.label
            color: "#8e8e93"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -7
            text: Math.round(meter.percent) + "%"
            color: "#f5f5f7"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 8
            height: 5
            radius: 2.5
            color: "#242426"

            Rectangle {
                width: parent.width * root.pct(meter.percent) / 100
                height: parent.height
                radius: parent.radius
                color: meter.accent
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 19
            text: meter.valueText
            color: "#636366"
            font.pixelSize: 8
            font.weight: Font.Medium
            visible: false
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: meter.clicked()
        }
    }

    component StatCard: Rectangle {
        id: card
        property string title: "CPU"
        property string primary: "0%"
        property string secondary: ""
        property real percent: 0
        property color accent: "#64d2ff"

        radius: 12
        color: "#0c0c0e"
        border.width: 1
        border.color: "#242426"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 10
            text: card.title
            color: "#8e8e93"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 8
            text: card.primary
            color: "#f5f5f7"
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 19
            text: card.secondary
            color: "#636366"
            font.pixelSize: 9
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            height: 4
            radius: 2
            color: "#242426"

            Rectangle {
                width: parent.width * root.pct(card.percent) / 100
                height: parent.height
                radius: parent.radius
                color: card.accent
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
        }
    }

    Item {
        id: compact
        anchors.fill: parent
        visible: root.active && !root.detailMode
        enabled: visible

        CompactMeter {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.leftWingWidth
            label: "RAM"
            percent: root.monitor ? root.monitor.ramPercent : 0
            valueText: root.monitor
                ? root.monitor.formatBytes(root.monitor.ramUsedKiB) + " / " + root.monitor.formatBytes(root.monitor.ramTotalKiB)
                : "0B"
            accent: "#30d158"
            onClicked: root.detailRequested()
        }

        CompactMeter {
            anchors.right: parent.right
            anchors.top: parent.top
            width: root.rightWingWidth
            label: "ZRAM"
            percent: root.monitor ? root.monitor.zramPercent : 0
            valueText: root.monitor
                ? root.monitor.formatBytes(root.monitor.zramUsedKiB) + " / " + root.monitor.formatBytes(root.monitor.zramTotalKiB)
                : "0B"
            accent: "#0a84ff"
            onClicked: root.detailRequested()
        }
    }

    Item {
        id: detail
        anchors.fill: parent
        visible: root.active && root.detailMode
        enabled: visible

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 48

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: symbols.back
                color: backHover.hovered ? "#f5f5f7" : "#b8b8bd"
                font.pixelSize: 20
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
                HoverHandler { id: backHover }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: "System"
                color: "#f5f5f7"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: root.monitor
                    ? root.monitor.hostname + "  ·  " + root.monitor.uptimeText()
                    : "btop"
                color: "#636366"
                font.pixelSize: 10
                font.family: "monospace"
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

        Row {
            id: cards
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 60
            height: 76
            spacing: 8

            StatCard {
                width: (cards.width - 24) / 4
                height: cards.height
                title: "CPU"
                primary: root.monitor ? root.monitor.cpuPercent + "%" : "0%"
                secondary: root.monitor
                    ? root.monitor.cpuCores + " cores · load " + root.monitor.load1.toFixed(2)
                    : ""
                percent: root.monitor ? root.monitor.cpuPercent : 0
                accent: "#64d2ff"
            }

            StatCard {
                width: (cards.width - 24) / 4
                height: cards.height
                title: "RAM"
                primary: root.monitor ? Math.round(root.monitor.ramPercent) + "%" : "0%"
                secondary: root.monitor
                    ? root.monitor.formatBytes(root.monitor.ramUsedKiB) + " / " + root.monitor.formatBytes(root.monitor.ramTotalKiB)
                    : ""
                percent: root.monitor ? root.monitor.ramPercent : 0
                accent: "#30d158"
            }

            StatCard {
                width: (cards.width - 24) / 4
                height: cards.height
                title: "ZRAM"
                primary: root.monitor ? Math.round(root.monitor.zramPercent) + "%" : "0%"
                secondary: root.monitor
                    ? root.monitor.formatBytes(root.monitor.zramUsedKiB) + " / " + root.monitor.formatBytes(root.monitor.zramTotalKiB)
                    : ""
                percent: root.monitor ? root.monitor.zramPercent : 0
                accent: "#0a84ff"
            }

            StatCard {
                width: (cards.width - 24) / 4
                height: cards.height
                title: "DISK"
                primary: root.monitor ? Math.round(root.monitor.diskPercent) + "%" : "0%"
                secondary: root.monitor
                    ? root.monitor.formatBytes(root.monitor.diskUsedKiB) + " / " + root.monitor.formatBytes(root.monitor.diskTotalKiB)
                    : ""
                percent: root.monitor ? root.monitor.diskPercent : 0
                accent: "#ff9f0a"
            }
        }

        Rectangle {
            id: historyPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cards.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 9
            height: 108
            radius: 12
            color: "#08080a"
            border.width: 1
            border.color: "#242426"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.top: parent.top
                anchors.topMargin: 9
                text: "HISTORY"
                color: "#8e8e93"
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.top: parent.top
                anchors.topMargin: 8
                spacing: 12

                Text { text: "CPU"; color: "#64d2ff"; font.pixelSize: 9; font.weight: Font.DemiBold }
                Text { text: "RAM"; color: "#30d158"; font.pixelSize: 9; font.weight: Font.DemiBold }
                Text { text: "ZRAM"; color: "#0a84ff"; font.pixelSize: 9; font.weight: Font.DemiBold }
            }

            Canvas {
                id: historyCanvas
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 25
                anchors.bottomMargin: 8

                function drawSeries(ctx, values, color) {
                    if (!values || values.length < 2)
                        return
                    ctx.beginPath()
                    ctx.strokeStyle = color
                    ctx.lineWidth = 1.5
                    for (var i = 0; i < values.length; ++i) {
                        var x = values.length > 1 ? i * width / (values.length - 1) : 0
                        var y = height - root.pct(values[i]) * height / 100
                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#1c1c1e"
                    ctx.lineWidth = 1
                    for (var y = 0; y <= 4; ++y) {
                        var gy = y * height / 4
                        ctx.beginPath()
                        ctx.moveTo(0, gy)
                        ctx.lineTo(width, gy)
                        ctx.stroke()
                    }
                    if (root.monitor) {
                        drawSeries(ctx, root.monitor.cpuHistory, "#64d2ff")
                        drawSeries(ctx, root.monitor.ramHistory, "#30d158")
                        drawSeries(ctx, root.monitor.zramHistory, "#0a84ff")
                    }
                }

                Connections {
                    target: root.monitor
                    function onCpuHistoryChanged() { historyCanvas.requestPaint() }
                    function onRamHistoryChanged() { historyCanvas.requestPaint() }
                    function onZramHistoryChanged() { historyCanvas.requestPaint() }
                }
            }
        }

        Rectangle {
            id: processPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: historyPanel.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 9
            anchors.bottomMargin: 14
            radius: 12
            color: "#08080a"
            border.width: 1
            border.color: "#242426"
            clip: true

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.top: parent.top
                anchors.topMargin: 9
                text: "PROCESSES"
                color: "#8e8e93"
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.top: parent.top
                anchors.topMargin: 9
                text: root.monitor
                    ? "load " + root.monitor.load1.toFixed(2) + "  " + root.monitor.load5.toFixed(2) + "  " + root.monitor.load15.toFixed(2)
                    : ""
                color: "#636366"
                font.pixelSize: 9
                font.family: "monospace"
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 29
                height: 18

                Text { x: 13; width: 52; text: "PID"; color: "#48484a"; font.pixelSize: 9; font.family: "monospace" }
                Text { x: 72; width: parent.width - 190; text: "COMMAND"; color: "#48484a"; font.pixelSize: 9; font.family: "monospace" }
                Text { anchors.right: parent.right; anchors.rightMargin: 70; width: 42; text: "CPU%"; horizontalAlignment: Text.AlignRight; color: "#48484a"; font.pixelSize: 9; font.family: "monospace" }
                Text { anchors.right: parent.right; anchors.rightMargin: 13; width: 42; text: "MEM%"; horizontalAlignment: Text.AlignRight; color: "#48484a"; font.pixelSize: 9; font.family: "monospace" }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 47
                spacing: 0

                Repeater {
                    model: root.monitor ? root.monitor.processes : []

                    delegate: Item {
                        required property var modelData
                        width: processPanel.width
                        height: 19

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            radius: 5
                            color: rowHover.hovered ? "#141416" : "transparent"
                        }

                        Text { x: 13; width: 52; anchors.verticalCenter: parent.verticalCenter; text: modelData.pid; color: "#636366"; font.pixelSize: 9; font.family: "monospace" }
                        Text { x: 72; width: parent.width - 190; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: "#d1d1d6"; font.pixelSize: 10; font.family: "monospace"; elide: Text.ElideRight }
                        Text { anchors.right: parent.right; anchors.rightMargin: 70; width: 42; anchors.verticalCenter: parent.verticalCenter; text: Number(modelData.cpu).toFixed(1); horizontalAlignment: Text.AlignRight; color: Number(modelData.cpu) >= 25 ? "#ff9f0a" : "#64d2ff"; font.pixelSize: 9; font.family: "monospace" }
                        Text { anchors.right: parent.right; anchors.rightMargin: 13; width: 42; anchors.verticalCenter: parent.verticalCenter; text: Number(modelData.mem).toFixed(1); horizontalAlignment: Text.AlignRight; color: "#30d158"; font.pixelSize: 9; font.family: "monospace" }

                        HoverHandler { id: rowHover }
                    }
                }
            }
        }
    }
}
