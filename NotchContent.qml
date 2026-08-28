import QtQuick

Item {
    id: root
    property string displayMode: "normal"
    property bool expanded: false
    property real wingWidth: 0
    property int normalHeight: 48
    property date now: new Date()
    property var battery: null
    property real batteryLevel: 0
    property bool batteryCharging: false
    property color batteryColor: "#f2f2f7"
    property color batteryShellColor: "#d1d1d6"
    property string batteryEventText: "Battery"
    property bool musicPlaying: false
    property bool musicSessionAvailable: false
    property var activePlayer: null
    property string musicTitle: ""
    property string musicArtist: ""
    property url musicArtSource: ""
    property real musicPosition: 0
    property real musicLength: 0
    property real musicProgress: 0
    property int volumePercent: 0
    property bool volumeMuted: false
    property int brightnessPercent: 0
    property bool wifiEnabled: false
    property string wifiSsid: ""
    property bool bluetoothPowered: false
    property string bluetoothDevice: ""
    property string bluetoothEventText: "Bluetooth"
    property string detailPanelType: "wifi"

    signal wifiPanelRequested()
    signal bluetoothPanelRequested()
    signal detailBackRequested()
    signal statusRefreshRequested()

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 19
        anchors.top: parent.top
        anchors.topMargin: 15
        opacity: root.musicPlaying && !root.expanded ? 1 : 0
        visible: opacity > 0.01
        text: "♪"
        color: "#c7c7cc"
        font.pixelSize: 13
        font.weight: Font.Medium
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Item {
        property bool active: root.displayMode === "normal" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        enabled: active
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.wingWidth
            height: root.normalHeight
            Text {
                id: normalTime
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(root.now, "HH:mm")
                color: "white"
                font.pixelSize: 17
                font.weight: Font.Medium
            }
            Item {
                anchors.left: normalTime.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: root.batteryCharging ? 48 : 36
                height: 18
                visible: root.battery && root.battery.ready
                Rectangle {
                    id: batteryBody
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 15
                    radius: 3.5
                    color: "transparent"
                    border.width: 1
                    border.color: root.batteryShellColor
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: Math.max(0, (batteryBody.width - 6) * root.batteryLevel)
                        radius: 1.7
                        color: root.batteryColor
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
                Rectangle {
                    anchors.left: batteryBody.right
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 7
                    radius: 1.5
                    color: root.batteryShellColor
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 13
            text: Qt.formatDateTime(root.now, "ddd, d MMM")
            color: "#b8b8bd"
            font.pixelSize: 17
            font.weight: Font.Medium
        }
    }

    NotchMusic {
        anchors.fill: parent
        active: root.displayMode === "music" && root.musicSessionAvailable && root.expanded
        playing: root.musicPlaying
        player: root.activePlayer
        title: root.musicTitle
        artist: root.musicArtist
        artSource: root.musicArtSource
        position: root.musicPosition
        length: root.musicLength
        progress: root.musicProgress
    }

    Item {
        property bool active: root.displayMode === "connectivity" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        enabled: active
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 185; easing.type: Easing.OutBack; easing.overshoot: 0.4 } }
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.wingWidth
            height: root.normalHeight
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: root.wifiEnabled ? "#30d158" : "#636366" }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 39
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiSsid !== "" ? root.wifiSsid : "Wi-Fi"
                color: "#e8e8ed"
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.wifiPanelRequested() }
        }
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            width: root.wingWidth
            height: root.normalHeight
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: root.bluetoothPowered ? "#30d158" : "#636366" }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 39
                anchors.verticalCenter: parent.verticalCenter
                text: root.bluetoothDevice !== "" ? root.bluetoothDevice : "Bluetooth"
                color: "#e8e8ed"
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.bluetoothPanelRequested() }
        }
    }

    ConnectivityPanel {
        anchors.fill: parent
        active: (root.displayMode === "wifiPanel" || root.displayMode === "bluetoothPanel") && root.expanded
        panelType: root.detailPanelType
        wifiEnabled: root.wifiEnabled
        bluetoothPowered: root.bluetoothPowered
        onBackRequested: root.detailBackRequested()
        onStatusRefreshRequested: root.statusRefreshRequested()
    }

    Item {
        property bool active: root.displayMode === "volume" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 145; easing.type: Easing.OutBack; easing.overshoot: 0.28 } }
        Text { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: root.volumeMuted ? "Muted" : "Volume"; color: "white"; font.pixelSize: 15; font.weight: Font.Medium }
        Rectangle {
            anchors.centerIn: parent
            width: 104
            height: 4
            radius: 2
            color: "#343438"
            Rectangle { width: parent.width * (root.volumeMuted ? 0 : root.volumePercent / 100); height: parent.height; radius: parent.radius; color: "#f2f2f7"; Behavior on width { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: root.volumeMuted ? "—" : root.volumePercent; color: "#e8e8ed"; font.pixelSize: 17; font.weight: Font.Medium }
    }

    Item {
        property bool active: root.displayMode === "brightness" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 145; easing.type: Easing.OutBack; easing.overshoot: 0.28 } }
        Text { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "☀"; color: "white"; font.pixelSize: 18 }
        Rectangle {
            anchors.centerIn: parent
            width: 112
            height: 4
            radius: 2
            color: "#343438"
            Rectangle { width: parent.width * (root.brightnessPercent / 100); height: parent.height; radius: parent.radius; color: "#f2f2f7"; Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: root.brightnessPercent; color: "#e8e8ed"; font.pixelSize: 17; font.weight: Font.Medium }
    }

    Item {
        property bool active: root.displayMode === "battery" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.batteryEventText
            color: root.batteryCharging ? "#30d158" : root.batteryLevel <= 0.20 ? "#ff453a" : "#e8e8ed"
            font.pixelSize: 16
            font.weight: Font.Medium
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.batteryLevel * 100) + "%"
            color: root.batteryColor
            font.pixelSize: 17
            font.weight: Font.Medium
        }
    }

    Item {
        property bool active: root.displayMode === "bluetooth" && root.expanded
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.985
        visible: opacity > 0.01
        Text { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth"; color: "#e8e8ed"; font.pixelSize: 15; font.weight: Font.Medium }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: root.wingWidth - 30
            text: root.bluetoothEventText
            color: "white"
            font.pixelSize: 15
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
