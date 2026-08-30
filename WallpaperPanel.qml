import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property string selectedPath: ""
    property string currentPhase: ""
    property string statusText: ""
    property string wallpaperFingerprint: ""
    property string pendingWallpaperRaw: ""
    property bool pendingWallpaperRefresh: false
    property string cycleInFlightPath: ""
    property string queuedCyclePath: ""
    property bool applying: scheduleAction.running
    property string schedulerPath:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/notch/wallpaper-schedule.sh"

    signal closeRequested()

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.975
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    UiSymbols { id: symbols }
    ListModel { id: wallpaperModel }

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

    function listIsMoving() {
        return wallpaperList.dragging || wallpaperList.flicking || wallpaperList.moving
    }

    function applyWallpaperModel(raw) {
        var fingerprint = raw.trim()
        if (fingerprint === root.wallpaperFingerprint)
            return

        var rows = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "")
                continue

            var parts = lines[i].split("\t")
            if (parts.length < 3)
                continue

            rows.push({
                fileName: parts[0],
                filePath: parts[1],
                assignment: parts[2]
            })
        }

        var oldY = wallpaperList.contentY
        root.wallpaperFingerprint = fingerprint
        wallpaperModel.clear()
        for (var j = 0; j < rows.length; ++j)
            wallpaperModel.append(rows[j])

        Qt.callLater(function() {
            if (root.listIsMoving())
                return
            var minY = wallpaperList.originY
            var maxY = Math.max(
                minY,
                wallpaperList.originY + wallpaperList.contentHeight - wallpaperList.height
            )
            wallpaperList.contentY = Math.max(minY, Math.min(oldY, maxY))
        })
    }

    function consumeWallpapers(raw) {
        if (raw.trim() === root.wallpaperFingerprint)
            return

        if (root.listIsMoving()) {
            root.pendingWallpaperRaw = raw
            root.pendingWallpaperRefresh = true
            return
        }

        root.applyWallpaperModel(raw)
    }

    function flushPendingWallpapers() {
        if (!root.pendingWallpaperRefresh || root.listIsMoving())
            return

        var raw = root.pendingWallpaperRaw
        root.pendingWallpaperRaw = ""
        root.pendingWallpaperRefresh = false
        root.applyWallpaperModel(raw)
    }

    function refresh() {
        if (root.active && !root.listIsMoving() && !scanAction.running)
            scanAction.running = true
    }

    function cycleAssignment(path) {
        if (path === "")
            return

        if (assignmentAction.running) {
            root.queuedCyclePath = path
            return
        }

        root.cycleInFlightPath = path
        assignmentAction.command = ["bash", root.schedulerPath, "cycle", path]
        assignmentAction.running = true
    }

    function consumeAssignmentResult(raw) {
        var fields = raw.trim().split("\t")
        if (fields.length < 3 || fields[0] !== "STATE") {
            root.statusText = "Could not change wallpaper schedule"
            statusClearTimer.restart()
            return
        }

        var state = fields[2]
        if (state === "day")
            root.statusText = "Day wallpaper · 07:00–19:00"
        else if (state === "night")
            root.statusText = "Night wallpaper · 19:00–07:00"
        else
            root.statusText = "Wallpaper removed from schedule"

        statusClearTimer.restart()
    }

    function runSchedule() {
        if (scheduleAction.running)
            return
        scheduleAction.running = true
    }

    function consumeScheduleResult(raw) {
        var fields = raw.trim().split("\t")
        if (fields.length === 0)
            return

        if (fields[0] === "ACTIVE" && fields.length >= 3) {
            root.selectedPath = fields[1]
            root.currentPhase = fields[2]
            if (fields.length >= 4 && fields[3] === "PARTIAL" && root.active) {
                root.statusText = "Desktop changed; login helper is not ready yet"
                statusClearTimer.restart()
            }
        } else if (fields[0] === "NONE" && fields.length >= 2) {
            root.selectedPath = ""
            root.currentPhase = fields[1]
        }
    }

    Component.onCompleted: {
        startupSetup.running = true
        Qt.callLater(root.runSchedule)
    }

    onActiveChanged: if (active)
        Qt.callLater(root.refresh)

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 50

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: symbols.back
            color: backHover.hovered ? "#f5f5f7" : "#b8b8bd"
            font.pixelSize: 20
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }

            HoverHandler { id: backHover }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: "Wallpaper"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 23
            anchors.verticalCenter: parent.verticalCenter
            text: symbols.refresh
            color: refreshHover.hovered ? "#f5f5f7" : "#8e8e93"
            font.pixelSize: 13
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh()
            }

            HoverHandler { id: refreshHover }
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

    ListView {
        id: wallpaperList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 10
        clip: true
        spacing: 7
        model: wallpaperModel
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3200
        maximumFlickVelocity: 4200
        interactive: contentHeight > height
        cacheBuffer: height * 2

        onMovementEnded: Qt.callLater(root.flushPendingWallpapers)

        delegate: Item {
            id: row

            property string wallpaperName: model.fileName
            property string wallpaperPath: model.filePath
            property string assignment: model.assignment || "none"
            property bool scheduledActive: root.selectedPath === wallpaperPath
            property color assignmentColor: assignment === "day"
                ? "#ff9f0a"
                : assignment === "night" ? "#0a84ff" : "#3a3a3c"

            width: ListView.view ? ListView.view.width : 0
            height: 94

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: rowHover.hovered ? "#161618" : "#0c0c0e"
                border.width: row.assignment === "none" ? 0 : 2
                border.color: row.assignmentColor
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                id: previewFrame
                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 142
                height: 80
                radius: 9
                color: "#1c1c1e"
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + row.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }
            }

            Text {
                anchors.left: previewFrame.right
                anchors.leftMargin: 14
                anchors.right: activeDot.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.wallpaperName
                color: "#e8e8ed"
                font.pixelSize: 13
                font.weight: row.assignment !== "none" ? Font.DemiBold : Font.Medium
                elide: Text.ElideMiddle
            }

            Rectangle {
                id: activeDot
                anchors.right: assignmentLabel.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: row.scheduledActive ? "#30d158" : "transparent"
                border.width: row.scheduledActive ? 0 : 1
                border.color: "#3a3a3c"
            }

            Text {
                id: assignmentLabel
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                text: row.assignment === "day"
                    ? "DAY"
                    : row.assignment === "night" ? "NIGHT" : "NONE"
                color: row.assignment === "none" ? "#636366" : row.assignmentColor
                font.pixelSize: 10
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.DragThreshold
                onTapped: root.cycleAssignment(row.wallpaperPath)
            }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    Text {
        anchors.centerIn: wallpaperList
        visible: wallpaperModel.count === 0 && !scanAction.running
        text: "No .jpg or .png wallpapers"
        color: "#636366"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.right: wallpaperList.right
        anchors.rightMargin: 2
        y: wallpaperList.y + wallpaperList.visibleArea.yPosition * wallpaperList.height
        width: 2
        height: Math.max(12, wallpaperList.visibleArea.heightRatio * wallpaperList.height)
        radius: 1
        visible: wallpaperList.contentHeight > wallpaperList.height
        color: "#48484a"
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 38

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.top: parent.top
            height: 1
            color: "#242426"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: root.statusText !== ""
                ? root.statusText
                : "Click: NONE → DAY → NIGHT · current: " +
                    (root.currentPhase === "night" ? "NIGHT" : "DAY")
            color: root.applying ? "#d1d1d6" : "#8e8e93"
            font.pixelSize: 11
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Timer {
        id: statusClearTimer
        interval: 2400
        repeat: false
        onTriggered: root.statusText = ""
    }

    Timer {
        interval: 2200
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!root.listIsMoving())
                root.refresh()
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.runSchedule()
    }

    Process {
        id: scanAction
        command: ["bash", root.schedulerPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.consumeWallpapers(text)
        }
    }

    Process {
        id: assignmentAction
        stdout: StdioCollector {
            onStreamFinished: root.consumeAssignmentResult(text)
        }
        onRunningChanged: if (!running) {
            root.cycleInFlightPath = ""
            Qt.callLater(root.refresh)
            Qt.callLater(root.runSchedule)

            if (root.queuedCyclePath !== "") {
                var queued = root.queuedCyclePath
                root.queuedCyclePath = ""
                Qt.callLater(function() { root.cycleAssignment(queued) })
            }
        }
    }

    Process {
        id: scheduleAction
        command: ["bash", root.schedulerPath, "apply-current"]
        stdout: StdioCollector {
            onStreamFinished: root.consumeScheduleResult(text)
        }
    }

    Process {
        id: startupSetup
        command: [
            "bash",
            "-lc",
            "helper=/usr/local/libexec/notch-wallpaper-root; " +
            "if sudo -n \"$helper\" --probe >/dev/null 2>&1; then exit 0; fi; " +
            "setup=\"${HOME}/.config/quickshell/notch/setup-no-password.sh\"; " +
            "[ -r \"$setup\" ] || exit 0; user=$(id -un); " +
            "if command -v pkexec >/dev/null 2>&1; then " +
            "pkexec bash \"$setup\" --install-for \"$user\" >/dev/null 2>&1 || true; " +
            "elif sudo -n true >/dev/null 2>&1; then " +
            "sudo bash \"$setup\" --install-for \"$user\" >/dev/null 2>&1 || true; fi"
        ]
        onRunningChanged: if (!running)
            Qt.callLater(root.runSchedule)
    }
}
