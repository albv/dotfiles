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
link herdr/config.toml          "$HOME/.config/herdr/config.toml"
link herdr/reviewr.toml         "$HOME/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
link claude/statusline.sh       "$HOME/.claude/statusline.sh"
link bin/wt                     "$HOME/.local/bin/wt"

# these are invoked by path — don't rely on git preserving the exec bit
chmod +x "$DIR/bin/wt" "$DIR/claude/statusline.sh"

# Retired tmux setup (git tag tmux-setup): drop the links it left behind, but
# only dangling ones that pointed into this repo, and unload its login agent.
for old in "$HOME/.tmux.conf" "$HOME/.local/bin/wezterm-project-picker" \
           "$HOME/.local/bin/tmux-boot" "$HOME/.local/bin/tmux-snapshot"; do
  [ -L "$old" ] && [ ! -e "$old" ] || continue
  case $(readlink "$old") in
    "$DIR"/*) rm "$old"; echo "removed retired link $old" ;;
  esac
done
agent="$HOME/Library/LaunchAgents/dev.dotfiles.tmux-boot.plist"
if [ -f "$agent" ]; then
  launchctl bootout "gui/$(id -u)/dev.dotfiles.tmux-boot" 2>/dev/null
  rm "$agent" && echo "removed retired LaunchAgent $agent"
fi

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
