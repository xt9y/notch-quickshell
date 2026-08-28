import QtQuick

Item {
    id: root

    property bool active: false
    property var settings: null
    property var weather: null

    signal closeRequested()
    signal calendarRequested()

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

        width: ListView.view ? ListView.view.width : 0
        height: detail === "" ? 44 : 54

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: rowMouse.containsMouse ? "#151517" : "#111113"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.top: parent.top
            anchors.topMargin: detail === "" ? 14 : 9
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
            visible: detail !== ""
            text: detail
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

    function focusTimeZone() {
        Qt.callLater(function() {
            timeZoneInput.forceActiveFocus()
            timeZoneInput.selectAll()
        })
    }

    function focusWeatherKey() {
        Qt.callLater(function() {
            weatherKeyInput.forceActiveFocus()
            weatherKeyInput.selectAll()
        })
    }

    onActiveChanged: {
        if (active && settings)
            timeZoneInput.text = settings.timeZone
        if (!active) {
            weatherKeyInput.text = ""
            timeZoneInput.focus = false
            weatherKeyInput.focus = false
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

    Flickable {
        id: scroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        contentWidth: width
        contentHeight: settingsColumn.height + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3200

        Column {
            id: settingsColumn
            width: scroll.width - 6
            spacing: 8

            Rectangle {
                width: parent.width
                height: 44
                radius: 10
                color: calendarMouse.containsMouse ? "#151517" : "#111113"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Calendar"
                    color: "#e5e5ea"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: symbols.forward
                    color: "#636366"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: calendarMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.calendarRequested()
                }
            }

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

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 5
                text: "Time zone"
                color: "#8e8e93"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: timeZoneField
                width: parent.width
                height: 42
                radius: 10
                color: "#111113"
                border.width: 1
                border.color: timeZoneInput.activeFocus ? "#5a5a60" : "#242426"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    visible: timeZoneInput.text.length === 0
                    text: "System timezone"
                    color: "#48484a"
                    font.pixelSize: 12
                }

                TextInput {
                    id: timeZoneInput
                    anchors.left: parent.left
                    anchors.right: timeZoneSave.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 13
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    activeFocusOnTab: true
                    color: "#e5e5ea"
                    selectionColor: "#48484a"
                    selectedTextColor: "white"
                    font.pixelSize: 12
                    clip: true

                    Keys.onReturnPressed: {
                        if (root.settings)
                            root.settings.setTimeZone(text)
                    }
                    Keys.onEnterPressed: {
                        if (root.settings)
                            root.settings.setTimeZone(text)
                    }
                }

                Text {
                    id: timeZoneSave
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: symbols.submit
                    color: timeZoneSaveMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
                    font.pixelSize: 17
                    font.weight: Font.Medium

                    MouseArea {
                        id: timeZoneSaveMouse
                        anchors.fill: parent
                        anchors.margins: -9
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.settings)
                                root.settings.setTimeZone(timeZoneInput.text)
                        }
                    }
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: timeZoneSave.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.IBeamCursor
                    onPressed: function(mouse) {
                        root.focusTimeZone()
                        mouse.accepted = false
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 8
                visible: root.settings && root.settings.timeZoneError !== ""
                text: root.settings ? root.settings.timeZoneError : ""
                color: "#ff9f0a"
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 5
                text: root.weather && root.weather.apiKey !== ""
                    ? "Weather API - " + root.weather.providerName()
                    : "Weather API"
                color: "#8e8e93"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: weatherKeyField
                width: parent.width
                height: 42
                radius: 10
                color: "#111113"
                border.width: 1
                border.color: weatherKeyInput.activeFocus ? "#5a5a60" : "#242426"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    visible: weatherKeyInput.text.length === 0
                    text: root.weather && root.weather.apiKey !== ""
                        ? "Paste a replacement key"
                        : "WeatherAPI.com or OpenWeather key"
                    color: "#48484a"
                    font.pixelSize: 12
                }

                TextInput {
                    id: weatherKeyInput
                    anchors.left: parent.left
                    anchors.right: weatherKeySave.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 13
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    activeFocusOnTab: true
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    color: "#e5e5ea"
                    selectionColor: "#48484a"
                    selectedTextColor: "white"
                    font.pixelSize: 12
                    clip: true

                    Keys.onReturnPressed: {
                        if (root.weather)
                            root.weather.saveApiKey(text)
                        text = ""
                    }
                    Keys.onEnterPressed: {
                        if (root.weather)
                            root.weather.saveApiKey(text)
                        text = ""
                    }
                }

                Text {
                    id: weatherKeySave
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: symbols.submit
                    color: weatherKeySaveMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
                    font.pixelSize: 17
                    font.weight: Font.Medium

                    MouseArea {
                        id: weatherKeySaveMouse
                        anchors.fill: parent
                        anchors.margins: -9
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.weather)
                                root.weather.saveApiKey(weatherKeyInput.text)
                            weatherKeyInput.text = ""
                        }
                    }
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: weatherKeySave.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.IBeamCursor
                    onPressed: function(mouse) {
                        root.focusWeatherKey()
                        mouse.accepted = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 42
                radius: 10
                visible: root.weather && root.weather.apiKey !== ""
                color: clearWeatherMouse.containsMouse ? "#151517" : "#111113"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear weather API key"
                    color: "#d1d1d6"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: symbols.close
                    color: "#636366"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: clearWeatherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.weather) root.weather.clearApiKey()
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
                        if (root.settings) {
                            root.settings.resetDefaults()
                            timeZoneInput.text = ""
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 6
        y: scroll.y + scroll.visibleArea.yPosition * scroll.height
        width: 2
        height: Math.max(14, scroll.visibleArea.heightRatio * scroll.height)
        radius: 1
        visible: scroll.contentHeight > scroll.height
        color: "#48484a"
    }
}
