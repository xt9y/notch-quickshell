#!/usr/bin/env bash
set -u

# Install/load the official Hyprland hyprbars plugin on demand.
# Plugin setup is best-effort so a plugin failure never prevents the rest of
# the desktop configuration from being applied.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
log_file="$cache_dir/hyprbars.log"
mkdir -p "$cache_dir"

# Start each setup attempt with a small readable header while preserving older
# failures below it for debugging.
printf '\n===== hyprbars setup %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"

log() {
    printf '%s\n' "$*" >> "$log_file"
}

run_logged() {
    log "+ $*"
    "$@" >> "$log_file" 2>&1
}

# hyprpm add always asks for confirmation, even for the official plugin repo.
# config-update runs detached, so explicitly provide that confirmation and cap
# the build time so a startup update can never wait forever for stdin/network.
run_logged_confirmed() {
    log "+ $* [auto-confirmed]"
    timeout 15m "$@" <<< "y" >> "$log_file" 2>&1
}

if ! command -v hyprpm >/dev/null 2>&1; then
    log "hyprbars: hyprpm is not installed"
    exit 0
fi

# Fedora's Hyprland packages use the matching system development headers for
# hyprpm. The lionheartp COPR provides these as hyprland-devel (or
# hyprland-git-devel when using the git package).
if command -v rpm >/dev/null 2>&1; then
    if ! rpm -q hyprland-devel >/dev/null 2>&1 && ! rpm -q hyprland-git-devel >/dev/null 2>&1; then
        log "hyprbars: missing matching Fedora Hyprland development headers"
        log "hyprbars: install once with: sudo dnf install hyprland-devel"
        exit 0
    fi
fi

# Nothing to do when this Hyprland process already has hyprbars loaded.
if command -v hyprctl >/dev/null 2>&1 && hyprctl plugins list 2>/dev/null | grep -qi 'hyprbars'; then
    log "hyprbars: already loaded"
    exit 0
fi

# Always refresh headers before touching plugin state. This is important after
# every Hyprland package upgrade; merely having the repository registered does
# not mean its cached headers match the currently running compositor.
log "hyprbars: refreshing Hyprland headers and plugin metadata"
if ! run_logged hyprpm update; then
    log "hyprbars: normal update failed; purging stale hyprpm cache"

    # Newer hyprpm versions expose purge-cache specifically for broken/stale
    # header state. Ignore the command when an older build does not support it.
    run_logged hyprpm purge-cache || true

    log "hyprbars: retrying forced header/plugin update"
    run_logged hyprpm update -f || true
fi

installed="$(hyprpm list 2>>"$log_file" || true)"
if ! grep -qi 'hyprbars' <<< "$installed"; then
    log "hyprbars: adding official hyprland-plugins repository"
    if ! run_logged_confirmed hyprpm add https://github.com/hyprwm/hyprland-plugins; then
        log "hyprbars: repository add failed or timed out"
    fi

    # A freshly added repository may have been built against newly established
    # headers. Force one final metadata/build pass before enabling it.
    run_logged hyprpm update -f || true
fi

log "hyprbars: enabling plugin"
run_logged hyprpm enable hyprbars || true
run_logged hyprpm reload || true

if command -v hyprctl >/dev/null 2>&1 && hyprctl plugins list 2>/dev/null | grep -qi 'hyprbars'; then
    log "hyprbars: loaded successfully"
else
    log "hyprbars: FAILED to load"
    log "hyprbars: inspect $log_file"
fi
