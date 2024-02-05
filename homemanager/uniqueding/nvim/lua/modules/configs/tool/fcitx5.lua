return function()
	require("fcitx5").setup({
		msg = "hhh", -- string | nil: printed when startup is completed
		-- imname = { -- fcitx5.Imname | nil: imnames on each mode set as prior. See `:h map-table` for more in-depth information.
		-- 	norm = "keyboard-us", -- string | nil: imname to set in normal mode. if nil, will restore the mode on exit.
		-- 	ins = "rime",
		-- 	cmd = "keyboard-us-colemak",
		-- },
		remember_prior = true, -- boolean: if true, it remembers the mode on exit and restore it when entering the mode again.
		--                                 if false, uses what was set in config.
		define_autocmd = true, -- boolean: if true, defines autocmd at `ModeChanged` to switch fcitx5 mode.
		log = "warn", -- string: log level (default: warn)
	})
end
