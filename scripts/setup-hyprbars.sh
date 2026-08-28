#!/usr/bin/env bash
set -u

# Install/load the official Hyprland hyprbars plugin on demand.
# This is intentionally best-effort: a plugin build failure must never prevent
# the rest of the desktop config from being applied.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
log_file="$cache_dir/hyprbars.log"
mkdir -p "$cache_dir"

log() {
    printf '%s\n' "$*" >> "$log_file"
}

if ! command -v hyprpm >/dev/null 2>&1; then
    log "hyprbars: hyprpm is not installed"
    exit 0
fi

# Nothing to do when this Hyprland process already has hyprbars loaded.
if command -v hyprctl >/dev/null 2>&1 && hyprctl plugins list 2>/dev/null | grep -qi 'hyprbars'; then
    exit 0
fi

# hyprpm is the officially supported installation path. Only hit the network
# when hyprbars is not already present in hyprpm's local plugin database.
installed="$(hyprpm list 2>/dev/null || true)"
if ! grep -qi 'hyprbars' <<< "$installed"; then
    log "hyprbars: refreshing Hyprland headers/plugin metadata"
    hyprpm update >> "$log_file" 2>&1 || true

    log "hyprbars: adding official hyprland-plugins repository"
    hyprpm add https://github.com/hyprwm/hyprland-plugins >> "$log_file" 2>&1 || true
fi

# Enabling an already-enabled plugin is harmless. Reloading here makes the
# title bars available before apply-hypr.sh reloads hyprland.lua.
hyprpm enable hyprbars >> "$log_file" 2>&1 || true
hyprpm reload >> "$log_file" 2>&1 || true

if command -v hyprctl >/dev/null 2>&1 && hyprctl plugins list 2>/dev/null | grep -qi 'hyprbars'; then
    log "hyprbars: loaded"
else
    log "hyprbars: not loaded; inspect this log for the hyprpm build error"
fi
