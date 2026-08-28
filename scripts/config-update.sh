#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$HOME/.config/quickshell/notch}"

cd "$repo_root"
git pull --ff-only
qs -c notch
