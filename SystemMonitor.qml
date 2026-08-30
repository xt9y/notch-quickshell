import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property int cpuPercent: 0
    property real ramUsedKiB: 0
    property real ramTotalKiB: 0
    property real zramUsedKiB: 0
    property real zramTotalKiB: 0
    property real diskUsedKiB: 0
    property real diskTotalKiB: 0
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property int uptimeSeconds: 0
    property int cpuCores: 1
    property string hostname: "Linux"
    property var processes: []
    property var cpuHistory: []
    property var ramHistory: []
    property var zramHistory: []

    property real ramPercent: ramTotalKiB > 0
        ? Math.max(0, Math.min(100, ramUsedKiB * 100 / ramTotalKiB))
        : 0
    property real zramPercent: zramTotalKiB > 0
        ? Math.max(0, Math.min(100, zramUsedKiB * 100 / zramTotalKiB))
        : 0
    property real diskPercent: diskTotalKiB > 0
        ? Math.max(0, Math.min(100, diskUsedKiB * 100 / diskTotalKiB))
        : 0

    property string helperPath: {
        var uri = Qt.resolvedUrl("system-monitor.sh").toString()
        if (uri.indexOf("file://") === 0)
            return decodeURIComponent(uri.substring(7))
        return uri
    }

    width: 0
    height: 0
    visible: false

    function number(value, fallback) {
        var n = Number(value)
        return isFinite(n) ? n : (fallback === undefined ? 0 : fallback)
    }

    function appendHistory(history, value) {
        var next = history.slice(0)
        next.push(Math.max(0, Math.min(100, value)))
        while (next.length > 56)
            next.shift()
        return next
    }

    function formatBytes(kib) {
        var value = number(kib, 0) * 1024
        if (value >= 1024 * 1024 * 1024)
            return (value / (1024 * 1024 * 1024)).toFixed(value >= 10 * 1024 * 1024 * 1024 ? 1 : 2) + "G"
        if (value >= 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(0) + "M"
        if (value >= 1024)
            return (value / 1024).toFixed(0) + "K"
        return Math.round(value) + "B"
    }

    function uptimeText() {
        var seconds = Math.max(0, uptimeSeconds)
        var days = Math.floor(seconds / 86400)
        var hours = Math.floor((seconds % 86400) / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function consume(raw) {
        var nextProcesses = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i] === "")
                continue
            var p = lines[i].split("\t")
            if (p[0] === "CPU" && p.length >= 2) {
                cpuPercent = Math.round(number(p[1]))
            } else if (p[0] === "RAM" && p.length >= 3) {
                ramUsedKiB = number(p[1])
                ramTotalKiB = number(p[2])
            } else if (p[0] === "ZRAM" && p.length >= 3) {
                zramUsedKiB = number(p[1])
                zramTotalKiB = number(p[2])
            } else if (p[0] === "DISK" && p.length >= 3) {
                diskUsedKiB = number(p[1])
                diskTotalKiB = number(p[2])
            } else if (p[0] === "META" && p.length >= 7) {
                uptimeSeconds = Math.round(number(p[1]))
                load1 = number(p[2])
                load5 = number(p[3])
                load15 = number(p[4])
                cpuCores = Math.max(1, Math.round(number(p[5], 1)))
                hostname = p.slice(6).join(" ")
            } else if (p[0] === "PROC" && p.length >= 5) {
                nextProcesses.push({
                    pid: p[1],
                    cpu: number(p[2]),
                    mem: number(p[3]),
                    name: p.slice(4).join(" ")
                })
            }
        }

        processes = nextProcesses
        cpuHistory = appendHistory(cpuHistory, cpuPercent)
        ramHistory = appendHistory(ramHistory, ramPercent)
        zramHistory = appendHistory(zramHistory, zramPercent)
    }

    function refresh() {
        if (active && !probe.running)
            probe.running = true
    }

    onActiveChanged: if (active)
        Qt.callLater(root.refresh)

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probe
        command: ["bash", root.helperPath]
        stdout: StdioCollector {
            onStreamFinished: root.consume(text)
        }
    }
}
