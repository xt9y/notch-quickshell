import QtQuick

Item {
    id: root

    property bool active: false
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    signal backRequested()

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.975
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    UiSymbols { id: symbols }

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

    function monthTitle() {
        return Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy")
    }

    function firstOffset() {
        var sundayBased = new Date(viewYear, viewMonth, 1).getDay()
        return (sundayBased + 6) % 7
    }

    function daysInMonth() {
        return new Date(viewYear, viewMonth + 1, 0).getDate()
    }

    function dayForCell(index) {
        return index - firstOffset() + 1
    }

    function isToday(day) {
        return day > 0 &&
            viewYear === today.getFullYear() &&
            viewMonth === today.getMonth() &&
            day === today.getDate()
    }

    function shiftMonth(delta) {
        var next = new Date(viewYear, viewMonth + delta, 1)
        viewYear = next.getFullYear()
        viewMonth = next.getMonth()
    }

    onActiveChanged: {
        if (active) {
            viewYear = today.getFullYear()
            viewMonth = today.getMonth()
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48

        Text {
            id: backGlyph
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: symbols.back
            color: "#d1d1d6"
            font.pixelSize: 22
            font.weight: Font.Medium
        }

        Text {
            anchors.left: backGlyph.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: "Calendar"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 132
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
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

    Item {
        id: monthBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 8
        height: 42

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.monthTitle()
            color: "#f5f5f7"
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Text {
            id: previousMonth
            anchors.right: nextMonth.left
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: symbols.previous
            color: previousMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
            font.pixelSize: 20
            font.weight: Font.Medium

            MouseArea {
                id: previousMouse
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shiftMonth(-1)
            }
        }

        Text {
            id: nextMonth
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: symbols.next
            color: nextMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
            font.pixelSize: 20
            font.weight: Font.Medium

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shiftMonth(1)
            }
        }
    }

    Row {
        id: weekdayHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.top: monthBar.bottom
        height: 28

        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            Item {
                width: weekdayHeader.width / 7
                height: weekdayHeader.height

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: "#636366"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Grid {
        id: calendarGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.top: weekdayHeader.bottom
        anchors.topMargin: 2
        columns: 7
        rows: 6
        spacing: 0

        Repeater {
            model: 42

            Item {
                property int dayNumber: root.dayForCell(index)
                property bool validDay: dayNumber >= 1 && dayNumber <= root.daysInMonth()

                width: calendarGrid.width / 7
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 29
                    height: 29
                    radius: 9
                    visible: validDay
                    color: root.isToday(dayNumber) ? "#f5f5f7" : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    visible: validDay
                    text: dayNumber
                    color: root.isToday(dayNumber) ? "#000000" : "#d1d1d6"
                    font.pixelSize: 12
                    font.weight: root.isToday(dayNumber) ? Font.DemiBold : Font.Medium
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: Qt.formatDate(root.today, "dddd, d MMMM yyyy")
        color: "#636366"
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
