local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- WezTerm is just the window: every window attaches to the one Herdr
-- session, and Herdr owns workspaces, tabs, panes, agent status,
-- notifications, and persistence (see herdr/config.toml).

-- Appearance
config.color_scheme = 'rose-pine-moon'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 14.0

-- Minimal chrome: no title bar, no traffic lights (like the reference)
config.window_decorations = 'RESIZE'
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Herdr has its own tabs and sidebar; a WezTerm tab bar only appears in the
-- rare case of a second WezTerm tab
config.hide_tab_bar_if_only_one_tab = true

-- Fancy tab bar in rose-pine-moon colors: quiet text-only tabs — active
-- is bold gold text, no fills (the built-in scheme doesn't style the tab
-- bar, so set explicitly)
config.use_fancy_tab_bar = true
-- No per-tab close buttons (their color inherits from title formatting and
-- shifts around; Cmd+W closes tabs anyway). Not possible per-tab.
config.show_close_tab_button_in_tabs = false
config.window_frame = {
  font = wezterm.font { family = 'JetBrains Mono', weight = 'Bold' },
  font_size = 13.0,
  active_titlebar_bg = '#2a273f',
  inactive_titlebar_bg = '#2a273f',
}
config.colors = {
  tab_bar = {
    active_tab = { bg_color = '#2a273f', fg_color = '#f6c177', intensity = 'Bold' },
    inactive_tab = { bg_color = '#2a273f', fg_color = '#908caa' },
    inactive_tab_hover = { bg_color = '#393552', fg_color = '#e0def4' },
    new_tab = { bg_color = '#2a273f', fg_color = '#6e6a86' },
    new_tab_hover = { bg_color = '#393552', fg_color = '#e0def4' },
  },
}

-- Dim inactive panes (native WezTerm splits only; Herdr draws its own panes)
config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.7,
}

config.scrollback_lines = 100000

-- Kitty keyboard protocol: lets Cmd chords WezTerm doesn't bind itself reach
-- Herdr (e.g. Cmd+R, see herdr/config.toml). Needs a WezTerm build with the
-- June 2026 Esc fix (wezterm#7787); older ones drop quick Esc taps in Herdr
-- (herdr#1266).
config.enable_kitty_keyboard = true

-- CMD+click to open links, working *through* Herdr. Herdr is mouse-first, so
-- mouse reporting is always on, and WezTerm normally forwards clicks to the
-- app instead of matching its own bindings — so the built-in CMD+click
-- link-open only fires when reporting is off. `mouse_reporting = true` is the
-- key: it opts THESE bindings in precisely when reporting IS on, without
-- repurposing CMD as a global bypass modifier. Nop the Down half so Herdr
-- never sees a stray click (focus change / selection); open on Up.
-- (SHIFT still bypasses reporting for normal WezTerm text selection.)
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    mouse_reporting = true,
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
}

-- Cmd+V: smart paste. Images can't ride a text paste through the tty, so a
-- terminal app (Claude Code) reads the clipboard itself on Ctrl+V. Peek at the
-- clipboard: if it holds an image (a screenshot etc.), send a raw Ctrl+V (0x16)
-- so the focused app grabs it; otherwise do a normal text paste. `osascript` is
-- the dependency-free clipboard probe — a few ms per paste, macOS-only.
-- (Edge: an image on the clipboard + a plain shell means Cmd+V inserts a literal
-- ^V rather than pasting — rare, and you rarely paste an image into a shell.)
config.keys = {
  {
    key = 'v',
    mods = 'CMD',
    action = wezterm.action_callback(function(window, pane)
      local pok, ran, out = pcall(wezterm.run_child_process,
        { '/usr/bin/osascript', '-e', 'clipboard info' })
      local has_image = out and (out:find 'PNGf' or out:find 'TIFF'
        or out:find 'JPEG' or out:find 'GIFf')
      local has_text = out and (out:find 'utf8' or out:find 'string')
      -- no text flavor at all: a text paste would paste nothing, so trying
      -- the app's own clipboard read (Ctrl+V) is strictly better
      if pok and ran and (has_image or not has_text) then
        window:perform_action(wezterm.action.SendString '\x16', pane)
      else
        window:perform_action(wezterm.action.PasteFrom 'Clipboard', pane)
      end
    end),
  },
  -- Cmd+R: free it from WezTerm's reload-config (the config reloads by
  -- itself on save anyway) so it reaches Herdr, which binds it to the
  -- reviewr diff pane
  {
    key = 'r',
    mods = 'CMD',
    action = wezterm.action.DisableDefaultAssignment,
  },
  -- Cmd+T: a plain login shell outside Herdr (new windows still open Herdr).
  -- The way in when Herdr itself won't start, and for quick one-offs.
  {
    key = 't',
    mods = 'CMD',
    action = wezterm.action.SpawnCommandInNewTab {
      args = { os.getenv 'SHELL' or '/bin/zsh', '-l' },
    },
  },
}

-- Every window and tab attaches to Herdr, which launches its server on first
-- use and restores the saved workspaces after a restart. Spawned by WezTerm
-- directly, never from inside another multiplexer, so Herdr's panes start
-- with a clean environment. Absolute path: a GUI-launched WezTerm doesn't
-- have Homebrew or ~/.local/bin on its PATH. Check both Homebrew locations
-- and the official installer's default; fall back to PATH for other installs.
local herdr = 'herdr'
for _, path in ipairs {
  '/opt/homebrew/bin/herdr',
  '/usr/local/bin/herdr',
  wezterm.home_dir .. '/.local/bin/herdr',
} do
  local file = io.open(path, 'r')
  if file then
    file:close()
    herdr = path
    break
  end
end
config.default_prog = { herdr }

-- Silent: no bell sound anywhere. Bells otherwise go unnoticed: agent alerts
-- come from Herdr instead, which posts macOS notifications when an agent
-- finishes or needs input.
config.audible_bell = 'Disabled'

-- macOS niceties
config.native_macos_fullscreen_mode = true
config.window_close_confirmation = 'NeverPrompt' -- Herdr keeps everything running anyway

return config
