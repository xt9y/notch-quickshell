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

Hold any modifier key (Shift, Ctrl, Alt, Super/Meta) and left-click the notch to open the wallpaper picker.

Directory scans are deferred while the list is being dragged or flicked so live refreshes cannot reset the scroll position.

### Day / night scheduling

Clicking a wallpaper cycles its persistent assignment:

```text
NONE -> DAY -> NIGHT -> NONE
```

- `DAY` wallpapers have a gold/orange border.
- `NIGHT` wallpapers have a blue border.
- `NONE` wallpapers have no assignment border.
- The green dot marks the wallpaper currently selected by the scheduler.

The local-time phases are:

```text
DAY    07:00 -> 19:00
NIGHT  19:00 -> 07:00
```

If exactly one wallpaper is assigned to a phase, it is used for that entire 12-hour phase. If multiple wallpapers are assigned, the phase is split evenly between them in deterministic filename order. For example, three DAY wallpapers each receive four hours.

Assignments are stored in:

```text
~/.config/quickshell/notch/wallpaper-schedule
```

The scheduler starts with `qs -c notch`, checks once per minute, and keeps running even while the wallpaper picker is closed. Assignment changes trigger an immediate recalculation.

Scheduled wallpapers are applied to the Plasma desktop, KDE lock screen, and PlasmaLogin.

### Passwordless wallpaper updates

When `qs -c notch` starts, the notch checks whether its restricted privileged wallpaper helper is already installed. If not, it automatically starts the one-time setup using KDE/Polkit. The first setup may therefore ask for your password once. Later starts detect the existing helper and do nothing, and changing wallpapers does not ask for a password.

The installed `/usr/local/libexec/notch-wallpaper-root` helper only accepts `.jpg` and `.png` files directly inside `~/.config/quickshell/notch/wallpaper` and only updates the fixed PlasmaLogin/shared wallpaper files. It does not grant general passwordless sudo access.

You can still run the setup manually if necessary:

```bash
cd ~/.config/quickshell/notch
sudo bash setup-no-password.sh
```
