local wezterm = require 'wezterm'
local config = wezterm.config_builder()

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

-- Keep the tab bar visible even with one tab: the bell highlight renders
-- in the tab bar, and hiding it made single-tab alerts invisible
config.hide_tab_bar_if_only_one_tab = false

-- Fancy tab bar in rose-pine-moon colors: quiet text-only tabs — active
-- is bold gold text (mirroring the tmux bar's active window), no fills
-- (the built-in scheme doesn't style the tab bar, so set explicitly)
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

-- Dim inactive panes (native WezTerm splits only; tmux panes get their
-- own dimming via window-style — see ~/.tmux.conf)
config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.7,
}

config.scrollback_lines = 100000

-- CMD+click to open links, working *through* tmux. With `mouse on`, tmux
-- keeps mouse reporting active, and WezTerm normally forwards clicks to the
-- app instead of matching its own bindings — so the built-in CMD+click
-- link-open only fires when reporting is off. `mouse_reporting = true` is the
-- key: it opts THESE bindings in precisely when reporting IS on (the tmux
-- case), without repurposing CMD as a global bypass modifier. Nop the Down
-- half so tmux never sees a stray click (cursor jump / copy-mode); open on Up.
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

-- One tab = one project = one tmux session.
-- New tabs open a project picker that attaches/creates the right session.
config.default_prog = { wezterm.home_dir .. '/.local/bin/wezterm-project-picker' }

-- On launch, reopen a tab for every tmux session. Delegates to bin/tmux-boot
-- (the same primitive the login LaunchAgent runs): it ensures the server is up,
-- waits for tmux-continuum's restore to settle, and prints the session list.
-- Calling it here — rather than a bare `tmux list-sessions` — closes the login
-- race: whether or not WezTerm auto-launches at boot, and whichever of WezTerm
-- vs. the agent starts first, this blocks until sessions have settled, so we
-- never build tabs from an empty or half-restored server. It's idempotent, so
-- overlapping with the agent is safe. (Cost: at most a few seconds' wait before
-- the window appears, and only when there is genuinely nothing to restore.)
wezterm.on('gui-startup', function()
  local mux = wezterm.mux
  -- pcall: run_child_process RAISES if the binary is missing, and an
  -- uncaught error here would leave WezTerm with no window at all
  local called, ok, stdout = pcall(wezterm.run_child_process, {
    wezterm.home_dir .. '/.local/bin/tmux-boot',
  })
  local window
  if called and ok and stdout ~= '' then
    for name in stdout:gmatch '[^\n]+' do
      local args = { '/opt/homebrew/bin/tmux', 'new-session', '-A', '-s', name }
      local tab
      if not window then
        tab, _, window = mux.spawn_window { args = args }
      else
        tab = window:spawn_tab { args = args }
      end
      -- explicit tab title: deterministic, immune to OSC title races
      if tab then
        tab:set_title(name)
      end
    end
  else
    mux.spawn_window {}
  end
end)

-- Silent notifications: no bell sound anywhere.
-- A bell (an agent finishing / needing attention, or any program) highlights
-- that tab; if WezTerm isn't focused, also show a silent macOS toast.
config.audible_bell = 'Disabled'

wezterm.on('bell', function(window, pane)
  local tab = pane:tab()
  if tab then
    local flags = wezterm.GLOBAL.bell_tabs or {}
    flags[tostring(tab:tab_id())] = true
    wezterm.GLOBAL.bell_tabs = flags
  end
  if not window:is_focused() then
    -- a bell is a bell — could be any program, not just an agent
    local where = tab and tab:get_title() or ''
    if where == '' then
      where = pane:get_title()
    end
    -- No timeout: on macOS persistence is the notification style, not this
    -- call. System Settings → Notifications → WezTerm → "Alerts" keeps it up
    -- until dismissed; "Banners" fades it. A timeout here withdraws it early.
    window:toast_notification('WezTerm', 'Bell in ' .. where, nil)
  end
end)

-- Tab titles: numbered, truncated; a tab whose agent rang the bell turns
-- rose with a ● until visited (colors otherwise come from the scheme)
wezterm.on('format-tab-title', function(tab)
  -- prefer the explicit tab title (set by gui-startup/picker); fall back
  -- to the pane's terminal title for tabs created any other way
  local title = tab.tab_title
  if #title == 0 then
    title = tab.active_pane.title
  end
  if #title > 24 then
    title = wezterm.truncate_right(title, 23) .. '…'
  end
  title = (tab.tab_index + 1) .. ': ' .. title

  local id = tostring(tab.tab_id)
  local flags = wezterm.GLOBAL.bell_tabs or {}
  if tab.is_active and flags[id] then
    flags[id] = nil
    wezterm.GLOBAL.bell_tabs = flags
  end

  if flags[id] then
    -- alert = dot + brightened text (same color as tab hover), bg unchanged
    return {
      { Background = { Color = '#2a273f' } },
      { Foreground = { Color = '#e0def4' } },
      { Text = ' ● ' .. title .. ' ' },
    }
  end
  return ' ' .. title .. ' '
end)

-- macOS niceties
config.native_macos_fullscreen_mode = true
config.window_close_confirmation = 'NeverPrompt' -- tmux keeps sessions alive anyway

return config
