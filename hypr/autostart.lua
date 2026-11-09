-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- EasyEffects in the background: runs the "Loud" limiter preset that makes the speakers usable.
o.launch_on_start("easyeffects --service-mode -w")

-- Wispr Flow: move its status pill to whichever monitor is focused.
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/wispr-pill-follow")
