import QtQuick

Item {
    id: root

    property bool active: false
    property real leftWingWidth: 0
    property real rightWingWidth: 0
    property int normalHeight: 48
    property date now: new Date()
    property string timeText: ""
    property string dateText: ""
    property bool showBattery: true
    property var battery: null
    property real batteryLevel: 0
    property bool batteryCharging: false
    property color batteryColor: "#f2f2f7"
    property color batteryShellColor: "#d1d1d6"

    signal settingsRequested()

    anchors.fill: parent
    visible: active
    enabled: active

    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.leftWingWidth
        height: root.normalHeight

        Text {
            id: timeLabel
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText !== ""
                ? root.timeText
                : Qt.formatDateTime(root.now, "HH:mm")
            color: leftMouse.containsMouse ? "#f5f5f7" : "white"
            font.pixelSize: 17
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Item {
            anchors.left: timeLabel.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: root.showBattery ? 38 : 0
            height: 28
            visible: root.showBattery && root.battery && root.battery.ready

            Item {
                anchors.centerIn: parent
                width: 34
                height: 18

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

        MouseArea {
            id: leftMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsRequested()
        }
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        width: root.rightWingWidth
        height: root.normalHeight

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateText !== ""
                ? root.dateText
                : Qt.formatDateTime(root.now, "ddd, d MMM")
            color: "#b8b8bd"
            font.pixelSize: 17
            font.weight: Font.Medium
        }

        // Consume right-wing clicks so the removed Calendar action underneath cannot fire.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: function(mouse) { mouse.accepted = true }
        }
    }
}
