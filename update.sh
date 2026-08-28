#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
cd "$repo_root"

git pull --ff-only
bash "$repo_root/scripts/setup-plasma.sh" "$repo_root"

echo "Updated notch-quickshell and applied the KDE Plasma integration."
echo "A running Quickshell instance will reload shell.qml automatically."
