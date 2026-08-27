#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
git pull --ff-only

echo "Updated notch-quickshell. A running Quickshell instance watches this config and reloads changed files automatically."
