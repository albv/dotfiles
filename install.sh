#!/bin/sh
# Symlink these dotfiles into place. Idempotent: safe to re-run anytime.
# A real file already at a target is backed up to <name>.bak first — or
# <name>.bak.<timestamp> if that's taken, so an older backup is never
# clobbered (skills excepted: see below).
DIR=$(cd "$(dirname "$0")" && pwd)

link() {
  src="$DIR/$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    # a link of our own is just refreshed; someone else's is worth a note
    old=$(readlink "$dst")
    case $old in
      "$DIR"/*) ;;
      *) echo "note: replacing link $dst (was -> $old)" ;;
    esac
  elif [ -e "$dst" ]; then
    bak="$dst.bak" n=1
    while [ -e "$bak" ] || [ -L "$bak" ]; do   # never clobber an older backup
      bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
      [ "$n" -gt 1 ] && bak="$bak-$n"          # same-second re-run
      n=$((n + 1))
    done
    # mv failing must stop the link: ln -sf would delete the real file
    mv "$dst" "$bak" || { echo "WARN: couldn't back up $dst; not linking" >&2; return 1; }
    echo "backed up existing $dst -> $bak"
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
link bin/tmux-snapshot          "$HOME/.local/bin/tmux-snapshot"

# these are invoked by path — don't rely on git preserving the exec bit
chmod +x "$DIR/bin/wezterm-project-picker" "$DIR/bin/wt" \
         "$DIR/bin/tmux-boot" "$DIR/bin/tmux-snapshot" \
         "$DIR/claude/statusline.sh"

# Agent skills: link each .agents/skills/<name> into every harness's skill
# dir, one link per skill since Claude Code won't follow a symlinked skills
# dir. Those dirs also hold other tools' skills, so a real dir or a live link
# elsewhere at a target is left alone, and only dangling links that pointed
# into this repo are pruned.
skills="$DIR/.agents/skills"
for dest in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  mkdir -p "$dest"
  for entry in "$dest"/*; do
    [ -L "$entry" ] && [ ! -e "$entry" ] || continue
    case $(readlink "$entry") in
      "$skills"/*) rm "$entry"; echo "pruned dangling $entry" ;;
    esac
  done
  for src in "$skills"/*; do
    [ -f "$src/SKILL.md" ] || continue
    target="$dest/${src##*/}"
    # relink only if missing, dangling, or already ours
    if [ -L "$target" ]; then
      case $(readlink "$target") in
        "$skills"/*) ;;
        *) if [ -e "$target" ]; then
             echo "WARN: $target links to $(readlink "$target"); not linking over it" >&2
             continue
           fi ;;
      esac
    elif [ -e "$target" ]; then
      echo "WARN: $target is a real directory; not linking over it" >&2
      continue
    fi
    ln -sfn "$src" "$target" && echo "linked $target -> $src"
  done
done

# tmux plugins: tpm + everything declared via `set -g @plugin` in tmux.conf.
# Cloning each into ~/.tmux/plugins/<name> is exactly what tpm's `prefix + I`
# does, so they load on the next tmux start — no manual step. Idempotent.
# Anchored to real `set -g @plugin` lines, so commented-out plugins are skipped.
plugdir="$HOME/.tmux/plugins"
mkdir -p "$plugdir"
sed -n "s/^[[:space:]]*set -g @plugin ['\"]\([^'\"]*\)['\"].*/\1/p" "$DIR/tmux/tmux.conf" | while read -r repo; do
  name=${repo##*/}
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
# generated file, not a symlink: launchctl reloads it by content. plutil, not
# sed: it sets the value as data, so a HOME containing & | \ or XML
# metacharacters can't corrupt the path or the plist.
if [ "$(uname)" = "Darwin" ]; then
  agent="$HOME/Library/LaunchAgents/dev.dotfiles.tmux-boot.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cp "$DIR/macos/dev.dotfiles.tmux-boot.plist" "$agent" &&
    plutil -replace ProgramArguments.0 -string "$HOME/.local/bin/tmux-boot" "$agent" ||
    { echo "WARN: couldn't render $agent" >&2; exit 1; }
  echo "rendered $agent"
  # reload so it's active this session too. bootstrap, not the legacy load:
  # `launchctl load` exits 0 even when it prints "Load failed", so its exit
  # code can't gate the success message. bootout's error (not loaded) is fine;
  # its teardown is async, so a bootstrap right after can transiently fail —
  # retry once.
  uid=$(id -u)
  launchctl bootout "gui/$uid/dev.dotfiles.tmux-boot" 2>/dev/null
  if launchctl bootstrap "gui/$uid" "$agent" 2>/dev/null ||
     { sleep 2; launchctl bootstrap "gui/$uid" "$agent"; }; then
    echo "loaded LaunchAgent dev.dotfiles.tmux-boot"
  else
    echo "WARN: bootstrap failed. The agent is installed and still loads at next login" >&2
    echo "      unless the service is disabled. If it was disabled, run:" >&2
    echo "      launchctl enable gui/$uid/dev.dotfiles.tmux-boot && launchctl bootstrap gui/$uid $agent" >&2
  fi
fi
