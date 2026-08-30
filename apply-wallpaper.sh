#!/usr/bin/env bash

set -u

WALLPAPER="${1:-}"
if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    printf 'ERROR\tWallpaper does not exist\n'
    exit 2
fi

WALLPAPER="$(readlink -f -- "$WALLPAPER")"
EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"

if [[ "$EXT" != "jpg" && "$EXT" != "png" ]]; then
    printf 'ERROR\tOnly .jpg and .png are supported\n'
    exit 2
fi

root_rc=1
ROOT_HELPER="/usr/local/libexec/notch-wallpaper-root"

# Deliberately never invoke pkexec or interactive sudo from the picker.
# setup-no-password.sh installs a narrowly scoped NOPASSWD helper once.
if (( EUID == 0 )); then
    root_rc=0
elif [[ -x "$ROOT_HELPER" ]] && command -v sudo >/dev/null 2>&1; then
    sudo -n "$ROOT_HELPER" "$WALLPAPER" >/dev/null 2>&1 && root_rc=0
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
