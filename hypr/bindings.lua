-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
o.bind("SUPER+SHIFT+O","Obsidian","obsidian")
o.bind("SUPER+SHIFT+CTRL+S","Spotify","spotify")
o.bind("SUPER+SHIFT+CTRL+V","Visual Studio Code","code")

-- Toggle workspace layout without the "Workspace layout set to ..." toast.
-- Script is a silent copy of omarchy-hyprland-workspace-layout-toggle in ~/.local/bin.
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Toggle workspace layout", "~/.local/bin/workspace-layout-toggle-quiet")

-- Volume keys go up to 150% instead of stopping at 100% (speakers are quiet at 100%).
-- Ceiling is MAX in ~/.local/bin/volume-boost. Mute keeps the default binding.
hl.unbind("XF86AudioRaiseVolume")
hl.unbind("XF86AudioLowerVolume")
hl.unbind("ALT + XF86AudioRaiseVolume")
hl.unbind("ALT + XF86AudioLowerVolume")
o.bind("XF86AudioRaiseVolume", "Volume up", "~/.local/bin/volume-boost raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "~/.local/bin/volume-boost lower", { locked = true, repeating = true })
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "~/.local/bin/volume-boost +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "~/.local/bin/volume-boost -1", { locked = true, repeating = true })

-- Monochrome (grayscale) screen, sibling of SUPER+CTRL+N nightlight.
o.bind("SUPER + CTRL + M", "Toggle monochrome", "~/.local/bin/omarchy-toggle-monochrome")

-- SUPER+SHIFT+S takes a screenshot instead of opening Google Maps.
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")
-- SUPER+SHIFT+G opens WhatsApp instead of Signal.
hl.unbind("SUPER + SHIFT + G")
o.bind("SUPER + SHIFT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })

-- Show desktop (like Win+D) on floating workspaces only; press again to restore.
o.bind("SUPER + D", "Show desktop (floating)", "~/.local/bin/show-desktop")

-- Shut down the PC (sibling of SUPER+ESCAPE system menu).
o.bind("SUPER + SHIFT + ESCAPE", "Shutdown", "omarchy-system shutdown")

-- Logitech music key (Fn+F5) opens Spotify, or focuses it if already open.
-- The keyboard may send any of these for that key, so bind all of them.
o.bind("XF86Tools", "Spotify", { focus = "spotify", launch = "spotify" })
o.bind("XF86MediaPlayer", "Spotify", { focus = "spotify", launch = "spotify" })
o.bind("XF86Audio", "Spotify", { focus = "spotify", launch = "spotify" })

-- Switch the GPU for newly opened apps between NVIDIA and AMD (~/.local/bin/gpu-switch).
o.bind("SUPER + CTRL + G", "Switch GPU (NVIDIA/AMD)", "~/.local/bin/gpu-switch")

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end

-- Pre-4.5 shortcuts: the 4.5.0 update (2026-11-05) reassigned these defaults; this puts them back.
o.rebind("SUPER + CTRL + N", "Toggle nightlight", "omarchy-toggle-nightlight")                  -- 4.5: Network
o.rebind("SUPER + CTRL + W", "Network", { panel = "omarchy.network" })                        -- 4.5: Background switcher (still on SUPER+CTRL+SPACE)
o.rebind("SUPER + CTRL + T", "Activity", { tui = "btop" })                                    -- 4.5: Theme menu (still on SUPER+SHIFT+CTRL+SPACE)
o.bind("SUPER + CTRL + Q", "Calculator", "omacalc")                                           -- 4.5 moved it to SUPER+SHIFT+Q
o.rebind("SUPER + ALT + SPACE", "Apps menu", { menu = "apps" })                               -- 4.5: dock apps
o.rebind("SUPER + comma", "Dismiss last notification", { ipc = "notifications.dismissOne" })  -- 4.5: dismiss/invoke/focus
o.rebind("SUPER + ALT + comma", "Invoke last notification", { ipc = "notifications.invokeLast" }) -- 4.5: dismiss last
o.rebind("SUPER + CTRL + comma", "Toggle silencing notifications", "omarchy-toggle-notification-silencing") -- 4.5: keyboard control
