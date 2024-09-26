local bind = require("core.bind")
local map_cr = bind.map_cr
-- local map_cu = bind.map_cu
-- local map_cmd = bind.map_cmd
-- local map_callback = bind.map_callback

local plug_map = {
	-- Plugin MarkdownPreview
	["n|<leader>mm"] = map_cr("MarkdownPreviewToggle"):with_noremap():with_silent():with_desc("tool: Preview markdown"),
	["n|<leader>ms"] = map_cr("ClangdSwitchSourceHeader"):with_noremap():with_silent():with_desc("tool: Clangd switch source header"),
}

bind.nvim_load_mapping(plug_map)
