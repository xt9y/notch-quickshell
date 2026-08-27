#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
git pull --ff-only

echo "Updated notch-quickshell. Quickshell watches this config and should reload it automatically."
echo "If it does not, restart only Quickshell with: qs -c notch"
