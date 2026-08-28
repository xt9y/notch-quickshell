import QtQuick
import Quickshell
import Quickshell.Services.UPower

ShellRoot {
    PanelWindow {
        id: panel

        anchors {
            top: true
            left: true
            right: true
        }

        color: "transparent"
        implicitHeight: 36

        // Reserve the notch clearance directly through Wayland layer-shell.
        // KWin respects this like a panel strut, so no compositor-specific
        // monitor reservation is needed.
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 37

        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Item {
            id: island

            // The complete notch UI is scaled up by roughly 25% while keeping
            // the same proportions and interaction model.
            property int notchWidth: 123
            property int notchHeight: 36
            property int expandedWidth: 444
            property int cornerRadius: 10
            property bool expanded: hover.hovered
            property real wingWidth: (width - notchWidth) / 2

            // In the idle state, rely entirely on the physical M2 notch. Keep
            // the software surface alive while the width animation contracts,
            // then remove it completely once we are fully collapsed.
            property bool surfaceVisible: expanded || width > notchWidth + 0.5

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
                visible: island.surfaceVisible
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: island.cornerRadius
                color: "#000000"
                visible: island.surfaceVisible
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
                        leftMargin: 20
                        verticalCenter: parent.verticalCenter
                    }

                    width: implicitWidth
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: batteryIndicator

                    anchors {
                        left: timeText.right
                        leftMargin: 9
                        verticalCenter: parent.verticalCenter
                    }

                    width: island.batteryCharging ? 43 : 31
                    height: 15
                    visible: island.battery && island.battery.ready

                    Rectangle {
                        id: batteryBody

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: 26
                        height: 13
                        radius: 3
                        color: "transparent"
                        border.width: 1
                        border.color: "#d1d1d6"

                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: 3
                                top: parent.top
                                topMargin: 3
                                bottom: parent.bottom
                                bottomMargin: 3
                            }

                            width: Math.max(0, (batteryBody.width - 6) * island.batteryLevel)
                            radius: 1.5
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

                        width: 3
                        height: 6
                        radius: 1.5
                        color: "#d1d1d6"
                    }

                    Text {
                        anchors {
                            left: batteryTip.right
                            leftMargin: 4
                            verticalCenter: parent.verticalCenter
                        }

                        visible: island.batteryCharging
                        text: "⚡"
                        color: "white"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                anchors {
                    right: parent.right
                    rightMargin: 20
                    verticalCenter: parent.verticalCenter
                }

                width: implicitWidth
                text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                color: "#b8b8bd"
                font.pixelSize: 15
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
