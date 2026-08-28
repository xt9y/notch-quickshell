#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
source_config="$repo_root/hypr/hyprland.lua"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
target_config="$hypr_dir/hyprland.lua"
backup_config="$hypr_dir/hyprland.lua.notch-backup"

if [[ ! -f "$source_config" ]]; then
    echo "notch-quickshell: missing $source_config" >&2
    exit 1
fi

mkdir -p "$hypr_dir"

desired_target="$(readlink -f "$source_config")"
current_target=""
if [[ -L "$target_config" ]]; then
    current_target="$(readlink -f "$target_config" 2>/dev/null || true)"
fi

if [[ "$current_target" != "$desired_target" ]]; then
    if [[ -e "$target_config" || -L "$target_config" ]]; then
        if [[ ! -e "$backup_config" && ! -L "$backup_config" ]]; then
            cp -aL "$target_config" "$backup_config"
            echo "notch-quickshell: backed up existing Hyprland config to $backup_config"
        fi
        rm -f "$target_config"
    fi

    ln -s "$source_config" "$target_config"
    echo "notch-quickshell: Hyprland config now points to $source_config"
fi

# Hyprland already watches its config, but force a reload here so a freshly
# installed symlink is applied immediately. This is harmless on later runs.
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
