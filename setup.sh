#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

# Install Plasma autostart entry.
mkdir -p "$config_home/autostart"
cp "$repo_root/plasma/notch-quickshell.desktop" \
   "$config_home/autostart/notch-quickshell.desktop"
chmod 0644 "$config_home/autostart/notch-quickshell.desktop"

# Clean up legacy config-update shell integration from older revisions.
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc_file" ]]; then
        sed -i \
            -e '\|^# notch-quickshell helpers$|d' \
            -e '\|notch-aliases\.sh|d' \
            -e '\|alias config-update=.*scripts/config-update\.sh|d' \
            "$rc_file"
    fi
done

# Restore the user's previous Kitty config if an older revision still left a
# symlink pointing at this repo's now-removed kitty/kitty.conf.
kitty_config="$config_home/kitty/kitty.conf"
kitty_backup="$config_home/kitty/kitty.conf.notch-backup"
if [[ -L "$kitty_config" ]]; then
    link_target="$(readlink "$kitty_config" || true)"
    if [[ "$link_target" == *"notch-quickshell/kitty/kitty.conf"* || \
          "$link_target" == *"quickshell/notch/kitty/kitty.conf"* ]]; then
        rm -f "$kitty_config"
        if [[ -e "$kitty_backup" || -L "$kitty_backup" ]]; then
            cp -aL "$kitty_backup" "$kitty_config"
            echo "notch-quickshell: restored previous Kitty config"
        fi
    fi
fi

echo "notch-quickshell: Plasma autostart installed"
