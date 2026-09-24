-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-- | q       | w       | f       | p       | g       | j       | l       | u       | y       | ;       |
-- | win1    | win2    | win3    | win4    | win5    | master  | width+  | width-  | copyMd  | --      |
-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-- | a       | r       | s       | t       | d       | h       | n       | e       | i       | o       |
-- | win6    | win7    | win8    | win9    | win0    | prevWin | nextPn  | prevPn  | nextWin | newPane |
-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-- | z       | x       | c       | v       | b       | k       | m       | ,       | .       | /       |
-- | reload  | killPn  | copy    | paste   | lastWin | newWin  | zoomPn  | rotate< | rotate> | --      |
-- +---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()
local is_macos = wezterm.target_triple:match("%-darwin$") ~= nil
local is_linux = wezterm.target_triple:match("%-linux") ~= nil

config.use_ime = true

local tmux_prefix = "\x07"

-- These are logical emitted Colemak keys, not physical QWERTY positions.
local window_selection_mappings = {
  { "q", "!" },
  { "w", "@" },
  { "f", "#" },
  { "p", "$" },
  { "g", "%" },
  { "a", "^" },
  { "r", "&" },
  { "s", "*" },
  { "t", "(" },
  { "d" }, -- No join-to-window-0 binding.
}

local function tmux_send(key)
  return act.SendString(tmux_prefix .. key)
end

local common_tmux_keys = {
  "h", "i", "n", "e", "l", "u", "y", "z",
  "j", "k", "m", "x", "b", "o", ",", ".",
}

local function bind_common_tmux_mappings(bind)
  for _, key in ipairs(common_tmux_keys) do
    bind(key, tmux_send(key))
  end
end

if is_macos then
  -- Let Ctrl+click bypass tmux mouse reporting and open terminal links.
  config.bypass_mouse_reporting_modifiers = "CTRL"
  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "CTRL",
      action = act.OpenLinkAtMouseCursor,
    },
    {
      event = { Down = { streak = 1, button = "Left" } },
      mods = "CTRL",
      action = act.Nop,
    },
  }

  local keys = {}
  local function bind(key, action)
    table.insert(keys, { key = "mapped:" .. key, mods = "CMD", action = action })
  end

  local function paste_for_active_program(window, pane)
    local process = pane:get_foreground_process_name() or ""

    if process:match("opencode") then
      -- OpenCode reads clipboard images and text through its Ctrl-V handler.
      window:perform_action(act.SendString("\x16"), pane)
      return
    end

    window:perform_action(act.PasteFrom("Clipboard"), pane)
  end

  for _, mapping in ipairs(window_selection_mappings) do
    bind(mapping[1], tmux_send(mapping[1]))
  end

  bind_common_tmux_mappings(bind)
  bind("v", wezterm.action_callback(paste_for_active_program))

  config.keys = keys
elseif is_linux then
  -- The Deepin package wrapper leaks a private library path. Start the shell
  -- without it so terminal programs use their own compatible shared libraries.
  config.default_prog = {
    "/usr/bin/env",
    "-u",
    "LD_LIBRARY_PATH",
    "/bin/bash",
    "-l",
  }
  config.ime_preedit_rendering = "Builtin"
  config.xim_im_name = "fcitx"

  config.keys = {
    {
      key = "RightControl",
      action = act.ActivateKeyTable({
        name = "right_ctrl",
        one_shot = false,
        timeout_milliseconds = 1000,
        replace_current = true,
      }),
    },
  }

  local right_ctrl = {}
  local function add(key, action, mods)
    table.insert(right_ctrl, {
      key = key,
      mods = mods or "CTRL",
      action = action,
    })
  end

  for _, mapping in ipairs(window_selection_mappings) do
    add(mapping[1], tmux_send(mapping[1]))
    if mapping[2] then
      add(mapping[1], tmux_send(mapping[2]), "CTRL|SHIFT")
    end
  end

  add("c", act.CopyTo("Clipboard"))
  add("v", act.PasteFrom("Clipboard"))

  bind_common_tmux_mappings(add)

  config.key_tables = {
    right_ctrl = right_ctrl,
  }
end

return config
