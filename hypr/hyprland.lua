-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Hybrid GPU: normal apps load only the AMD (Mesa) EGL driver so they don't
-- keep the NVIDIA card awake. ~/.local/bin/uwsm-app overrides this for games,
-- heavy apps and gpu-switch NVIDIA mode. Remove this line to undo.
hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
-- Same for Vulkan: GTK4 apps otherwise load the NVIDIA Vulkan driver at startup.
hl.env("VK_LOADER_DRIVERS_DISABLE", "nvidia_icd.json")

-- OpenDisplay: while an iPad/iPhone session is active, opendisplayd writes its
-- virtual monitor rules here so config reloads (layout toggles, theme changes)
-- keep the right mode. The file is removed when the session ends.
pcall(dofile, (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/opendisplay/hyprland.lua")

-- Gaming: let CS2 skip vsync (tearing) for lower input lag. Only applies to
-- windows with the immediate rule, normal apps stay tear-free.
hl.config({ general = { allow_tearing = true } })
o.window("^(cs2)$", { immediate = true })

-- Wispr Flow status pill: bottom-center of the focused monitor, follows workspace switches mid-dictation.
o.window({ class = "^wispr-flow$", title = "^Status$" }, {
  tag = "-default-opacity",
  float = true,
  pin = true,
  no_initial_focus = true,
  border_size = 0,
  no_shadow = true,
  opacity = "1 1",
  move = { "((monitor_w-window_w)/2)", "(monitor_h-window_h-20)" },
})
