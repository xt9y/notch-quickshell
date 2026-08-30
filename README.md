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

Selecting a wallpaper applies it to the Plasma desktop, KDE lock screen, and PlasmaLogin. The PlasmaLogin and shared lock-screen copy require elevated privileges; `pkexec` is used when available.
