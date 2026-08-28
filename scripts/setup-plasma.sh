#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

source_kitty="$repo_root/kitty/kitty.conf"
autostart_template="$repo_root/plasma/notch-quickshell.desktop.in"

kitty_dir="$config_home/kitty"
target_kitty="$kitty_dir/kitty.conf"
backup_kitty="$kitty_dir/kitty.conf.notch-backup"

autostart_dir="$config_home/autostart"
target_autostart="$autostart_dir/notch-quickshell.desktop"

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

# Preserve the repo-managed Kitty font settings independently of the desktop.
if [[ -f "$source_kitty" ]]; then
    link_managed_file "$source_kitty" "$target_kitty" "$backup_kitty" "Kitty config"
fi

# Remove the legacy config-update shell integration completely. Older versions
# sourced shell/notch-aliases.sh from the user's shell rc file.
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc_file" ]]; then
        sed -i \
            -e '\|^# notch-quickshell helpers$|d' \
            -e '\|notch-aliases\.sh|d' \
            -e '\|alias config-update=.*scripts/config-update\.sh|d' \
            "$rc_file"
    fi
done

# Plasma starts Quickshell directly. There is no updater command or wrapper in
# the login path anymore.
if [[ -f "$autostart_template" ]]; then
    mkdir -p "$autostart_dir"
    cp "$autostart_template" "$target_autostart"
    chmod 0644 "$target_autostart"
fi
