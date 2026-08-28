#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
source_config="$repo_root/hypr/hyprland.lua"
source_kitty="$repo_root/kitty/kitty.conf"
hyprpaper_template="$repo_root/hypr/hyprpaper.conf.in"
wallpaper_dir="$repo_root/wallpaper"
alias_file="$repo_root/shell/notch-aliases.sh"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

hypr_dir="$config_home/hypr"
target_config="$hypr_dir/hyprland.lua"
backup_config="$hypr_dir/hyprland.lua.notch-backup"
target_hyprpaper="$hypr_dir/hyprpaper.conf"
backup_hyprpaper="$hypr_dir/hyprpaper.conf.notch-backup"

kitty_dir="$config_home/kitty"
target_kitty="$kitty_dir/kitty.conf"
backup_kitty="$kitty_dir/kitty.conf.notch-backup"

if [[ ! -f "$source_config" ]]; then
    echo "notch-quickshell: missing $source_config" >&2
    exit 1
fi

link_managed_file() {
    local source_file="$1"
    local target_file="$2"
    local backup_file="$3"
    local label="$4"

    mkdir -p "$(dirname "$target_file")"

    local desired_target
    desired_target="$(readlink -f "$source_file")"

    local current_target=""
    if [[ -L "$target_file" ]]; then
        current_target="$(readlink -f "$target_file" 2>/dev/null || true)"
    fi

    if [[ "$current_target" != "$desired_target" ]]; then
        if [[ -e "$target_file" || -L "$target_file" ]]; then
            if [[ ! -e "$backup_file" && ! -L "$backup_file" ]]; then
                cp -aL "$target_file" "$backup_file"
                echo "notch-quickshell: backed up existing $label to $backup_file"
            fi
            rm -f "$target_file"
        fi

        ln -s "$source_file" "$target_file"
        echo "notch-quickshell: $label now points to $source_file"
    fi
}

link_managed_file "$source_config" "$target_config" "$backup_config" "Hyprland config"

if [[ -f "$source_kitty" ]]; then
    link_managed_file "$source_kitty" "$target_kitty" "$backup_kitty" "Kitty config"
fi

# Optional wallpaper support. No fixed filename is required: use the first
# supported image in wallpaper/ sorted by filename.
wallpaper_file=""
if [[ -d "$wallpaper_dir" ]]; then
    wallpaper_file="$(find "$wallpaper_dir" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
    \) -print | sort | head -n 1 || true)"
fi

hyprpaper_managed=false
if [[ -f "$target_hyprpaper" ]] && grep -Fq '# Managed by xt9y/notch-quickshell.' "$target_hyprpaper"; then
    hyprpaper_managed=true
fi

if [[ -n "$wallpaper_file" && -f "$hyprpaper_template" ]]; then
    mkdir -p "$hypr_dir"

    if [[ -e "$target_hyprpaper" || -L "$target_hyprpaper" ]]; then
        if [[ "$hyprpaper_managed" == false && ! -e "$backup_hyprpaper" && ! -L "$backup_hyprpaper" ]]; then
            cp -aL "$target_hyprpaper" "$backup_hyprpaper"
            echo "notch-quickshell: backed up existing hyprpaper config to $backup_hyprpaper"
        fi
        rm -f "$target_hyprpaper"
    fi

    escaped_wallpaper="${wallpaper_file//\\/\\\\}"
    escaped_wallpaper="${escaped_wallpaper//&/\\&}"
    escaped_wallpaper="${escaped_wallpaper//|/\\|}"
    sed "s|__WALLPAPER__|$escaped_wallpaper|g" "$hyprpaper_template" > "$target_hyprpaper"
    echo "notch-quickshell: wallpaper set to $wallpaper_file"

    if command -v hyprpaper >/dev/null 2>&1; then
        pkill -x hyprpaper >/dev/null 2>&1 || true
        setsid -f hyprpaper >/dev/null 2>&1 || true
    else
        echo "notch-quickshell: wallpaper found, but hyprpaper is not installed" >&2
    fi
elif [[ "$hyprpaper_managed" == true ]]; then
    # The repo wallpaper was removed. Stop using the stale generated config and
    # restore the user's previous hyprpaper config when one was backed up.
    rm -f "$target_hyprpaper"
    if [[ -e "$backup_hyprpaper" || -L "$backup_hyprpaper" ]]; then
        cp -aL "$backup_hyprpaper" "$target_hyprpaper"
        echo "notch-quickshell: restored previous hyprpaper config"
        if command -v hyprpaper >/dev/null 2>&1; then
            pkill -x hyprpaper >/dev/null 2>&1 || true
            setsid -f hyprpaper >/dev/null 2>&1 || true
        fi
    else
        pkill -x hyprpaper >/dev/null 2>&1 || true
        echo "notch-quickshell: repo wallpaper removed; hyprpaper disabled"
    fi
fi

# Keep shell helpers in the repo as well. The rc file only contains one stable
# source line, so changing shell/notch-aliases.sh in a future git pull updates
# the aliases without rewriting ~/.bashrc again.
if [[ -f "$alias_file" ]]; then
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        zsh) rc_file="$HOME/.zshrc" ;;
        *)   rc_file="$HOME/.bashrc" ;;
    esac

    touch "$rc_file"
    source_line='[[ -f "$HOME/.config/quickshell/notch/shell/notch-aliases.sh" ]] && source "$HOME/.config/quickshell/notch/shell/notch-aliases.sh"'

    if ! grep -Fqx "$source_line" "$rc_file"; then
        printf '\n# notch-quickshell helpers\n%s\n' "$source_line" >> "$rc_file"
        echo "notch-quickshell: installed config-update alias in $rc_file"
    fi
fi

# Hyprland already watches its config, but force a reload here so a freshly
# installed symlink is applied immediately. This is harmless on later runs.
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
