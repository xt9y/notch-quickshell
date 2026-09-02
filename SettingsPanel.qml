import QtQuick

Item {
    id: root

    property bool active: false
    property var settings: null

    // Kept for shell compatibility; these entries are intentionally no longer exposed.
    property bool weatherConfigured: false
    signal calendarRequested()
    signal weatherRequested()

    signal closeRequested()

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

    component ToggleRow: Item {
        id: row
        property string label: ""
        property string detail: ""
        property bool checked: false
        signal toggled(bool value)

        width: parent ? parent.width : 0
        height: 54

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: rowMouse.containsMouse ? "#151517" : "#111113"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 9
            text: row.label
            color: "#e5e5ea"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.right: stateDot.left
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: row.detail
            color: "#636366"
            font.pixelSize: 10
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Rectangle {
            id: stateDot
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 4.5
            color: row.checked ? "#30d158" : "#48484a"
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled(!row.checked)
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: "Settings"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            id: closeGlyph
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: symbols.close
            color: closeMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
            font.pixelSize: 15
            font.weight: Font.DemiBold

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
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

    Column {
        id: settingsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: header.bottom
        anchors.topMargin: 12
        spacing: 8

        ToggleRow {
            width: parent.width
            label: "Always show Date + Time"
            detail: "Keep the compact clock visible without hovering"
            checked: root.settings ? root.settings.alwaysShowDateTime : false
            onToggled: function(value) {
                if (root.settings)
                    root.settings.setAlwaysShowDateTime(value)
            }
        }

        ToggleRow {
            width: parent.width
            label: "24-hour time"
            detail: "Use 13:45 instead of 1:45 PM"
            checked: root.settings ? root.settings.use24HourTime : true
            onToggled: function(value) {
                if (root.settings)
                    root.settings.setUse24HourTime(value)
            }
        }

        ToggleRow {
            width: parent.width
            label: "Show battery"
            detail: "Display the battery beside the clock"
            checked: root.settings ? root.settings.showBattery : true
            onToggled: function(value) {
                if (root.settings)
                    root.settings.setShowBattery(value)
            }
        }

        ToggleRow {
            width: parent.width
            label: "Show in fullscreen apps"
            detail: "Keep the notch above fullscreen windows"
            checked: root.settings ? root.settings.showInFullscreen : true
            onToggled: function(value) {
                if (root.settings)
                    root.settings.setShowInFullscreen(value)
            }
        }

        Rectangle {
            width: parent.width
            height: 42
            radius: 10
            color: resetMouse.containsMouse ? "#151517" : "#111113"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset notch preferences"
                color: "#8e8e93"
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.settings)
                        root.settings.resetDefaults()
                }
            }
        }
    }
}
