# configs

My `~/.config` for [Omarchy](https://omarchy.org/) (Arch + Hyprland): the Omarchy shell
and my own `aaditya.*` shell plugins, Hyprland, terminals, Neovim, audio (EasyEffects,
WirePlumber, Voxtype), user systemd services and assorted app settings.

The repo *is* `~/.config`. `.gitignore` is an allowlist: everything is ignored unless
listed, so browser profiles, app data, caches and logins never get committed.

## Restore on a new machine

```bash
cd ~/.config
git init -b main
git remote add origin https://github.com/aaditya19saini/configs-.git
git fetch origin
git checkout -f main      # overwrites matching files in ~/.config
./restore.sh              # third-party themes and plugins
omarchy restart shell
```

## Update

```bash
cd ~/.config && git add -A && git commit -m "..." && git push
```

New app folders stay out until added to `.gitignore` with a `!/name/` line.
