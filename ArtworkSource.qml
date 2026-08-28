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

    AudioRecovery { }

    onRequestKeyChanged: Qt.callLater(root.refresh)
    Component.onCompleted: Qt.callLater(root.refresh)

    function refresh() {
        var raw = rawUrl
        var fallback = preferredSource.toString()

        if (raw === "" && fallback === "") {
            resolvedSource = ""
            return
        }

        // Remote artwork is safe to show immediately. file:// artwork is never
        // handed directly to Image; it is copied to a stable cache first.
        if (raw.indexOf("http://") === 0 || raw.indexOf("https://") === 0)
            resolvedSource = raw
        else
            resolvedSource = ""

        if (loader.running)
            loader.running = false

        loader.environment = ({ ART_URL: raw, ART_FALLBACK: fallback })
        loader.running = true
    }

    Process {
        id: loader
        command: [
            "bash",
            "-lc",
            "set -u; " +
            "primary=\"${ART_URL:-}\"; fallback=\"${ART_FALLBACK:-}\"; " +
            "seed=\"${primary:-$fallback}\"; [ -n \"$seed\" ] || exit 0; " +
            "dir=\"${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell/art\"; mkdir -p \"$dir\"; " +
            "key=$(printf '%s' \"$seed\" | sha256sum | cut -d' ' -f1); " +
            "for ext in jpg jpeg png webp gif bmp avif img; do out=\"$dir/$key.$ext\"; if [ -s \"$out\" ]; then printf 'file://%s' \"$out\"; exit 0; fi; done; " +
            "tmp=\"$dir/$key.tmp.$$\"; " +
            "fetch_one() { u=\"$1\"; [ -n \"$u\" ] || return 1; case \"$u\" in " +
            "http://*|https://*) command -v curl >/dev/null 2>&1 || return 1; curl -LfsS --max-time 8 \"$u\" -o \"$tmp\" ;; " +
            "file://*) if command -v python3 >/dev/null 2>&1; then src=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' \"$u\"); else src=\"${u#file://}\"; fi; [ -r \"$src\" ] || return 1; cp -f -- \"$src\" \"$tmp\" ;; " +
            "/*) [ -r \"$u\" ] || return 1; cp -f -- \"$u\" \"$tmp\" ;; " +
            "*) return 1 ;; esac; }; " +
            "fetch_one \"$primary\" || { rm -f \"$tmp\"; fetch_one \"$fallback\" || { rm -f \"$tmp\"; exit 0; }; }; " +
            "[ -s \"$tmp\" ] || { rm -f \"$tmp\"; exit 0; }; " +
            "mime=$(file -Lb --mime-type \"$tmp\" 2>/dev/null || true); " +
            "case \"$mime\" in image/jpeg) ext=jpg ;; image/png) ext=png ;; image/webp) ext=webp ;; image/gif) ext=gif ;; image/bmp) ext=bmp ;; image/avif) ext=avif ;; *) ext=img ;; esac; " +
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
