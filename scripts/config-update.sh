#!/usr/bin/env bash
set -u

repo_root="${1:-$HOME/.config/quickshell/notch}"
cd "$repo_root"

# A missing network connection must never prevent the last-known-good notch
# from starting at Plasma login.
if ! git pull --ff-only; then
    echo "notch-quickshell: git pull failed; starting the local version" >&2
fi

bash "$repo_root/scripts/setup-plasma.sh" "$repo_root"

if ! command -v qs >/dev/null 2>&1; then
    echo "notch-quickshell: Quickshell (qs) is not installed" >&2
    exit 1
fi

exec qs -c notch
