#!/bin/sh
# Symlink these dotfiles into place. Idempotent: safe to re-run anytime.
# A real file already at a target is backed up to <name>.bak first.
DIR=$(cd "$(dirname "$0")" && pwd)

link() {
  src="$DIR/$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up existing $dst -> $dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

link wezterm/wezterm.lua        "$HOME/.wezterm.lua"
link tmux/tmux.conf             "$HOME/.tmux.conf"
link claude/statusline.sh       "$HOME/.claude/statusline.sh"
link bin/wezterm-project-picker "$HOME/.local/bin/wezterm-project-picker"
link bin/wt                     "$HOME/.local/bin/wt"
link bin/tmux-boot              "$HOME/.local/bin/tmux-boot"

# these are invoked by path — don't rely on git preserving the exec bit
chmod +x "$DIR/bin/wezterm-project-picker" "$DIR/bin/wt" \
         "$DIR/bin/tmux-boot" "$DIR/claude/statusline.sh"

# tmux plugins: tpm + everything declared via `set -g @plugin` in tmux.conf.
# Cloning each into ~/.tmux/plugins/<name> is exactly what tpm's `prefix + I`
# does, so they load on the next tmux start — no manual step. Idempotent.
plugdir="$HOME/.tmux/plugins"
mkdir -p "$plugdir"
[ -d "$plugdir/tpm" ] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$plugdir/tpm"
grep -oE "@plugin '[^']+'" "$DIR/tmux/tmux.conf" | tr -d "'" | sed 's/@plugin //' | while read -r repo; do
  name=${repo##*/}
  [ "$name" = tpm ] && continue
  if [ -d "$plugdir/$name" ]; then
    echo "plugin present: $name"
  elif git clone --depth 1 "https://github.com/$repo" "$plugdir/$name" 2>/dev/null; then
    echo "installed plugin: $name"
  else
    echo "WARN: could not clone $repo (network?)" >&2
  fi
done
# activate immediately if a tmux server is already running (no-op otherwise)
tmux source-file "$HOME/.tmux.conf" 2>/dev/null && echo "reloaded tmux config"

# macOS: LaunchAgent that restores tmux at login (headless — see bin/tmux-boot).
# launchd can't expand ~/$HOME, so render the placeholder to a real path. A
# generated file, not a symlink: launchctl reloads it by content.
if [ "$(uname)" = "Darwin" ]; then
  agent="$HOME/Library/LaunchAgents/dev.dotfiles.tmux-boot.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed "s|__TMUX_BOOT__|$HOME/.local/bin/tmux-boot|g" \
    "$DIR/macos/dev.dotfiles.tmux-boot.plist" > "$agent"
  echo "rendered $agent"
  # reload so it's active this session too (ignore unload error if not loaded)
  launchctl unload "$agent" 2>/dev/null
  launchctl load "$agent" 2>/dev/null && echo "loaded LaunchAgent dev.dotfiles.tmux-boot"
fi
