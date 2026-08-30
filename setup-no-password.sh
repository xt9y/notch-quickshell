#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER=""

if [[ "${1:-}" == "--install-for" ]]; then
    TARGET_USER="${2:-}"
fi

if (( EUID != 0 )); then
    TARGET_USER="${TARGET_USER:-${USER:-$(id -un)}}"
    exec sudo bash "$0" --install-for "$TARGET_USER"
fi

if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER="${SUDO_USER:-}"
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    echo "Could not determine desktop user." >&2
    exit 1
fi

id "$TARGET_USER" >/dev/null 2>&1 || {
    echo "Unknown user: $TARGET_USER" >&2
    exit 1
}

install -d -m 0755 /usr/local/libexec
install -o root -g root -m 0755 \
    "$SCRIPT_DIR/notch-wallpaper-root" \
    /usr/local/libexec/notch-wallpaper-root

SAFE_USER="${TARGET_USER//[^A-Za-z0-9_.-]/_}"
SUDOERS_FILE="/etc/sudoers.d/notch-wallpaper-${SAFE_USER}"

printf '%s ALL=(root) NOPASSWD: /usr/local/libexec/notch-wallpaper-root *\n' \
    "$TARGET_USER" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

if ! visudo -cf "$SUDOERS_FILE" >/dev/null; then
    rm -f "$SUDOERS_FILE"
    echo "sudoers validation failed; rule removed" >&2
    exit 1
fi

echo "Installed passwordless notch wallpaper helper for $TARGET_USER."
