# dotfiles: a WezTerm + Herdr agent workspace

A macOS terminal setup built around coding agents. WezTerm is the window;
[Herdr](https://herdr.dev) inside it runs every project as a workspace,
shows which agent is working, blocked, or done across all of them, and
keeps everything alive through closed windows and restarts. Themed
rose-pine, with silent notifications.

One rule holds it together: one project, one Herdr workspace. For feature
work: one task, one worktree, one branch, one workspace.

---

## What you get

- **Every window is Herdr.** WezTerm opens straight into the one Herdr
  session; a second window (Cmd-N) attaches to the same session. Cmd-T
  opens a plain shell tab outside Herdr.
- **Agent status at a glance.** Herdr recognizes Claude Code, Codex, and
  other agents in its panes, and its sidebar shows each one's state per
  workspace. When a background agent finishes or needs input, you get a
  silent macOS notification. No sound, anywhere.
- **Worktrees as workspaces.** `herdr worktree create` (or `Ctrl-a
  Shift-g`) makes a branch, a worktree under `~/Workspace/.worktrees`, and a
  workspace for it. `wt gc` later sweeps the ones whose work has merged.
- **Survives restarts.** Closing WezTerm leaves everything running. After a
  Herdr server restart or a reboot, Herdr brings back workspaces, tabs, panes,
  their directories, and recent screen contents, and reopens Claude Code
  conversations where they left off.
- **Agents that drive agents.** With the Herdr skill, an agent can split a
  pane, start another agent there, prompt it, wait for it, and read its
  answer.
- **Review diffs beside the agent.** Cmd-R toggles
  [reviewr](https://github.com/persiyanov/herdr-reviewr), a Herdr plugin
  that shows the agent's changes full-tab: comment on lines, then send the
  comments to the agent's input.
- **One home for agent skills.** Skills live in `.agents/skills/` and get
  symlinked into every agent's skill directory, so Claude Code, Codex, and
  opencode all read the same copy.
- Plus the small stuff: Cmd-click opens URLs through Herdr, Cmd-V pastes
  images into Claude Code, and a consistent rose-pine look.

---

## Requirements

- macOS. WezTerm detects Herdr in the Apple Silicon (`/opt/homebrew`) or
  Intel (`/usr/local`) Homebrew location, or the official installer's default
  (`~/.local/bin`), then falls back to `PATH`. The setup also relies on macOS
  notifications.
- Homebrew, and a zsh login shell (the macOS default).

---

## Install (new machine)

```sh
# 1: terminal + tools
brew install --cask wezterm@nightly
curl -fsSL https://herdr.dev/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"   # Herdr now, and `wt` after linking
command -v jq >/dev/null || brew install jq

# 2: clone this repo anywhere, then run the installer
git clone <this-repo> ~/dotfiles
~/dotfiles/install.sh    # idempotent; backs up any real file it would replace

# 3: let Herdr reopen Claude Code conversations after a restart
herdr integration install claude

# 4: the reviewr diff pane (Cmd-R); its config comes from herdr/reviewr.toml
herdr plugin install persiyanov/herdr-reviewr
```

Add this to `~/.zshrc` if it isn't already present, then open a new shell:

```sh
export PATH="$HOME/.local/bin:$PATH"   # for Herdr and `wt`
```

The [official Herdr installer](https://herdr.dev/docs/install/) downloads a
prebuilt binary for either Intel or Apple Silicon into `~/.local/bin` and
verifies its checksum. Update this install with `herdr update`. On Apple
Silicon, `brew install herdr` is also an option; update that install with
`brew upgrade herdr`. WezTerm checks the Homebrew locations first if both
install methods are present.

On Intel Macs, Homebrew [no longer builds new bottles](https://docs.brew.sh/Support-Tiers#future-macos-support),
so installing Herdr through it can build Rust, Zig, LLVM, and their dependencies
from source. Use the official installer to avoid those builds. The setup can
use macOS's bundled `jq`; the command above installs it only when missing.

`gh` is optional: it improves merged-PR detection in `wt gc`. On Apple Silicon,
install it with `brew install gh`; on Intel, use a prebuilt macOS amd64 binary
from [GitHub CLI releases](https://github.com/cli/cli/releases) to avoid building Go.
Without `gh`, `wt gc` still checks Git ancestry and squash merges.

Then put your projects under the workspace root and launch:

```sh
mkdir -p ~/Workspace
git -C ~/Workspace clone <some-project>
open -a WezTerm
```

`install.sh` is idempotent; run it as often as you like. It:

- symlinks every config into place, so editing `~/.wezterm.lua` or
  `~/.config/herdr/config.toml` edits this repo. A real file in the way is
  moved to `<name>.bak` (or `<name>.bak.<timestamp>` if that exists, so no
  backup is ever overwritten); a symlink pointing elsewhere is replaced with
  a note naming its old target,
- links every skill in `.agents/skills/` into the agents' skill directories.

---

## Verify

- Open WezTerm. You land in Herdr. `cd` into a project and start `claude`;
  the sidebar shows it.
- Quit WezTerm and reopen it: everything is where you left it.
- `herdr server stop`, then reopen WezTerm: workspaces, tabs, and panes come
  back, and Claude Code resumes its conversation.

---

## Workflow

### Herdr basics

The mouse covers everything: click panes, tabs, and workspaces to focus,
drag split borders, right-click for menus, drag-select to copy. For the
keyboard, the prefix is `Ctrl-a`, then one key:

| Key | Action |
|---|---|
| `Ctrl-a ?` | every active binding |
| `Ctrl-a w` | workspace picker |
| `Ctrl-a Shift-n` | new workspace |
| `Ctrl-a c` | new tab |
| `Ctrl-a v` / `Ctrl-a -` | split right / down |
| `Ctrl-a h/j/k/l` | move between panes |
| `Ctrl-a q` | detach (everything keeps running) |
| `Cmd-R` | toggle the reviewr diff pane |

### Worktrees

Herdr creates and opens worktrees; `herdr/config.toml` stores them under
`~/Workspace/.worktrees/<repo>/<branch-slug>`.

```
herdr worktree create --branch <name>   new branch + worktree + workspace (or Ctrl-a Shift-g)
herdr worktree open                     open an existing one as a workspace
herdr worktree list                     worktrees of the current repo
herdr worktree remove --workspace <id>  remove checkout + workspace (keeps the branch)
wt gc                                   sweep worktrees whose work has merged
```

`wt gc` checks each worktree's branch against the repo's default branch
(merged PR for that exact commit, ancestry, or squash-merge), and removes
the landed ones along with their branch and any Herdr workspace showing
them. It asks per worktree (`--all` doesn't, `--dry-run` only reports) and
never touches a worktree with uncommitted changes.

Herdr doesn't copy untracked files (`.env` and friends) into a new worktree
or run a per-repo setup script; copy what the task needs by hand.

---

## Agent skills

The agents get their skills from this repo too. `.agents/skills/` holds
[Agent Skills](https://agentskills.io), the `SKILL.md` format that Claude
Code, Codex, opencode, and most other coding agents understand. `install.sh`
symlinks each skill into `~/.claude/skills/` and `~/.agents/skills/`, so one
copy serves every agent and an edit here is live everywhere. Re-run it after
adding, removing, or renaming a skill; it also prunes dead links that
pointed into this repo.

```sh
# -a codex: Codex's project dir is .agents/skills/, so the skill lands only there
npx skills add <owner/repo> -s <name> -a codex -y
./install.sh             # link it everywhere
```

Read a skill before you link it: it is instructions, and often scripts, that
your agents will follow with their full permissions.

To keep a skill, commit it along with the `skills-lock.json` that
`npx skills` writes. To drop one, run `npx skills remove <name>` (which also
updates the lock) and re-run `install.sh`. `npx skills update` pulls
upstream changes. A skill of your own is just a hand-written
`.agents/skills/<name>/SKILL.md`.

`install.sh` never overwrites a real directory, or a live link to somewhere
else, in the agents' skill dirs; if a name collides with one, it warns and
skips that skill.

The `herdr` skill (from `herdrdev/herdr`) teaches agents to control Herdr
from inside one of its panes. It only activates when you mention Herdr, for
example "use herdr to start codex in a pane next to me and have it review
the diff".

---

## Persistence & restarts

| | |
|---|---|
| **Closed window / detach** | nothing stops: the Herdr server owns the processes, and reopening WezTerm reattaches |
| **Server restart or reboot** | opening WezTerm starts the server, which restores workspaces, tabs, panes, their directories and layout; other running programs (dev servers, watchers) don't survive and need restarting |
| **Screen contents** | recent pane history comes back too (`pane_history`, experimental, on in `herdr/config.toml`) |
| **Agents** | Claude Code conversations resume through `herdr integration install claude`; other agents need their own integration (`herdr integration status`) |
| **At login** | nothing runs by itself: add WezTerm to Login Items to have the workspace open at login |

---

## Customizing

- **Herdr.** `herdr/config.toml` holds the overrides; `herdr --default-config`
  prints every option. `herdr config check` validates, and
  `herdr server reload-config` applies edits to the running server. Herdr's
  settings screen (`Ctrl-a s`) writes to this same file.
- **Workspace root.** Defaults to `~/Workspace`: change `[worktrees]
  directory` in `herdr/config.toml`, and set `WORKSPACE_DIR` in
  `~/.zshenv` for `wt`.
- **Theme / font.** `wezterm/wezterm.lua` for the window, `[theme]` in
  `herdr/config.toml` for Herdr's UI.

---

## Repo layout

| Repo file | Symlinked to | What it is |
|---|---|---|
| `wezterm/wezterm.lua` | `~/.wezterm.lua` | WezTerm: theme, every window runs Herdr, Cmd-T plain shell, Cmd-R reviewr, Cmd-click links, smart Cmd-V |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | Herdr: `Ctrl-a` prefix, reviewr key, worktree dir, theme, silent notifications, pane history |
| `herdr/reviewr.toml` | `~/.config/herdr/plugins/config/persiyanov.reviewr/config.toml` | reviewr plugin: opens zoomed |
| `bin/wt` | `~/.local/bin/wt` | `wt gc`: sweep merged worktrees |
| `claude/statusline.sh` | `~/.claude/statusline.sh` | Claude Code status line (opt-in: point Claude's `statusLine` setting at it) |
| `.agents/skills/<name>/` | `~/.claude/skills/<name>`, `~/.agents/skills/<name>` | agent skills, linked per skill; add via `npx skills add` |
| `skills-lock.json` | — | source and content-hash pins for skills installed via `npx skills` (written by it) |
| `install.sh` | — | symlinks everything; idempotent |

---

## Notes & troubleshooting

- The live files (`~/.wezterm.lua`, `~/.config/herdr/config.toml`, and
  friends) are symlinks into this repo, so editing them edits the repo.
  `git status` here shows your drift; commit as you go.
- If an app ever replaces a symlink with a real file, re-run `install.sh`:
  it moves the file to `<name>.bak` (timestamped if that exists) and restores
  the link. Diff the backup against the repo and commit what you want to
  keep.
- **An agent shows the wrong state (or `unknown`)?** `herdr agent explain
  <pane> --json` shows why Herdr classified it that way. Codex's finished
  state isn't recognized as of Herdr 0.9.3 / Codex 0.159, so it stays
  `unknown` between turns.
- **Something off at startup?** If new windows close right away, Herdr failed
  to start. Press Cmd-T in any open window for a plain shell (with none
  left, run `/Applications/WezTerm.app/Contents/MacOS/wezterm start --
  /bin/zsh -l` from Terminal.app), and run `herdr` there to see the error.
  `herdr status` summarizes client and server; logs live in
  `~/.config/herdr/`.
- **WezTerm cannot find Herdr after installing it?** Executable detection runs
  when the config loads. If WezTerm was already running before installation,
  press Ctrl-Shift-R to reload its config, or quit and reopen it. New windows
  will then use the detected absolute path; Cmd-R still toggles reviewr.
