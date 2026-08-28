import QtQuick
import QtQml.Models
import Quickshell.Io

Item {
    id: root

    property string panelType: "wifi"
    property bool active: false
    property bool wifiEnabled: false
    property bool bluetoothPowered: false
    property bool airplaneMode: false
    property bool airplaneAvailable: false
    property string wifiPasswordSsid: ""

    signal backRequested()
    signal statusRefreshRequested()

    opacity: active ? 1 : 0
    scale: active ? 1 : 0.975
    visible: opacity > 0.01
    enabled: active
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: 125
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 175
            easing.type: Easing.OutBack
            easing.overshoot: 0.35
        }
    }

    component MiniToggle: Rectangle {
        id: toggle
        property bool checked: false
        property bool available: true
        signal toggled()
        width: 34
        height: 20
        radius: 10
        opacity: available ? 1 : 0.35
        color: checked ? "#30d158" : "#343438"
        Behavior on color { ColorAnimation { duration: 145 } }
        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 2
            x: toggle.checked ? toggle.width - width - 2 : 2
            color: "#f5f5f7"
            Behavior on x {
                NumberAnimation {
                    duration: 185
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.5
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: toggle.available
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component RoundButton: Rectangle {
        id: button
        property string glyph: "↻"
        signal clicked()
        width: 27
        height: 27
        radius: 13.5
        color: buttonMouse.containsMouse ? "#2c2c2e" : "#1c1c1e"
        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: "#d1d1d6"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: button.scale = 0.9
            onReleased: button.scale = 1
            onCanceled: button.scale = 1
            onClicked: button.clicked()
        }
    }

    ListModel { id: wifiModel }
    ListModel { id: bluetoothModel }

    function wifiScript(rescan) {
        var scan = rescan ? "nmcli device wifi rescan >/dev/null 2>&1 || true; " : ""
        return "command -v nmcli >/dev/null 2>&1 || exit 0; " + scan +
            "while IFS=$'\\t' read -r uuid type; do " +
            "[ \"$type\" = \"802-11-wireless\" ] || continue; " +
            "ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid \"$uuid\" 2>/dev/null | head -n1); " +
            "[ -n \"$ssid\" ] && printf 'K\\t%s\\t%s\\n' \"$ssid\" \"$uuid\"; " +
            "done < <(nmcli -t --escape no --separator $'\\t' -f UUID,TYPE connection show 2>/dev/null); " +
            "nmcli -t --escape no --separator $'\\t' -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | sed $'s/^/N\\t/'"
    }

    function refreshAirplane() {
        if (!airplaneProbe.running)
            airplaneProbe.running = true
    }

    function refreshWifi(rescan) {
        refreshAirplane()
        if (!active || panelType !== "wifi" || wifiListProbe.running)
            return
        wifiListProbe.command = ["bash", "-lc", wifiScript(rescan)]
        wifiListProbe.running = true
    }

    function refreshBluetooth(scan) {
        refreshAirplane()
        if (!active || panelType !== "bluetooth")
            return
        if (scan && !bluetoothScan.running)
            bluetoothScan.running = true
        if (!bluetoothListProbe.running)
            bluetoothListProbe.running = true
    }

    function refreshCurrent(rescan) {
        refreshAirplane()
        if (panelType === "wifi")
            refreshWifi(rescan)
        else
            refreshBluetooth(rescan)
    }

    function consumeAirplane(raw) {
        var lines = raw.trim().split("\n")
        airplaneAvailable = lines.length > 0 && lines[0] === "available"
        airplaneMode = airplaneAvailable && lines.length > 1 && lines[1] === "blocked"
    }

    function consumeWifiList(raw) {
        var known = ({})
        var found = ({})
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "") continue
            var p = lines[i].split("\t")
            if (p[0] === "K" && p.length >= 3) {
                known[p[1]] = p[2]
                continue
            }
            if (p[0] !== "N" || p.length < 4 || p[2] === "") continue
            var item = {
                ssid: p[2],
                active: p[1] === "*",
                strength: Math.max(0, Math.min(100, parseInt(p[3]) || 0)),
                security: p.length > 4 ? p.slice(4).join("\t") : ""
            }
            if (!found[item.ssid] || item.active || item.strength > found[item.ssid].strength)
                found[item.ssid] = item
        }
        var result = []
        for (var key in found) {
            var row = found[key]
            row.known = known[key] !== undefined
            row.uuid = row.known ? known[key] : ""
            result.push(row)
        }
        result.sort(function(a, b) {
            if (a.active !== b.active) return a.active ? -1 : 1
            if (a.known !== b.known) return a.known ? -1 : 1
            if (a.strength !== b.strength) return b.strength - a.strength
            return a.ssid.localeCompare(b.ssid)
        })
        wifiModel.clear()
        for (var j = 0; j < result.length; ++j)
            wifiModel.append(result[j])
    }

    function consumeBluetoothList(raw) {
        var result = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "") continue
            var p = lines[i].split("\t")
            if (p[0] !== "D" || p.length < 6) continue
            result.push({
                address: p[1],
                paired: p[2] === "yes",
                connected: p[3] === "yes",
                trusted: p[4] === "yes",
                deviceName: p.slice(5).join("\t")
            })
        }
        result.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return a.deviceName.localeCompare(b.deviceName)
        })
        bluetoothModel.clear()
        for (var j = 0; j < result.length; ++j)
            bluetoothModel.append(result[j])
    }

    function selectWifi(ssid, security, known, uuid) {
        if (wifiAction.running || wifiForget.running) return
        if (known && uuid !== "") {
            wifiPasswordSsid = ""
            wifiAction.exec(["nmcli", "connection", "up", "uuid", uuid])
            return
        }
        var secured = security !== "" && security !== "--"
        if (secured) {
            wifiPasswordSsid = ssid
            return
        }
        wifiPasswordSsid = ""
        wifiAction.exec(["nmcli", "device", "wifi", "connect", ssid])
    }

    function submitWifiPassword(ssid, password) {
        if (password === "" || wifiAction.running) return
        wifiAction.exec({
            command: ["bash", "-lc", "nmcli --wait 20 device wifi connect \"$NM_SSID\" password \"$NM_PASSWORD\""],
            environment: ({ NM_SSID: ssid, NM_PASSWORD: password })
        })
        wifiPasswordSsid = ""
    }

    function forgetWifi(uuid) {
        if (uuid === "" || wifiForget.running) return
        wifiPasswordSsid = ""
        wifiForget.exec(["nmcli", "connection", "delete", "uuid", uuid])
    }

    function selectBluetooth(address, paired, connected) {
        if (bluetoothAction.running || bluetoothForget.running) return
        if (connected) {
            bluetoothAction.exec(["bluetoothctl", "disconnect", address])
        } else if (paired) {
            bluetoothAction.exec(["bluetoothctl", "connect", address])
        } else {
            bluetoothAction.exec({
                command: [
                    "bash", "-lc",
                    "bluetoothctl power on >/dev/null 2>&1 || true; " +
                    "bluetoothctl --timeout 20 pair \"$BT_ADDR\" >/dev/null 2>&1 || exit 1; " +
                    "bluetoothctl trust \"$BT_ADDR\" >/dev/null 2>&1 || true; " +
                    "bluetoothctl connect \"$BT_ADDR\" >/dev/null 2>&1 || true"
                ],
                environment: ({ BT_ADDR: address })
            })
        }
    }

    function forgetBluetooth(address) {
        if (address === "" || bluetoothForget.running) return
        bluetoothForget.exec(["bluetoothctl", "remove", address])
    }

    function toggleAirplane() {
        if (!airplaneAvailable || radioAction.running) return
        radioAction.command = [
            "bash", "-lc",
            airplaneMode
                ? "rfkill unblock all >/dev/null 2>&1 || exit 1; nmcli networking on >/dev/null 2>&1 || true; nmcli radio wifi on >/dev/null 2>&1 || true; bluetoothctl power on >/dev/null 2>&1 || true"
                : "rfkill block all >/dev/null 2>&1"
        ]
        radioAction.running = true
    }

    function toggleCurrentRadio() {
        if (panelType === "wifi") {
            wifiRadioAction.command = wifiEnabled
                ? ["nmcli", "radio", "wifi", "off"]
                : ["bash", "-lc", "rfkill unblock wlan >/dev/null 2>&1 || true; nmcli radio wifi on"]
            wifiRadioAction.running = true
        } else {
            bluetoothRadioAction.command = bluetoothPowered
                ? ["bluetoothctl", "power", "off"]
                : ["bash", "-lc", "rfkill unblock bluetooth >/dev/null 2>&1 || true; bluetoothctl power on"]
            bluetoothRadioAction.running = true
        }
    }

    onActiveChanged: {
        if (active) Qt.callLater(function() { root.refreshCurrent(true) })
        else wifiPasswordSsid = ""
    }
    onPanelTypeChanged: {
        wifiPasswordSsid = ""
        if (active) Qt.callLater(function() { root.refreshCurrent(true) })
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48
        Text {
            id: backGlyph
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "‹"
            color: "#d1d1d6"
            font.pixelSize: 26
        }
        Text {
            anchors.left: backGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.panelType === "wifi" ? "Wi-Fi" : "Bluetooth"
            color: "#f5f5f7"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 120
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backRequested()
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: root.panelType === "wifi" ? (root.wifiEnabled ? "#30d158" : "#636366") : (root.bluetoothPowered ? "#30d158" : "#636366")
        }
    }

    Item {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 51
        height: 40

        Text {
            id: airplaneText
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "✈  Airplane"
            color: root.airplaneAvailable ? "#b8b8bd" : "#48484a"
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MiniToggle {
            anchors.left: airplaneText.right
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            checked: root.airplaneMode
            available: root.airplaneAvailable
            onToggled: root.toggleAirplane()
        }
        RoundButton {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            glyph: "↻"
            onClicked: root.refreshCurrent(true)
        }
        MiniToggle {
            id: radioToggle
            anchors.right: parent.right
            anchors.rightMargin: 60
            anchors.verticalCenter: parent.verticalCenter
            checked: root.panelType === "wifi" ? root.wifiEnabled : root.bluetoothPowered
            onToggled: root.toggleCurrentRadio()
        }
        Text {
            anchors.right: radioToggle.left
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: root.panelType === "wifi" ? "Wi-Fi" : "Bluetooth"
            color: "#b8b8bd"
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.top: controls.bottom
        height: 1
        color: "#242426"
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: controls.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: root.panelType === "wifi"
        clip: true

        Text {
            anchors.centerIn: parent
            visible: !root.wifiEnabled
            text: root.airplaneMode ? "Airplane mode" : "Wi-Fi is off"
            color: "#636366"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        ListView {
            id: wifiList
            anchors.fill: parent
            visible: root.wifiEnabled
            clip: true
            model: wifiModel
            spacing: 2
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            flickDeceleration: 3000
            maximumFlickVelocity: 4300
            rebound: Transition {
                NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.2 }
            }
            add: Transition {
                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 170; easing.type: Easing.OutBack }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: wifiRow
                width: wifiList.width
                height: 46
                property bool editing: root.wifiPasswordSsid === model.ssid
                onEditingChanged: {
                    if (editing) Qt.callLater(function() { passwordInput.forceActiveFocus() })
                    else passwordInput.text = ""
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: rowHover.hovered ? "#161618" : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Item {
                    id: signalIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17
                    height: 14
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 4
                        radius: 1.5
                        color: model.strength > 0 ? (model.active ? "#30d158" : "#d1d1d6") : "#3a3a3c"
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 8
                        radius: 1.5
                        color: model.strength >= 40 ? (model.active ? "#30d158" : "#d1d1d6") : "#3a3a3c"
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 12
                        radius: 1.5
                        color: model.strength >= 70 ? (model.active ? "#30d158" : "#d1d1d6") : "#3a3a3c"
                    }
                }
                Text {
                    anchors.left: signalIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: model.known ? 50 : 17
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !wifiRow.editing
                    text: model.ssid
                    color: model.active ? "#f5f5f7" : "#e5e5ea"
                    font.pixelSize: 14
                    font.weight: model.active ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }
                MouseArea {
                    z: 1
                    anchors.fill: parent
                    enabled: !wifiRow.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectWifi(model.ssid, model.security, model.known, model.uuid)
                }
                Item {
                    z: 2
                    anchors.left: signalIcon.right
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    visible: wifiRow.editing
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "#1c1c1e"
                        border.width: 1
                        border.color: passwordInput.activeFocus ? "#5a5a60" : "#2c2c2e"
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length === 0
                        text: "Password"
                        color: "#636366"
                        font.pixelSize: 13
                    }
                    TextInput {
                        id: passwordInput
                        anchors.left: parent.left
                        anchors.right: submitPassword.left
                        anchors.leftMargin: 10
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#f5f5f7"
                        font.pixelSize: 13
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        selectionColor: "#48484a"
                        selectedTextColor: "white"
                        clip: true
                        Keys.onReturnPressed: { root.submitWifiPassword(model.ssid, text); text = "" }
                        Keys.onEnterPressed: { root.submitWifiPassword(model.ssid, text); text = "" }
                    }
                    Text {
                        id: submitPassword
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↵"
                        color: "#b8b8bd"
                        font.pixelSize: 15
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -7
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.submitWifiPassword(model.ssid, passwordInput.text); passwordInput.text = "" }
                        }
                    }
                }
                Text {
                    z: 3
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: model.known && !wifiRow.editing
                    text: "×"
                    color: forgetWifiMouse.containsMouse ? "#b8b8bd" : "#636366"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    MouseArea {
                        id: forgetWifiMouse
                        anchors.fill: parent
                        anchors.margins: -9
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.forgetWifi(model.uuid)
                    }
                }
                HoverHandler { id: rowHover }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: controls.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: root.panelType === "bluetooth"
        clip: true

        Text {
            anchors.centerIn: parent
            visible: !root.bluetoothPowered
            text: root.airplaneMode ? "Airplane mode" : "Bluetooth is off"
            color: "#636366"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        ListView {
            id: bluetoothList
            anchors.fill: parent
            visible: root.bluetoothPowered
            clip: true
            model: bluetoothModel
            spacing: 2
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            flickDeceleration: 3000
            maximumFlickVelocity: 4300
            rebound: Transition {
                NumberAnimation { properties: "x,y"; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.2 }
            }
            add: Transition {
                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 170; easing.type: Easing.OutBack }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: btRow
                width: bluetoothList.width
                height: 46
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: btHover.hovered ? "#161618" : "transparent"
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: model.connected ? "#30d158" : model.paired ? "#8e8e93" : "#48484a"
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 35
                    anchors.right: parent.right
                    anchors.rightMargin: model.paired ? 52 : 16
                    anchors.top: parent.top
                    anchors.topMargin: model.connected || model.paired ? 7 : 14
                    text: model.deviceName
                    color: "#e5e5ea"
                    font.pixelSize: 14
                    font.weight: model.connected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 35
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: model.connected || model.paired
                    text: model.connected ? "Connected" : "Paired"
                    color: model.connected ? "#30d158" : "#636366"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                MouseArea {
                    z: 1
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectBluetooth(model.address, model.paired, model.connected)
                }
                Text {
                    z: 3
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: model.paired
                    text: "×"
                    color: forgetBtMouse.containsMouse ? "#b8b8bd" : "#636366"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    MouseArea {
                        id: forgetBtMouse
                        anchors.fill: parent
                        anchors.margins: -9
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.forgetBluetooth(model.address)
                    }
                }
                HoverHandler { id: btHover }
            }
        }
    }

    Timer {
        interval: root.panelType === "bluetooth" ? 900 : 2200
        repeat: true
        running: root.active
        onTriggered: root.refreshCurrent(false)
    }

    Process {
        id: airplaneProbe
        command: [
            "bash", "-lc",
            "command -v rfkill >/dev/null 2>&1 || { printf 'unavailable\\nunblocked\\n'; exit 0; }; read total blocked <<<\"$(rfkill -n -o SOFT 2>/dev/null | awk '{t++; if ($1 == \\\"blocked\\\") b++} END {print t+0, b+0}')\"; if [ \"$total\" -gt 0 ]; then printf 'available\\n'; [ \"$blocked\" -eq \"$total\" ] && printf 'blocked\\n' || printf 'unblocked\\n'; else printf 'unavailable\\nunblocked\\n'; fi"
        ]
        stdout: StdioCollector { onStreamFinished: root.consumeAirplane(text) }
    }
    Process {
        id: wifiListProbe
        stdout: StdioCollector { onStreamFinished: root.consumeWifiList(text) }
    }
    Process {
        id: wifiAction
        onRunningChanged: if (!running) {
            environment = ({})
            root.wifiPasswordSsid = ""
            root.refreshWifi(false)
            root.statusRefreshRequested()
        }
    }
    Process {
        id: wifiForget
        onRunningChanged: if (!running) {
            root.refreshWifi(true)
            root.statusRefreshRequested()
        }
    }
    Process {
        id: bluetoothListProbe
        command: [
            "bash", "-lc",
            "command -v bluetoothctl >/dev/null 2>&1 || exit 0; bluetoothctl devices 2>/dev/null | while read -r tag addr name; do [ \"$tag\" = \"Device\" ] || continue; info=$(bluetoothctl info \"$addr\" 2>/dev/null); paired=$(printf '%s\\n' \"$info\" | awk '/Paired:/ {print $2; exit}'); connected=$(printf '%s\\n' \"$info\" | awk '/Connected:/ {print $2; exit}'); trusted=$(printf '%s\\n' \"$info\" | awk '/Trusted:/ {print $2; exit}'); printf 'D\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$addr\" \"${paired:-no}\" \"${connected:-no}\" \"${trusted:-no}\" \"$name\"; done"
        ]
        stdout: StdioCollector { onStreamFinished: root.consumeBluetoothList(text) }
    }
    Process {
        id: bluetoothScan
        command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
        onRunningChanged: if (!running) root.refreshBluetooth(false)
    }
    Process {
        id: bluetoothAction
        onRunningChanged: if (!running) {
            environment = ({})
            root.refreshBluetooth(false)
            root.statusRefreshRequested()
        }
    }
    Process {
        id: bluetoothForget
        onRunningChanged: if (!running) {
            root.refreshBluetooth(true)
            root.statusRefreshRequested()
        }
    }
    Process {
        id: radioAction
        onRunningChanged: if (!running) {
            root.refreshAirplane()
            root.statusRefreshRequested()
            root.refreshCurrent(true)
        }
    }
    Process {
        id: wifiRadioAction
        onRunningChanged: if (!running) {
            root.refreshAirplane()
            root.statusRefreshRequested()
            root.refreshWifi(true)
        }
    }
    Process {
        id: bluetoothRadioAction
        onRunningChanged: if (!running) {
            root.refreshAirplane()
            root.statusRefreshRequested()
            root.refreshBluetooth(true)
        }
    }
}
