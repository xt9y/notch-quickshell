#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
bin_home="$HOME/.local/bin"
shortcut_rc="$config_home/kglobalshortcutsrc"

if ! command -v wpctl >/dev/null 2>&1; then
    if command -v dnf >/dev/null 2>&1; then
        echo "notch-quickshell: installing wpctl (WirePlumber)"
        sudo dnf install -y wireplumber
    else
        echo "notch-quickshell: wpctl is required but was not found" >&2
        exit 1
    fi
fi

mkdir -p "$config_home/autostart"
cp "$repo_root/plasma/notch-quickshell.desktop" \
   "$config_home/autostart/notch-quickshell.desktop"
chmod 0644 "$config_home/autostart/notch-quickshell.desktop"

# Volume Up/Down are intentionally one-percent steps. Plasma/KGlobalAccel
# repeats the launcher while the media key is held, producing a constant linear
# ramp. Every action also touches volume-event so the notch reacts immediately.
mkdir -p "$bin_home" "$cache_home/notch-quickshell"
: > "$cache_home/notch-quickshell/volume-event"

cat > "$bin_home/notch-volume-up" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 1%+
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
mkdir -p "$cache_dir"
printf 'up %s\n' "$(date +%s%N)" > "$cache_dir/volume-event"
EOF

cat > "$bin_home/notch-volume-down" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 1%-
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
mkdir -p "$cache_dir"
printf 'down %s\n' "$(date +%s%N)" > "$cache_dir/volume-event"
EOF

cat > "$bin_home/notch-volume-mute" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
mkdir -p "$cache_dir"
stamp="$cache_dir/mute-last"
now_ms=$(( $(date +%s%N) / 1000000 ))
last_ms=0
[[ -r "$stamp" ]] && read -r last_ms < "$stamp" || true
# Prevent a held mute key from rapidly toggling on/off, while ordinary presses
# remain responsive.
if (( now_ms - last_ms < 350 )); then
    exit 0
fi
printf '%s\n' "$now_ms" > "$stamp"
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
printf 'mute %s\n' "$(date +%s%N)" > "$cache_dir/volume-event"
EOF

chmod 0755 \
    "$bin_home/notch-volume-up" \
    "$bin_home/notch-volume-down" \
    "$bin_home/notch-volume-mute"

kglobal_dir="$data_home/kglobalaccel"
mkdir -p "$kglobal_dir"

cat > "$kglobal_dir/notch-volume-up.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Notch Volume Up
Exec="$bin_home/notch-volume-up"
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF

cat > "$kglobal_dir/notch-volume-down.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Notch Volume Down
Exec="$bin_home/notch-volume-down"
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF

cat > "$kglobal_dir/notch-volume-mute.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Notch Volume Mute
Exec="$bin_home/notch-volume-mute"
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF

chmod 0644 \
    "$kglobal_dir/notch-volume-up.desktop" \
    "$kglobal_dir/notch-volume-down.desktop" \
    "$kglobal_dir/notch-volume-mute.desktop"

remove_shortcut_group() {
    local group="$1"
    [[ -f "$shortcut_rc" ]] || return 0

    local tmp
    tmp="$(mktemp)"
    awk -v wanted="[$group]" '
        /^\[/ { skip = ($0 == wanted) }
        !skip { print }
    ' "$shortcut_rc" > "$tmp"
    mv "$tmp" "$shortcut_rc"
}

for shortcut_dir in "$data_home/kglobalaccel" "$data_home/applications"; do
    [[ -d "$shortcut_dir" ]] || continue
    while IFS= read -r -d '' desktop; do
        case "$(basename "$desktop")" in
            notch-volume-up.desktop|notch-volume-down.desktop|notch-volume-mute.desktop)
                continue
                ;;
        esac

        if grep -Eq '^Exec=.*wpctl[[:space:]]+(set-volume|set-mute).*@DEFAULT_AUDIO_SINK@' "$desktop"; then
            old_group="$(basename "$desktop")"
            rm -f "$desktop"
            remove_shortcut_group "$old_group"
            echo "notch-quickshell: removed old volume shortcut $old_group"
        fi
    done < <(find "$shortcut_dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
done

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "$shortcut_rc" --group kmix \
        --key increase_volume 'none,Volume Up,Increase Volume'
    kwriteconfig6 --file "$shortcut_rc" --group kmix \
        --key decrease_volume 'none,Volume Down,Decrease Volume'
    kwriteconfig6 --file "$shortcut_rc" --group kmix \
        --key mute 'none,Volume Mute,Mute'

    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-up.desktop \
        --key _k_friendly_name 'Notch Volume Up'
    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-up.desktop \
        --key _launch 'Volume Up,Volume Up,Notch Volume Up'

    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-down.desktop \
        --key _k_friendly_name 'Notch Volume Down'
    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-down.desktop \
        --key _launch 'Volume Down,Volume Down,Notch Volume Down'

    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-mute.desktop \
        --key _k_friendly_name 'Notch Volume Mute'
    kwriteconfig6 --file "$shortcut_rc" --group notch-volume-mute.desktop \
        --key _launch 'Volume Mute,Volume Mute,Notch Volume Mute'
else
    echo "notch-quickshell: kwriteconfig6 missing; volume shortcuts were not registered" >&2
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
elif command -v dbus-send >/dev/null 2>&1; then
    dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure \
        >/dev/null 2>&1 || true
fi

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc_file" ]]; then
        sed -i \
            -e '\|^# notch-quickshell helpers$|d' \
            -e '\|notch-aliases\.sh|d' \
            -e '\|alias config-update=.*scripts/config-update\.sh|d' \
            "$rc_file"
    fi
done

kitty_config="$config_home/kitty/kitty.conf"
kitty_backup="$config_home/kitty/kitty.conf.notch-backup"
if [[ -L "$kitty_config" ]]; then
    link_target="$(readlink "$kitty_config" || true)"
    if [[ "$link_target" == *"notch-quickshell/kitty/kitty.conf"* || \
          "$link_target" == *"quickshell/notch/kitty/kitty.conf"* ]]; then
        rm -f "$kitty_config"
        if [[ -e "$kitty_backup" || -L "$kitty_backup" ]]; then
            cp -aL "$kitty_backup" "$kitty_config"
            echo "notch-quickshell: restored previous Kitty config"
        fi
    fi
fi

echo "notch-quickshell: Plasma autostart and volume shortcuts installed"
