#!/usr/bin/env bash

set -u

ROOT_MODE=0
if [[ "${1:-}" == "--root" ]]; then
    ROOT_MODE=1
    shift
fi

WALLPAPER="${1:-}"
if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    printf 'ERROR\tWallpaper does not exist\n'
    exit 2
fi

WALLPAPER="$(readlink -f -- "$WALLPAPER")"
NAME="$(basename -- "$WALLPAPER")"
DEST="/var/lib/plasmalogin/wallpapers/login-wallpaper${NAME}"

apply_root_parts() {
    local rc=0

    mkdir -p /var/lib/plasmalogin/wallpapers || rc=1
    cp -- "$WALLPAPER" "$DEST" || rc=1

    if [[ -f /etc/plasmalogin.conf ]]; then
        sed -i "s|Image=.*|Image=file://${DEST}|" /etc/plasmalogin.conf || rc=1
    else
        rc=1
    fi

    mkdir -p /usr/local/share/wallpapers || rc=1
    cp -- "$WALLPAPER" /usr/local/share/wallpapers/login-wallpaper.jpg || rc=1

    return "$rc"
}

if (( ROOT_MODE )); then
    apply_root_parts
    exit $?
fi

root_rc=1
if (( EUID == 0 )); then
    apply_root_parts && root_rc=0
elif command -v pkexec >/dev/null 2>&1; then
    pkexec bash "$0" --root "$WALLPAPER" && root_rc=0
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n bash "$0" --root "$WALLPAPER" && root_rc=0
fi

lock_rc=0
LOCK_CONFIG="${HOME}/.config/kscreenlockerrc"
if [[ -f "$LOCK_CONFIG" ]]; then
    sed -i 's|Image=file://.*|Image=file:///usr/local/share/wallpapers/login-wallpaper.jpg|' "$LOCK_CONFIG" || lock_rc=1
    sed -i 's|PreviewImage=file://.*|PreviewImage=file:///usr/local/share/wallpapers/login-wallpaper.jpg|' "$LOCK_CONFIG" || lock_rc=1
else
    lock_rc=1
fi

desktop_rc=0
if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER" >/dev/null 2>&1 || desktop_rc=1
else
    desktop_rc=1
fi

if (( root_rc == 0 && lock_rc == 0 && desktop_rc == 0 )); then
    printf 'OK\t%s\n' "$WALLPAPER"
    exit 0
fi

if (( desktop_rc == 0 )); then
    printf 'PARTIAL\t%s\n' "$WALLPAPER"
    exit 0
fi

printf 'ERROR\tCould not apply wallpaper\n'
exit 1
