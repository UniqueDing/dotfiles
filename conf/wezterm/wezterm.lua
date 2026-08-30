local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.use_ime = true
config.ime_preedit_rendering = "Builtin"
config.xim_im_name = "fcitx"

config.keys = {
  {
    key = "RightControl",
    action = wezterm.action.ActivateKeyTable({
      name = "right_ctrl",
      one_shot = false,
      timeout_milliseconds = 300,
      replace_current = true,
    }),
  },
}

local tmux_prefix = "\x07"

local function tmux_send(key)
  return wezterm.action.SendString(tmux_prefix .. key)
end

local function tmux_meta_send(key)
  return wezterm.action.SendString(tmux_prefix .. "\x1b" .. key)
end

local right_ctrl = {}

local function add(key, action, mods)
  table.insert(right_ctrl, {
    key = key,
    mods = mods or "CTRL",
    action = action,
  })
end

-- These are logical emitted keys, not physical QWERTY positions.
for _, mapping in ipairs({
  { "q", "1", "!" },
  { "w", "2", "@" },
  { "f", "3", "#" },
  { "p", "4", "$" },
  { "g", "5", "%" },
  { "a", "6", "^" },
  { "r", "7", "&" },
  { "s", "8", "*" },
  { "t", "9", "(" },
  { "d", "0", nil }, -- No shifted d/0 mapping: there is no DWM pane 0.
}) do
  add(mapping[1], tmux_send(mapping[2]))
  if mapping[3] then
    add(mapping[1], tmux_send(mapping[3]), "CTRL|SHIFT")
  end
end

add("c", wezterm.action.CopyTo("Clipboard"))
add("v", wezterm.action.PasteFrom("Clipboard"))

for _, key in ipairs({ "x", "b", "m", "k" }) do
  add(key, tmux_meta_send(key))
end

for _, key in ipairs({ "h", "i", "n", "e", "l", "u", "y", "z", "j" }) do
  add(key, tmux_meta_send(key))
end

add("o", tmux_send("\t"))
add("Backspace", tmux_send("\x1b"))
add("Enter", tmux_send("\r"))
add("Space", tmux_send(" "))
add(",", tmux_send(","))
add(".", tmux_send("."))
add("[", tmux_send("["))
add("]", tmux_send("]"))

config.key_tables = {
  right_ctrl = right_ctrl,
}

return config
