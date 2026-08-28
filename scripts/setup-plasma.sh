#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

source_kitty="$repo_root/kitty/kitty.conf"
alias_file="$repo_root/shell/notch-aliases.sh"
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

# Install config-update in the user's interactive shell. The rc file only gets
# one stable source line; the alias itself stays in this repository.
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

# Plasma autostart runs the exact same update path as the config-update alias.
if [[ -f "$autostart_template" ]]; then
    mkdir -p "$autostart_dir"
    escaped_home="${HOME//\\/\\\\}"
    escaped_home="${escaped_home//&/\\&}"
    escaped_home="${escaped_home//|/\\|}"
    sed "s|__HOME__|$escaped_home|g" "$autostart_template" > "$target_autostart"
    chmod 0644 "$target_autostart"
fi
