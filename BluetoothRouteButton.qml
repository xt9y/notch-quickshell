import QtQuick

Item {
    property bool active: false
    property string deviceName: ""
    signal routeChanged()

    width: 0
    height: 0
    visible: false
    enabled: false
}
