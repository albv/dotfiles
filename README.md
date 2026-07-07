# dotfiles — a WezTerm + tmux project workspace

A macOS terminal setup where **every tab is a project**, feature work happens in
**git worktrees that are first-class tmux sessions**, and your whole workspace —
layouts, scrollback, and running agents — **survives a reboot**. Themed
rose-pine-moon, with silent (toast-only) notifications.

It's built around one rule:

> **one tab = one project = one tmux session** — and for feature work,
> **one task = one worktree = one branch = one session.**

WezTerm provides the window, tabs, theme, and notifications; tmux provides the
sessions, splits, and persistence. You interact with WezTerm; tmux is the
durable spine underneath that keeps everything alive across disconnects and
reboots.

---

## What you get

- **Tabs are projects.** Opening a new WezTerm tab shows an fzf picker of your
  projects. Pick one and you're attached to its tmux session — created on first
  use, reattached forever after.
- **Worktrees as sessions.** `wt new <branch>` creates a git worktree, a branch,
  and a tmux session in one step, isolated from your main checkout. `wt gc`
  later sweeps the ones whose work has already merged.
- **Survives reboot.** Sessions are snapshotted on every change; at login they're
  restored headlessly and WezTerm reopens one tab per session — panes, layouts,
  scrollback, and coding agents included.
- **Silent notifications.** When a long command (or a coding agent) finishes,
  its tab highlights and macOS shows a toast. No sound, anywhere.
- **Agent-friendly.** Wire any coding agent (Claude Code, etc.) into a repo's
  worktrees with a small `.session-setup` script; it comes back on reboot
  continuing where it left off.
- Plus the small stuff: `Cmd`-click opens URLs from inside tmux, vim-style pane
  navigation, true color, and a consistent rose-pine-moon look.

---

## Requirements

- **macOS** — the setup uses Homebrew paths (`/opt/homebrew`), a launchd agent,
  and macOS notifications.
- **Homebrew**, and a **zsh** login shell (the macOS default).

---

## Install (new machine)

```sh
# 1 — terminal + tools
brew install --cask wezterm@nightly
brew install tmux fzf jq
brew install gh          # optional: better merged-PR detection in `wt gc`

# 2 — clone this repo anywhere, then run the installer
git clone <this-repo> ~/dotfiles
~/dotfiles/install.sh    # idempotent; backs up any real file it would replace
```

Add these to `~/.zshrc` if they aren't already present, then open a new shell:

```sh
export PATH="$HOME/.local/bin:$PATH"                       # for `wt`, the picker
export PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS" # for the `wezterm` CLI
```

Then put your projects under the workspace root and launch:

```sh
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/Workspace}"   # default; override to taste
mkdir -p "$WORKSPACE_DIR"
git -C "$WORKSPACE_DIR" clone <some-project>        # the picker lists repos here
open -a WezTerm
```

`install.sh` is one-stop and idempotent — it:

- **symlinks** every config into place (so editing `~/.tmux.conf`,
  `~/.wezterm.lua`, … edits this repo),
- **installs the tmux plugins** — `tpm`, `tmux-resurrect`, `tmux-continuum`
  (declared via `@plugin` in `tmux.conf`); no `prefix + I` needed, and
- on macOS, **installs a launchd agent** that restores tmux at login.

---

## Verify

- Open WezTerm → you should land in the **project picker**. Pick a project;
  you're now in its tmux session.
- Open a couple of projects in tabs, quit WezTerm, reopen it → your tabs return.

---

## Workflow

### The picker (every new tab)

`Cmd-t` opens a new tab into the picker:

| Key | Action |
|---|---|
| **Enter** | attach (or create) the selected project's session |
| **ctrl-o** | create a new worktree off a project (prompts for a branch) |
| **ctrl-x** | remove a worktree |
| **Esc** | drop to a plain shell |

Live sessions are marked `●`; worktrees whose session died show as `⌥` — press
Enter to revive them.

### Worktrees (`wt`)

Worktrees live centrally under `$WORKSPACE_DIR/.worktrees/<repo>/<slug>`
(default `~/Workspace`); sessions are named `<repo>--<slug>`.

```
wt new <branch>         create branch + worktree + session (off origin/HEAD)
wt open <repo> <slug>   reattach (or recreate) an existing worktree's session
wt done [name]          remove worktree + branch + session (refuses dirty/unmerged)
wt gc                   sweep worktrees whose work has merged (PR / ancestry / squash)
wt ls                   list worktrees: ● live / ⌥ orphaned, merged?
wt help                 full help
```

Drop a `.worktreeinclude` (gitignore syntax) in a repo to copy untracked files
(`.env` and friends) into every fresh worktree.

## Session setup

A fresh worktree just opens plain shells. To customize how a repo's sessions
start — split panes a certain way, boot a dev server, launch a coding agent,
whatever — add an executable **`.session-setup`** to that repo (commit it, or
list it in `.worktreeinclude`). It runs in the session's first pane on creation
and can run anything; `wt` itself stays agent-agnostic.

The script (and every pane in the session) inherits these variables:

| Variable | Value |
|---|---|
| `WT_WORKTREE_PATH` | the worktree directory (also the pane's cwd) |
| `WT_REPO` | repository name (e.g. `myrepo`) |
| `WT_BRANCH` | the worktree's branch (e.g. `feature/login`) |
| `WT_BASE_BRANCH` | branch it was forked from (e.g. `main`; may be empty for a reopened worktree) |

For example, to open a split and start Claude Code in the main pane:

```sh
#!/bin/sh
# .session-setup — assumes tmux pane-base-index 1 (this config's default)
tmux split-window -h -l 30% -c "$PWD"
tmux select-pane -t 1
tmux send-keys -t 1 'claude --dangerously-skip-permissions -c' Enter
```

Here `claude -c` continues that directory's conversation (or starts fresh if
there isn't one), so reopening or reviving a worktree resumes where you left
off. Swap the command for any other agent, or drop it for a plain dev layout.

---

## Persistence & reboot

| | |
|---|---|
| **Autosave** | event-driven: every session create/close and tab detach triggers a debounced snapshot via `bin/tmux-snapshot` (a single serialized writer; continuum's timer is off) |
| **At login** | a launchd agent runs `bin/tmux-boot`, which starts tmux headlessly; continuum restores your sessions, stale worktree sessions are reconciled away, and WezTerm reopens a tab per session |
| **Agents** | resurrect replays each allowlisted pane's command verbatim — a pane started with `claude -c` comes back continuing. Add agents to `@resurrect-processes` in `tmux/tmux.conf`, e.g. `'"~claude" "~aider"'` |
| **Manual** | `Ctrl-a Ctrl-s` save · `Ctrl-a Ctrl-r` restore |

---

## Customizing

- **Workspace root** — defaults to `~/Workspace`; set `WORKSPACE_DIR`, or edit
  the variable at the top of `bin/wt` and `bin/wezterm-project-picker`.
- **Swap the agent** — change the command in your repos' `.session-setup`, and
  update the allowlist in `tmux/tmux.conf`.
- **Theme / font / keys** — `wezterm/wezterm.lua` and `tmux/tmux.conf` are the
  live configs (symlinked), so edit in place and commit.

---

## Repo layout

| Repo file | Symlinked to | What it is |
|---|---|---|
| `wezterm/wezterm.lua` | `~/.wezterm.lua` | WezTerm: theme, tab-per-session restore, bell → toast, `Cmd`-click links |
| `tmux/tmux.conf` | `~/.tmux.conf` | tmux: `Ctrl-a` prefix, status bar, TPM + resurrect + continuum |
| `bin/wezterm-project-picker` | `~/.local/bin/wezterm-project-picker` | fzf new-tab menu: attach/create sessions & worktrees |
| `bin/wt` | `~/.local/bin/wt` | worktree workflow CLI (`new/open/done/gc/ls`) |
| `bin/tmux-boot` | `~/.local/bin/tmux-boot` | headless tmux restore at login (run by the launchd agent) |
| `bin/tmux-snapshot` | `~/.local/bin/tmux-snapshot` | debounced single-writer resurrect save (fired by tmux hooks on session create/close, tab detach) |
| `claude/statusline.sh` | `~/.claude/statusline.sh` | Claude Code status line (opt-in: point Claude's `statusLine` setting at it) |
| `macos/dev.dotfiles.tmux-boot.plist` | `~/Library/LaunchAgents/…` | login agent (rendered + loaded by `install.sh`) |
| `install.sh` | — | symlinks everything + installs the login agent; idempotent |

---

## Notes & troubleshooting

- The live files (`~/.tmux.conf`, `~/.wezterm.lua`, …) are **symlinks into this
  repo** — editing them edits the repo. `git status` here shows your drift;
  commit as you go.
- If an app ever replaces a symlink with a real file, re-run `install.sh` and
  commit the difference.
- **The picker is empty?** It lists directories directly under `$WORKSPACE_DIR`
  (default `~/Workspace`) — clone your project repos there.
- **Sessions don't come back after a reboot?** Make sure the plugins installed
  (re-run `install.sh`, or `Ctrl-a I` inside tmux) and that a session was saved
  at least once — saves fire automatically on session create/close and tab
  detach (force one with `Ctrl-a Ctrl-s`; snapshots live in
  `~/.local/share/tmux/resurrect`).
