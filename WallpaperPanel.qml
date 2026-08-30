import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property string selectedPath: ""
    property string statusText: ""
    property bool applying: applyAction.running

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

    function consumeWallpapers(raw) {
        var rows = []
        var lines = raw.split("\n")

        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "")
                continue

            var split = lines[i].indexOf("\t")
            if (split <= 0)
                continue

            rows.push({
                fileName: lines[i].slice(0, split),
                filePath: lines[i].slice(split + 1)
            })
        }

        wallpaperModel.clear()
        for (var j = 0; j < rows.length; ++j)
            wallpaperModel.append(rows[j])
    }

    function refresh() {
        if (root.active && !scanAction.running)
            scanAction.running = true
    }

    function applyWallpaper(path) {
        if (path === "" || applyAction.running)
            return

        root.statusText = "Applying..."
        applyAction.command = [
            "bash",
            (Quickshell.env("HOME") || "") + "/.config/quickshell/notch/apply-wallpaper.sh",
            path
        ]
        applyAction.running = true
    }

    function consumeApplyResult(raw) {
        var line = raw.trim()
        if (line === "") {
            root.statusText = "Could not apply wallpaper"
            return
        }

        var fields = line.split("\t")
        if (fields[0] === "OK") {
            if (fields.length > 1)
                root.selectedPath = fields.slice(1).join("\t")
            root.statusText = "Applied to desktop, lock screen and login"
        } else if (fields[0] === "PARTIAL") {
            if (fields.length > 1)
                root.selectedPath = fields.slice(1).join("\t")
            root.statusText = "Desktop applied; login or lock screen needs permission"
        } else {
            root.statusText = fields.length > 1
                ? fields.slice(1).join(" ")
                : "Could not apply wallpaper"
        }
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
        interactive: contentHeight > height

        delegate: Item {
            id: row

            property string wallpaperName: model.fileName
            property string wallpaperPath: model.filePath
            property bool selected: root.selectedPath === wallpaperPath

            width: ListView.view ? ListView.view.width : 0
            height: 94

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: rowHover.hovered ? "#161618" : "#0c0c0e"
                border.width: row.selected ? 1 : 0
                border.color: "#5e5ce6"
                Behavior on color { ColorAnimation { duration: 100 } }
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
                anchors.right: stateDot.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.wallpaperName
                color: "#e8e8ed"
                font.pixelSize: 13
                font.weight: row.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideMiddle
            }

            Rectangle {
                id: stateDot
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: row.selected ? "#30d158" : "#48484a"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !root.applying
                onClicked: root.applyWallpaper(row.wallpaperPath)
            }

            HoverHandler { id: rowHover }
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
                : wallpaperModel.count + " wallpaper" + (wallpaperModel.count === 1 ? "" : "s")
            color: root.applying ? "#d1d1d6" : "#8e8e93"
            font.pixelSize: 11
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Timer {
        interval: 1400
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: scanAction
        command: [
            "bash",
            "-lc",
            "dir=\"${HOME}/.config/quickshell/notch/wallpaper\"; " +
            "mkdir -p \"$dir\"; " +
            "find \"$dir\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' \\) " +
            "-printf '%f\\t%p\\n' 2>/dev/null | sort -f"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.consumeWallpapers(text)
        }
    }

    Process {
        id: applyAction
        stdout: StdioCollector {
            onStreamFinished: root.consumeApplyResult(text)
        }
        onRunningChanged: if (!running)
            Qt.callLater(root.refresh)
    }
}
