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

Hold any modifier key (Shift, Ctrl, Alt, Super/Meta) and left-click the notch to open the wallpaper picker. The picker shows the wallpapers in a vertically scrollable list and stays open after applying one so another can be selected immediately.

Directory scans are deferred while the list is being dragged or flicked so live refreshes cannot reset the scroll position.

Selecting a wallpaper applies it to the Plasma desktop, KDE lock screen, and PlasmaLogin.

### Passwordless wallpaper updates

When `qs -c notch` starts, the notch checks whether its restricted privileged wallpaper helper is already installed. If not, it automatically starts the one-time setup using KDE/Polkit. The first setup may therefore ask for your password once. Later starts detect the existing helper and do nothing, and changing wallpapers does not ask for a password.

The installed `/usr/local/libexec/notch-wallpaper-root` helper only accepts `.jpg` and `.png` files directly inside `~/.config/quickshell/notch/wallpaper` and only updates the fixed PlasmaLogin/shared wallpaper files. It does not grant general passwordless sudo access.

You can still run the setup manually if necessary:

```bash
cd ~/.config/quickshell/notch
sudo bash setup-no-password.sh
```
