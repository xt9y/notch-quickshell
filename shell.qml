import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

ShellRoot {
    // Make this repository the source of truth for Hyprland as well.
    // Every `qs -c notch` run ensures ~/.config/hypr/hyprland.lua points
    // at hypr/hyprland.lua in this repo, then reloads Hyprland.
    Process {
        running: true
        command: [
            "bash",
            Quickshell.shellDir + "/scripts/apply-hypr.sh",
            Quickshell.shellDir
        ]
    }

    PanelWindow {
        id: panel

        anchors {
            top: true
            left: true
            right: true
        }

        color: "transparent"
        implicitHeight: 29
        exclusionMode: ExclusionMode.Ignore

        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Item {
            id: island

            property int notchWidth: 98
            property int notchHeight: 29
            property int expandedWidth: 355
            property int cornerRadius: 8
            property bool expanded: hover.hovered
            property real wingWidth: (width - notchWidth) / 2

            property var battery: UPower.displayDevice
            property real batteryLevel: battery && battery.ready
                ? Math.max(0, Math.min(1, battery.percentage))
                : 0
            property bool batteryCharging: battery && battery.ready &&
                (battery.state === UPowerDeviceState.Charging ||
                 battery.state === UPowerDeviceState.PendingCharge)
            property bool batteryFull: battery && battery.ready &&
                (battery.state === UPowerDeviceState.FullyCharged || batteryLevel >= 0.95)

            property color batteryColor: batteryCharging || batteryFull
                ? "#30d158"
                : batteryLevel <= 0.15
                    ? "#ff453a"
                    : batteryLevel <= 0.30
                        ? "#ffd60a"
                        : "#f2f2f7"

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            width: expanded ? expandedWidth : notchWidth
            height: notchHeight

            HoverHandler {
                id: hover
            }

            Rectangle {
                anchors.fill: parent
                radius: island.cornerRadius
                color: "#000000"
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: island.cornerRadius
                color: "#000000"
            }

            Item {
                id: leftWing

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                width: island.wingWidth
                height: parent.height
                opacity: island.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    id: timeText

                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }

                    width: implicitWidth
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: batteryIndicator

                    anchors {
                        left: timeText.right
                        leftMargin: 7
                        verticalCenter: parent.verticalCenter
                    }

                    width: island.batteryCharging ? 34 : 25
                    height: 12
                    visible: island.battery && island.battery.ready

                    Rectangle {
                        id: batteryBody

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: 21
                        height: 10
                        radius: 2.5
                        color: "transparent"
                        border.width: 1
                        border.color: "#d1d1d6"

                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: 2
                                top: parent.top
                                topMargin: 2
                                bottom: parent.bottom
                                bottomMargin: 2
                            }

                            width: Math.max(0, (batteryBody.width - 4) * island.batteryLevel)
                            radius: 1.2
                            color: island.batteryColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: batteryTip

                        anchors {
                            left: batteryBody.right
                            leftMargin: 1
                            verticalCenter: parent.verticalCenter
                        }

                        width: 2
                        height: 5
                        radius: 1
                        color: "#d1d1d6"
                    }

                    Text {
                        anchors {
                            left: batteryTip.right
                            leftMargin: 3
                            verticalCenter: parent.verticalCenter
                        }

                        visible: island.batteryCharging
                        text: "⚡"
                        color: "white"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                anchors {
                    right: parent.right
                    rightMargin: 16
                    verticalCenter: parent.verticalCenter
                }

                width: implicitWidth
                text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                color: "#b8b8bd"
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                opacity: island.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }
        }
    }
}
