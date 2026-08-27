import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        id: panel

        anchors {
            top: true
            left: true
            right: true
        }

        color: "transparent"
        implicitHeight: 92
        exclusionMode: ExclusionMode.Ignore

        // Only the notch/island area should catch the pointer.
        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Rectangle {
            id: island

            // These are intentionally kept together so we can tune them to the
            // exact MacBook notch dimensions after the first on-device test.
            property int notchWidth: 210
            property int notchHeight: 34
            property int expandedWidth: 390
            property int expandedHeight: 64
            property bool expanded: hover.hovered

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            width: expanded ? expandedWidth : notchWidth
            height: expanded ? expandedHeight : notchHeight
            radius: expanded ? 22 : 12
            color: "black"

            HoverHandler {
                id: hover
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 24
                    rightMargin: 24
                }

                spacing: 18
                opacity: island.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    width: (parent.width - parent.spacing) / 2
                    anchors.verticalCenter: parent.verticalCenter

                    // Left: date
                    text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                    color: "#b8b8bd"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                }

                Text {
                    width: (parent.width - parent.spacing) / 2
                    anchors.verticalCenter: parent.verticalCenter

                    // Right: time
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutBack
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
