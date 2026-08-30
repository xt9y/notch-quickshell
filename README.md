# Quickshell Notch

A macOS-style notch bar for Wayland using [Quickshell](https://quickshell.outfoxxed.me/).

Features:
- Dynamic notch with expand/collapse animations
- Connectivity panel
- Music player (MPRIS)
- Battery status via UPower
- Wallpaper integration

## Wallpaper picker

Put `.jpg` or `.png` files in:

```text
~/.config/quickshell/notch/wallpaper
```

Hold any modifier key (Shift, Ctrl, Alt, Super/Meta) and left-click the notch to open the wallpaper picker. The picker rescans the directory while it is open, shows the wallpapers in a vertically scrollable list, and stays open after applying one so another can be selected immediately.

Selecting a wallpaper applies it to the Plasma desktop, KDE lock screen, and PlasmaLogin.

### Remove the password prompt

Run this once from your normal desktop user:

```bash
cd ~/.config/quickshell/notch
sudo bash setup-no-password.sh
```

This asks for your password once while installing `/usr/local/libexec/notch-wallpaper-root` and a narrowly scoped rule in `/etc/sudoers.d/`. After that, wallpaper selections use `sudo -n` and do not open the KDE/Polkit authentication dialog.

The helper only accepts `.jpg` and `.png` files directly inside `~/.config/quickshell/notch/wallpaper` and only updates the fixed PlasmaLogin/shared wallpaper files. It does not grant general passwordless sudo access.
