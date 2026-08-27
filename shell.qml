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
        implicitHeight: 32
        exclusionMode: ExclusionMode.Ignore

        // Only the physical notch / expanded island catches the pointer.
        mask: Region {
            item: island
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Rectangle {
            id: island

            // Tuned for a Retina-scaled notched MacBook display.
            // Hover changes width only: the island never grows downward.
            property int notchWidth: 98
            property int notchHeight: 32
            property int expandedWidth: 248
            property int cornerRadius: 8
            property bool expanded: hover.hovered

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            width: expanded ? expandedWidth : notchWidth
            height: notchHeight
            radius: cornerRadius
            color: "black"
            clip: true

            HoverHandler {
                id: hover
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                }

                spacing: 16
                opacity: island.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    width: (parent.width - parent.spacing) / 2
                    anchors.verticalCenter: parent.verticalCenter

                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: (parent.width - parent.spacing) / 2
                    anchors.verticalCenter: parent.verticalCenter

                    text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                    color: "#b8b8bd"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
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
