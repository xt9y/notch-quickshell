import QtQuick

Item {
    id: root

    property bool active: false
    property var service: null
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

    component StatCard: Item {
        property string label: ""
        property string value: ""

        width: 244
        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "#111113"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 8
            text: label
            color: "#636366"
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.right: parent.right
            anchors.rightMargin: 10
            text: value
            color: "#e5e5ea"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    function oneDecimal(value) {
        return Number(value).toFixed(1)
    }

    function degree(value) {
        return Math.round(Number(value)) + "°"
    }

    function hourLabel(value) {
        var text = value || ""
        var parts = text.split(" ")
        return parts.length > 1 ? parts[1] : text
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
            text: "Weather"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 126
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 23
            anchors.verticalCenter: parent.verticalCenter
            text: symbols.refresh
            visible: root.service && root.service.apiKey !== ""
            color: refreshMouse.containsMouse ? "#d1d1d6" : "#8e8e93"
            font.pixelSize: 13
            font.weight: Font.DemiBold

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.refresh()
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

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        visible: root.service && root.service.keyLoaded && root.service.apiKey === ""

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 32
            text: "WeatherAPI.com"
            color: "#f5f5f7"
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 66
            text: "Paste your API key once. It is saved only on this computer. Your weather location is resolved automatically by the API."
            color: "#8e8e93"
            font.pixelSize: 12
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: keyField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 124
            height: 38
            radius: 10
            color: "#161618"
            border.width: 1
            border.color: keyInput.activeFocus ? "#5a5a60" : "#2c2c2e"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: keyInput.text.length === 0
                text: "API key"
                color: "#636366"
                font.pixelSize: 13
            }

            TextInput {
                id: keyInput
                anchors.left: parent.left
                anchors.right: saveKey.left
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: "#f5f5f7"
                font.pixelSize: 13
                echoMode: TextInput.Password
                passwordCharacter: "*"
                selectionColor: "#48484a"
                selectedTextColor: "white"
                clip: true

                Keys.onReturnPressed: {
                    if (root.service)
                        root.service.saveApiKey(text)
                    text = ""
                }
                Keys.onEnterPressed: {
                    if (root.service)
                        root.service.saveApiKey(text)
                    text = ""
                }
            }

            Text {
                id: saveKey
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: symbols.submit
                color: saveMouse.containsMouse ? "#f5f5f7" : "#8e8e93"
                font.pixelSize: 18
                font.weight: Font.Medium

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    anchors.margins: -9
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.service)
                            root.service.saveApiKey(keyInput.text)
                        keyInput.text = ""
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: keyField.bottom
            anchors.topMargin: 12
            text: "The key file is stored with user-only permissions."
            color: "#48484a"
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.service && !root.service.keyLoaded
        text: "Loading weather settings"
        color: "#636366"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        visible: root.service && root.service.apiKey !== "" && !root.service.ready

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -18
            text: root.service && root.service.loading
                ? "Loading weather"
                : (root.service ? root.service.errorText : "")
            color: root.service && root.service.errorText !== "" ? "#ff9f0a" : "#636366"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 10
            text: "Reset API key"
            color: resetErrorMouse.containsMouse ? "#d1d1d6" : "#636366"
            font.pixelSize: 11
            font.weight: Font.Medium

            MouseArea {
                id: resetErrorMouse
                anchors.fill: parent
                anchors.margins: -9
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.clearApiKey()
            }
        }
    }

    Flickable {
        id: weatherScroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 10
        clip: true
        visible: root.service && root.service.apiKey !== "" && root.service.ready
        contentWidth: width
        contentHeight: weatherColumn.height + 10
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3200

        Column {
            id: weatherColumn
            width: weatherScroll.width - 6
            spacing: 10

            Item {
                width: parent.width
                height: 92

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    text: root.service ? root.service.locationName : ""
                    color: "#f5f5f7"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 31
                    text: root.service
                        ? [root.service.locationRegion, root.service.locationCountry].filter(function(v) { return v !== "" }).join(", ")
                        : ""
                    color: "#636366"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    text: root.service ? root.degree(root.service.tempC) : ""
                    color: "#f5f5f7"
                    font.pixelSize: 36
                    font.weight: Font.Medium
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.right: parent.right
                    anchors.rightMargin: 120
                    text: root.service ? root.service.conditionText : ""
                    color: "#b8b8bd"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    text: root.service ? "Feels " + root.degree(root.service.feelsLikeC) : ""
                    color: "#636366"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            Grid {
                id: currentGrid
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                StatCard { width: (currentGrid.width - 8) / 2; label: "RAIN"; value: root.service ? root.service.rainChance + "%" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "HUMIDITY"; value: root.service ? root.service.humidity + "%" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "WIND"; value: root.service ? root.oneDecimal(root.service.windKph) + " km/h " + root.service.windDir : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "GUSTS"; value: root.service ? root.oneDecimal(root.service.gustKph) + " km/h" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "PRESSURE"; value: root.service ? Math.round(root.service.pressureMb) + " mb" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "VISIBILITY"; value: root.service ? root.oneDecimal(root.service.visibilityKm) + " km" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "CLOUD"; value: root.service ? root.service.cloud + "%" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "UV"; value: root.service ? root.oneDecimal(root.service.uv) : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "PRECIPITATION"; value: root.service ? root.oneDecimal(root.service.precipMm) + " mm" : "" }
                StatCard { width: (currentGrid.width - 8) / 2; label: "DEW POINT"; value: root.service ? root.degree(root.service.dewpointC) : "" }
            }

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 8
                text: "Forecast"
                color: "#8e8e93"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.service ? root.service.forecastDays : []

                Rectangle {
                    width: weatherColumn.width
                    height: 86
                    radius: 11
                    color: "#111113"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 9
                        text: modelData.date
                        color: "#f5f5f7"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 9
                        text: root.degree(modelData.maxC) + " / " + root.degree(modelData.minC)
                        color: "#d1d1d6"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 31
                        text: modelData.condition
                        color: "#8e8e93"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        text: "Rain " + modelData.rainChance + "%   Snow " + modelData.snowChance + "%   Wind " + root.oneDecimal(modelData.maxWindKph) + " km/h"
                        color: "#636366"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        text: modelData.sunrise + " - " + modelData.sunset
                        color: "#636366"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 8
                text: "Next 24 hours"
                color: "#8e8e93"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.service ? root.service.hourlyForecast : []

                Item {
                    width: weatherColumn.width
                    height: 42

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: "#1c1c1e"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hourLabel(modelData.time)
                        color: "#8e8e93"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 62
                        anchors.right: parent.right
                        anchors.rightMargin: 142
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.condition
                        color: "#d1d1d6"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 80
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.degree(modelData.tempC)
                        color: "#f5f5f7"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Rain " + modelData.rainChance + "%"
                        color: "#636366"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 8
                text: "Air quality"
                visible: root.service && Object.keys(root.service.airQuality || ({})).length > 0
                color: "#8e8e93"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Grid {
                id: airGrid
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: root.service && Object.keys(root.service.airQuality || ({})).length > 0

                StatCard { width: (airGrid.width - 8) / 2; label: "PM2.5"; value: root.service ? root.oneDecimal(root.service.airQuality["pm2_5"] || 0) : "" }
                StatCard { width: (airGrid.width - 8) / 2; label: "PM10"; value: root.service ? root.oneDecimal(root.service.airQuality["pm10"] || 0) : "" }
                StatCard { width: (airGrid.width - 8) / 2; label: "OZONE"; value: root.service ? root.oneDecimal(root.service.airQuality["o3"] || 0) : "" }
                StatCard { width: (airGrid.width - 8) / 2; label: "US EPA INDEX"; value: root.service ? String(root.service.airQuality["us-epa-index"] || "-") : "" }
            }

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 8
                text: "Alerts"
                visible: root.service && root.service.alerts.length > 0
                color: "#8e8e93"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.service ? root.service.alerts : []

                Rectangle {
                    width: weatherColumn.width
                    height: alertColumn.height + 18
                    radius: 11
                    color: "#171310"

                    Column {
                        id: alertColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 9
                        spacing: 4

                        Text {
                            width: parent.width
                            text: modelData.headline || modelData.event || "Weather alert"
                            color: "#ff9f0a"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: modelData.desc || ""
                            color: "#b8b8bd"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 48

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service ? "Updated " + Qt.formatTime(root.service.lastUpdated, "HH:mm") : ""
                    color: "#48484a"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Reset API key"
                    color: resetMouse.containsMouse ? "#b8b8bd" : "#48484a"
                    font.pixelSize: 10
                    font.weight: Font.Medium

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) root.service.clearApiKey()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 6
        y: weatherScroll.y + weatherScroll.visibleArea.yPosition * weatherScroll.height
        width: 2
        height: Math.max(14, weatherScroll.visibleArea.heightRatio * weatherScroll.height)
        radius: 1
        visible: weatherScroll.visible && weatherScroll.contentHeight > weatherScroll.height
        color: "#48484a"
    }
}
