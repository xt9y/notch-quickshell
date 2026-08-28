import QtQuick
import Quickshell.Io

Item {
    id: root

    property var player: null
    property url preferredSource: ""
    property url resolvedSource: ""
    property string rawUrl: player && player.trackArtUrl
        ? player.trackArtUrl.toString()
        : ""
    property string requestKey: preferredSource.toString() + "\u241f" + rawUrl

    width: 0
    height: 0
    visible: false

    // This component is instantiated for the lifetime of the notch, so it is
    // also a stable home for the non-visual PipeWire/Bluetooth handoff watcher.
    AudioRecovery { }

    onRequestKeyChanged: Qt.callLater(root.refresh)
    Component.onCompleted: Qt.callLater(root.refresh)

    function refresh() {
        var preferred = preferredSource.toString()
        if (preferred !== "") {
            resolvedSource = preferredSource
            return
        }

        var raw = rawUrl
        if (raw === "") {
            resolvedSource = ""
            return
        }

        if (raw.indexOf("http://") === 0 || raw.indexOf("https://") === 0)
            resolvedSource = raw
        else
            resolvedSource = ""

        if (loader.running)
            loader.running = false

        loader.environment = ({ ART_URL: raw })
        loader.running = true
    }

    Process {
        id: loader
        command: [
            "bash",
            "-lc",
            "set -e; " +
            "url=\"$ART_URL\"; [ -n \"$url\" ] || exit 0; " +
            "dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell/art\"; mkdir -p \"$dir\"; " +
            "key=$(printf '%s' \"$url\" | sha256sum | cut -d' ' -f1); " +
            "for ext in jpg jpeg png webp gif bmp avif img; do out=\"$dir/$key.$ext\"; if [ -s \"$out\" ]; then printf 'file://%s' \"$out\"; exit 0; fi; done; " +
            "tmp=\"$dir/$key.tmp.$$\"; " +
            "case \"$url\" in " +
            "http://*|https://*) command -v curl >/dev/null 2>&1 || exit 0; curl -LfsS --max-time 8 \"$url\" -o \"$tmp\" ;; " +
            "file://*) if command -v python3 >/dev/null 2>&1; then src=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' \"$url\"); else src=\"${url#file://}\"; fi; [ -r \"$src\" ] || exit 0; cp -f -- \"$src\" \"$tmp\" ;; " +
            "/*) [ -r \"$url\" ] || exit 0; cp -f -- \"$url\" \"$tmp\" ;; " +
            "*) exit 0 ;; esac; " +
            "[ -s \"$tmp\" ] || { rm -f \"$tmp\"; exit 0; }; " +
            "mime=$(file -Lb --mime-type \"$tmp\" 2>/dev/null || true); " +
            "case \"$mime\" in image/jpeg) ext=jpg ;; image/png) ext=png ;; image/webp) ext=webp ;; image/gif) ext=gif ;; image/bmp) ext=bmp ;; image/avif) ext=avif ;; image/*) ext=img ;; *) ext=img ;; esac; " +
            "out=\"$dir/$key.$ext\"; mv -f \"$tmp\" \"$out\"; printf 'file://%s' \"$out\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var cached = text.trim()
                if (cached !== "")
                    root.resolvedSource = cached
            }
        }

        onRunningChanged: {
            if (!running)
                environment = ({})
        }
    }
}
