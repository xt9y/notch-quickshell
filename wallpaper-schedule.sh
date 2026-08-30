#!/usr/bin/env bash

set -u

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/notch"
WALLPAPER_DIR="$CONFIG_DIR/wallpaper"
SCHEDULE_FILE="$CONFIG_DIR/wallpaper-schedule"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/notch-quickshell"
ACTIVE_FILE="$CACHE_DIR/scheduled-wallpaper"
APPLY_HELPER="$CONFIG_DIR/apply-wallpaper.sh"

# Local-time phases. Multiple wallpapers assigned to a phase divide it evenly.
DAY_START_MINUTE=$((7 * 60))
NIGHT_START_MINUTE=$((19 * 60))
PHASE_LENGTH_MINUTE=$((12 * 60))

mkdir -p "$WALLPAPER_DIR" "$CACHE_DIR"
touch "$SCHEDULE_FILE"

canonical_wallpaper() {
    local input="${1:-}"
    local path dir ext

    [[ -n "$input" && -f "$input" ]] || return 1
    path="$(readlink -f -- "$input")" || return 1
    dir="$(readlink -f -- "$WALLPAPER_DIR")" || return 1
    [[ "$(dirname -- "$path")" == "$dir" ]] || return 1

    ext="${path##*.}"
    ext="${ext,,}"
    [[ "$ext" == "jpg" || "$ext" == "png" ]] || return 1
    printf '%s' "$path"
}

state_for() {
    local path="$1"
    awk -F '\t' -v path="$path" '$2 == path && ($1 == "day" || $1 == "night") { print $1; exit }' "$SCHEDULE_FILE"
}

rewrite_state() {
    local path="$1"
    local state="$2"
    local tmp

    tmp="$(mktemp "$CONFIG_DIR/wallpaper-schedule.XXXXXX")" || return 1
    awk -F '\t' -v path="$path" '$2 != path && ($1 == "day" || $1 == "night") { print $0 }' \
        "$SCHEDULE_FILE" > "$tmp"

    if [[ "$state" == "day" || "$state" == "night" ]]; then
        printf '%s\t%s\n' "$state" "$path" >> "$tmp"
    fi

    mv -f -- "$tmp" "$SCHEDULE_FILE"
}

list_wallpapers() {
    while IFS= read -r path; do
        local state
        state="$(state_for "$path")"
        [[ -n "$state" ]] || state="none"
        printf '%s\t%s\t%s\n' "$(basename -- "$path")" "$path" "$state"
    done < <(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.png' \) -print 2>/dev/null | sort -f
    )
}

cycle_wallpaper() {
    local path current next
    path="$(canonical_wallpaper "${1:-}")" || {
        printf 'ERROR\tInvalid wallpaper\n'
        return 2
    }

    current="$(state_for "$path")"
    case "$current" in
        day) next="night" ;;
        night) next="none" ;;
        *) next="day" ;;
    esac

    rewrite_state "$path" "$next" || {
        printf 'ERROR\tCould not save wallpaper assignment\n'
        return 1
    }

    printf 'STATE\t%s\t%s\n' "$path" "$next"
}

phase_info() {
    local now_minute phase elapsed
    now_minute=$((10#$(date +%H) * 60 + 10#$(date +%M)))

    if (( now_minute >= DAY_START_MINUTE && now_minute < NIGHT_START_MINUTE )); then
        phase="day"
        elapsed=$((now_minute - DAY_START_MINUTE))
    else
        phase="night"
        if (( now_minute >= NIGHT_START_MINUTE )); then
            elapsed=$((now_minute - NIGHT_START_MINUTE))
        else
            elapsed=$(((24 * 60 - NIGHT_START_MINUTE) + now_minute))
        fi
    fi

    printf '%s\t%s\n' "$phase" "$elapsed"
}

apply_current() {
    local info phase elapsed
    local -a candidates=()
    local state path count index desired cached_path cached_status result result_status

    info="$(phase_info)"
    phase="${info%%$'\t'*}"
    elapsed="${info#*$'\t'}"

    while IFS=$'\t' read -r state path; do
        [[ "$state" == "$phase" ]] || continue
        path="$(canonical_wallpaper "$path" 2>/dev/null || true)"
        [[ -n "$path" ]] && candidates+=("$path")
    done < <(sort -f -t $'\t' -k2,2 "$SCHEDULE_FILE")

    count=${#candidates[@]}
    if (( count == 0 )); then
        printf 'NONE\t%s\n' "$phase"
        return 0
    fi

    # One item naturally maps to the entire 12-hour phase. More items split
    # the phase into equal contiguous slots.
    index=$((elapsed * count / PHASE_LENGTH_MINUTE))
    (( index >= count )) && index=$((count - 1))
    desired="${candidates[$index]}"

    cached_path=""
    cached_status=""
    if [[ -r "$ACTIVE_FILE" ]]; then
        IFS=$'\t' read -r cached_path cached_status < "$ACTIVE_FILE" || true
    fi

    if [[ "$cached_path" == "$desired" && "$cached_status" == "OK" ]]; then
        printf 'ACTIVE\t%s\t%s\tOK\n' "$desired" "$phase"
        return 0
    fi

    [[ -r "$APPLY_HELPER" ]] || {
        printf 'ERROR\tWallpaper apply helper missing\n'
        return 1
    }

    result="$(bash "$APPLY_HELPER" "$desired" 2>/dev/null || true)"
    result_status="${result%%$'\t'*}"

    if [[ "$result_status" != "OK" && "$result_status" != "PARTIAL" ]]; then
        printf 'ERROR\tCould not apply scheduled wallpaper\n'
        return 1
    fi

    printf '%s\t%s\n' "$desired" "$result_status" > "$ACTIVE_FILE"
    printf 'ACTIVE\t%s\t%s\t%s\n' "$desired" "$phase" "$result_status"
}

case "${1:-}" in
    list)
        list_wallpapers
        ;;
    cycle)
        cycle_wallpaper "${2:-}"
        ;;
    apply-current)
        apply_current
        ;;
    phase)
        phase_info
        ;;
    *)
        echo "usage: $0 {list|cycle <wallpaper>|apply-current|phase}" >&2
        exit 2
        ;;
esac
