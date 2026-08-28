import QtQuick
import QtQuick.Shapes
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
        implicitHeight: 48

        // Reserve the enlarged notch clearance directly through Wayland
        // layer-shell so Plasma/KWin keeps normal windows below it.
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 49

        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Item {
            id: island

            property int notchWidth: 170
            property int notchHeight: 48
            property int collapsedVisualHeight: 44
            property int expandedWidth: 540
            property int cornerRadius: 13
            property bool expanded: hover.hovered
            property real wingWidth: (width - notchWidth) / 2
            property real visualHeight: expanded ? notchHeight : collapsedVisualHeight

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

            // One exact notch silhouette: perfectly square along the display
            // edge, a flat bottom, and only the two lower corners rounded.
            // The collapsed silhouette is slightly shorter so no black lip is
            // visible below the physical notch while idle.
            Shape {
                id: notchShape

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: island.visualHeight
                antialiasing: true

                ShapePath {
                    strokeWidth: -1
                    fillColor: "#000000"

                    startX: 0
                    startY: 0

                    PathLine {
                        x: notchShape.width
                        y: 0
                    }

                    PathLine {
                        x: notchShape.width
                        y: notchShape.height - island.cornerRadius
                    }

                    PathQuad {
                        x: notchShape.width - island.cornerRadius
                        y: notchShape.height
                        controlX: notchShape.width
                        controlY: notchShape.height
                    }

                    PathLine {
                        x: island.cornerRadius
                        y: notchShape.height
                    }

                    PathQuad {
                        x: 0
                        y: notchShape.height - island.cornerRadius
                        controlX: 0
                        controlY: notchShape.height
                    }

                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }

            Item {
                id: leftWing

                anchors {
                    left: parent.left
                    verticalCenter: notchShape.verticalCenter
                }

                width: island.wingWidth
                height: notchShape.height
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
                        leftMargin: 24
                        verticalCenter: parent.verticalCenter
                    }

                    width: implicitWidth
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: batteryIndicator

                    anchors {
                        left: timeText.right
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    width: island.batteryCharging ? 48 : 36
                    height: 18
                    visible: island.battery && island.battery.ready

                    Rectangle {
                        id: batteryBody

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: 30
                        height: 15
                        radius: 3.5
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
                            radius: 1.7
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
                        height: 7
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
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                anchors {
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: notchShape.verticalCenter
                }

                width: implicitWidth
                text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                color: "#b8b8bd"
                font.pixelSize: 17
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

            Behavior on visualHeight {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
