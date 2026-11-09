#!/bin/bash
# Reinstall the third-party Omarchy themes and shell plugins this setup uses.
# They are other people's git repos, so they're not copied into this one.
# Run after cloning this repo into ~/.config on a fresh Omarchy install.
# Plugins are added without --enable: shell.json (in this repo) already
# places and enables them.

set -u

themes=(
  https://github.com/tahfizhabib/omarchy-amberbyte-theme
  https://github.com/anuj-kosambi/omarchy-apexer-theme.git
  https://github.com/bjarneo/omarchy-ash-theme
  https://github.com/atif-1402/omarchy-atelier-theme.git
  https://github.com/pkovzz/omarchy-black-sand-theme.git
  https://github.com/knappkevin/omarchy-crimson-gold-theme
  https://github.com/abhijeet-swami/omarchy-forest-green-theme
  https://github.com/rondilley/omarchy-retropc-theme
)

plugins=(
  https://github.com/Enovara/omarchy-teach-voxtype.git
  https://github.com/RuffBudda/omarchy-sticky-notes.git
  https://github.com/SanchoKusika/omarchy-workspace-styler.git
)

for url in "${themes[@]}"; do
  echo "== theme: $url"
  omarchy theme install "$url" || echo "   (failed or already installed, skipping)"
done

for url in "${plugins[@]}"; do
  echo "== plugin: $url"
  omarchy plugin add "$url" --yes || echo "   (failed or already installed, skipping)"
done

echo "Done. Restart the shell: omarchy restart shell"
