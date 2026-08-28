-- Hyprland configuration managed by xt9y/notch-quickshell.
-- ~/.config/hypr/hyprland.lua is symlinked to this file by scripts/apply-hypr.sh.

------------------
---- MONITORS ----
------------------

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",

    -- Keep tiled windows just below the physical MacBook notch.
    reserved_area = {
        top = 30,
        bottom = 0,
        left = 0,
        right = 0,
    },
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "dolphin"
local mainMod = "SUPER"

-------------------
---- AUTOSTART ----
-------------------

-- Run the same update path used by the config-update shell alias on every
-- Hyprland login: pull the repo, then launch the notch Quickshell config.
-- Detach it so startup never leaves a terminal/helper window behind.
hl.on("hyprland.start", function()
    hl.exec_cmd("setsid -f bash $HOME/.config/quickshell/notch/scripts/config-update.sh $HOME/.config/quickshell/notch >/dev/null 2>&1")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "16")
hl.env("HYPRCURSOR_SIZE", "16")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 1,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
        col = {
            -- Focused windows: restrained dark gray. Everything else: pitch black.
            active_border = "rgba(3a3a3aff)",
            inactive_border = "rgba(000000ff)",
        },
    },

    decoration = {
        -- Match the notch's 8px lower-corner radius.
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },

    input = {
        -- German keyboard layout.
        kb_layout = "de",
        kb_variant = "nodeadkeys",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
        },
    },
})

----------------------------------
---- MACOS WINDOW DECORATIONS ----
----------------------------------

-- hyprbars is loaded by scripts/setup-hyprbars.sh. Guard the plugin-specific
-- API so Hyprland remains usable even if the plugin cannot be built/loaded.
if hl.plugin.hyprbars ~= nil then
    hl.config({
        plugin = {
            hyprbars = {
                enabled = true,

                -- macOS dark title-bar proportions.
                bar_height = 28,
                bar_color = "rgba(282828f2)",
                bar_blur = true,
                bar_part_of_window = true,
                bar_precedence_over_border = true,

                -- macOS-like centered title typography. Fontconfig falls back
                -- automatically when SF Pro Display is not installed.
                col = {
                    text = "rgba(e7e7e7ff)",
                },
                bar_title_enabled = true,
                bar_text_size = 11,
                bar_text_weight = 500,
                bar_text_font = "SF Pro Display",
                bar_text_align = "center",

                -- Apple traffic lights: 12px circles with compact left spacing.
                bar_buttons_alignment = "left",
                bar_padding = 12,
                bar_button_padding = 7,
                icon_on_hover = true,
                inactive_button_color = "rgb(777777)",

                on_double_click = "hyprctl dispatch fullscreen 1",
            },
        },
    })

    -- Red: close. The dark glyph only appears while hovering the traffic light.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ff5f57)",
        fg_color = "rgb(5b1110)",
        size = 12,
        icon = "×",
        action = "hyprctl dispatch killactive",
    })

    -- Yellow: emulate macOS minimize using a hidden Hyprland special workspace.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(febc2e)",
        fg_color = "rgb(6b4800)",
        size = 12,
        icon = "−",
        action = "hyprctl dispatch movetoworkspacesilent special:minimized",
    })

    -- Green: fullscreen/zoom.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(28c840)",
        fg_color = "rgb(075d18)",
        size = 12,
        icon = "⤢",
        action = "hyprctl dispatch fullscreen 1",
    })

    -- Helper windows must not receive a decorative title bar.
    hl.window_rule({
        name = "xwayland-video-bridge-no-titlebar",
        match = { class = "xwaylandvideobridge" },
        ["hyprbars:no_bar"] = true,
    })
end

----------------
---- GESTURES ----
----------------

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Show/hide windows sent to the yellow traffic-light "minimized" workspace.
hl.bind(mainMod .. " + N", hl.dsp.workspace.toggle_special("minimized"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------------------
---- HARDWARE BUTTONS ----
-------------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------
---- WINDOW RULES ----
--------------------

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland Video Bridge is a KDE screen-sharing helper. Keep the helper alive,
-- but make its dummy window floating so it can never consume a tiled slot.
hl.window_rule({
    name = "xwayland-video-bridge-fixes",
    match = { class = "xwaylandvideobridge" },
    float = true,
    size = { 1, 1 },
    max_size = { 1, 1 },
    no_initial_focus = true,
    no_focus = true,
    no_anim = true,
    no_blur = true,
    opacity = "0.0 override",
})
