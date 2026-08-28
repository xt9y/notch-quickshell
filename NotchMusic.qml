import QtQuick

Item {
    id: root
    property bool active: false
    property bool playing: false
    property var player: null
    property string title: ""
    property string artist: ""
    property url artSource: ""
    property real position: 0
    property real length: 0
    property real progress: 0

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.972
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: 115; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 165; easing.type: Easing.OutBack; easing.overshoot: 0.32 } }

    function timeText(seconds) {
        if (!isFinite(seconds) || seconds < 0) seconds = 0
        var total = Math.floor(seconds)
        var mins = Math.floor(total / 60)
        var secs = total % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: 17
        Text {
            text: "‹"
            color: root.player && root.player.canGoPrevious ? "white" : "#55555a"
            font.pixelSize: 25
            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
        }
        Text {
            text: root.playing ? "Ⅱ" : "▶"
            color: root.player && root.player.canTogglePlaying ? "white" : "#55555a"
            font.pixelSize: root.playing ? 16 : 15
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
        }
        Text {
            text: "›"
            color: root.player && root.player.canGoNext ? "white" : "#55555a"
            font.pixelSize: 25
            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoNext; onClicked: root.player.next() }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 17
        text: root.playing ? root.timeText(root.position) + " / " + root.timeText(root.length) : "Paused · " + root.timeText(root.position) + " / " + root.timeText(root.length)
        color: root.playing ? "#8e8e93" : "#b8b8bd"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Item {
        id: albumArt
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 52
        width: 68
        height: 68
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#1c1c1e"
            Text { anchors.centerIn: parent; visible: artImage.status !== Image.Ready; text: "♪"; color: "#636366"; font.pixelSize: 25 }
        }
        Image {
            id: artImage
            anchors.fill: parent
            anchors.margins: 2
            source: root.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: 160
            sourceSize.height: 160
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.width: 3; border.color: "#000000" }
    }

    Item {
        anchors.left: albumArt.right
        anchors.leftMargin: 15
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 53
        height: 67
        Text {
            id: titleText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: root.title
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleText.bottom
            anchors.topMargin: 3
            text: root.artist
            color: "#8e8e93"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            height: 4
            radius: 2
            color: "#2c2c2e"
            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: parent.radius
                color: "#f2f2f7"
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.Linear } }
            }
        }
    }
}
