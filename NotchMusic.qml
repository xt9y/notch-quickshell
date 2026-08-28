import QtQuick
import QtQuick.Shapes
import Quickshell.Io

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
    property int volumeValue: 0

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.972
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    UiSymbols { id: symbols }

    Behavior on opacity {
        NumberAnimation { duration: 115; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 165
            easing.type: Easing.OutBack
            easing.overshoot: 0.32
        }
    }

    function timeText(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0
        var total = Math.floor(seconds)
        var mins = Math.floor(total / 60)
        var secs = total % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    function consumeVolume(raw) {
        var match = raw.match(/Volume:\s*([0-9.]+)/)
        if (!match)
            return
        root.volumeValue = Math.max(0, Math.min(100,
            Math.round(parseFloat(match[1]) * 100)))
    }

    ArtworkSource {
        id: artworkSource
        player: root.player
        preferredSource: root.artSource
    }

    Text {
        anchors.horizontalCenter: albumArt.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        text: root.volumeValue
        color: "#b8b8bd"
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Timer {
        interval: 120
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!volumeProbe.running)
                volumeProbe.running = true
        }
    }

    Process {
        id: volumeProbe
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: root.consumeVolume(text)
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 17
        text: root.playing
            ? root.timeText(root.position) + " / " + root.timeText(root.length)
            : "Paused - " + root.timeText(root.position) + " / " + root.timeText(root.length)
        color: root.playing ? "#8e8e93" : "#b8b8bd"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Item {
        id: albumArt
        property real artRadius: 14

        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 52
        width: 68
        height: 68

        Rectangle {
            anchors.fill: parent
            radius: albumArt.artRadius
            color: "#1c1c1e"
            Text {
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: symbols.musicPlaceholder
                color: "#636366"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: artworkSource.resolvedSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: 160
            sourceSize.height: 160
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                strokeWidth: -1
                fillColor: "#000000"
                startX: 0
                startY: 0
                PathLine { x: albumArt.artRadius; y: 0 }
                PathQuad {
                    x: 0
                    y: albumArt.artRadius
                    controlX: 0
                    controlY: 0
                }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: "#000000"
                startX: albumArt.width
                startY: 0
                PathLine { x: albumArt.width - albumArt.artRadius; y: 0 }
                PathQuad {
                    x: albumArt.width
                    y: albumArt.artRadius
                    controlX: albumArt.width
                    controlY: 0
                }
                PathLine { x: albumArt.width; y: 0 }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: "#000000"
                startX: 0
                startY: albumArt.height
                PathLine { x: 0; y: albumArt.height - albumArt.artRadius }
                PathQuad {
                    x: albumArt.artRadius
                    y: albumArt.height
                    controlX: 0
                    controlY: albumArt.height
                }
                PathLine { x: 0; y: albumArt.height }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: "#000000"
                startX: albumArt.width
                startY: albumArt.height
                PathLine { x: albumArt.width; y: albumArt.height - albumArt.artRadius }
                PathQuad {
                    x: albumArt.width - albumArt.artRadius
                    y: albumArt.height
                    controlX: albumArt.width
                    controlY: albumArt.height
                }
                PathLine { x: albumArt.width; y: albumArt.height }
            }
        }
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
                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.Linear }
                }
            }
        }
    }
}
