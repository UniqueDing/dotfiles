local bind = require("keymap.bind")
local map_cr = bind.map_cr
-- local map_cu = bind.map_cu
-- local map_cmd = bind.map_cmd
-- local map_callback = bind.map_callback

local plug_map = {
	-- Plugin: bufferline
	["n|<A-i>"] = map_cr("BufferLineCycleNext"):with_noremap():with_silent():with_desc("buffer: Switch to next"),
	["n|<A-h>"] = map_cr("BufferLineCyclePrev"):with_noremap():with_silent():with_desc("buffer: Switch to prev"),
	["n|<leader>tH"] = map_cr("BufferLineMoveNext"):with_noremap():with_silent():with_desc("buffer: Move current to next"),
	["n|<leader>tI"] = map_cr("BufferLineMovePrev"):with_noremap():with_silent():with_desc("buffer: Move current to prev"),
	-- ["n|te"] = map_cr("BufferLineSortByExtension"):with_noremap():with_desc("buffer: Sort by extension"),
	-- ["n|td"] = map_cr("BufferLineSortByDirectory"):with_noremap():with_desc("buffer: Sort by direrctory"),
	["n|<leader>t1"] = map_cr("BufferLineGoToBuffer 1"):with_noremap():with_silent():with_desc("buffer: Goto buffer 1"),
	["n|<leader>t2"] = map_cr("BufferLineGoToBuffer 2"):with_noremap():with_silent():with_desc("buffer: Goto buffer 2"),
	["n|<leader>t3"] = map_cr("BufferLineGoToBuffer 3"):with_noremap():with_silent():with_desc("buffer: Goto buffer 3"),
	["n|<leader>t4"] = map_cr("BufferLineGoToBuffer 4"):with_noremap():with_silent():with_desc("buffer: Goto buffer 4"),
	["n|<leader>t5"] = map_cr("BufferLineGoToBuffer 5"):with_noremap():with_silent():with_desc("buffer: Goto buffer 5"),
	["n|<leader>t6"] = map_cr("BufferLineGoToBuffer 6"):with_noremap():with_silent():with_desc("buffer: Goto buffer 6"),
	["n|<leader>t7"] = map_cr("BufferLineGoToBuffer 7"):with_noremap():with_silent():with_desc("buffer: Goto buffer 7"),
	["n|<leader>t8"] = map_cr("BufferLineGoToBuffer 8"):with_noremap():with_silent():with_desc("buffer: Goto buffer 8"),
	["n|<leader>t9"] = map_cr("BufferLineGoToBuffer 9"):with_noremap():with_silent():with_desc("buffer: Goto buffer 9"),
}

bind.nvim_load_mapping(plug_map)

local mapping = {}

function mapping.gitsigns(buf)
	local actions = require("gitsigns.actions")
	local map = {
		["n|]g"] = bind.map_callback(function()
			if vim.wo.diff then
				return "]g"
			end
			vim.schedule(function()
				actions.next_hunk()
			end)
			return "<Ignore>"
		end)
			:with_buffer(buf)
			:with_expr()
			:with_desc("git: Goto next hunk"),
		["n|[g"] = bind.map_callback(function()
			if vim.wo.diff then
				return "[g"
			end
			vim.schedule(function()
				actions.prev_hunk()
			end)
			return "<Ignore>"
		end)
			:with_buffer(buf)
			:with_expr()
			:with_desc("git: Goto prev hunk"),
		["n|<leader>gs"] = bind.map_callback(function()
			actions.stage_hunk()
		end)
			:with_buffer(buf)
			:with_desc("git: Stage hunk"),
		["v|<leader>gs"] = bind.map_callback(function()
			actions.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end)
			:with_buffer(buf)
			:with_desc("git: Stage hunk"),
		["n|<leader>gu"] = bind.map_callback(function()
			actions.undo_stage_hunk()
		end)
			:with_buffer(buf)
			:with_desc("git: Undo stage hunk"),
		["n|<leader>gr"] = bind.map_callback(function()
			actions.reset_hunk()
		end)
			:with_buffer(buf)
			:with_desc("git: Reset hunk"),
		["v|<leader>gr"] = bind.map_callback(function()
			actions.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end)
			:with_buffer(buf)
			:with_desc("git: Reset hunk"),
		["n|<leader>gR"] = bind.map_callback(function()
			actions.reset_buffer()
		end)
			:with_buffer(buf)
			:with_desc("git: Reset buffer"),
		["n|<leader>gp"] = bind.map_callback(function()
			actions.preview_hunk()
		end)
			:with_buffer(buf)
			:with_desc("git: Preview hunk"),
		["n|<leader>gb"] = bind.map_callback(function()
			actions.blame_line({ full = true })
		end)
			:with_buffer(buf)
			:with_desc("git: Blame line"),
		-- Text objects
		["ox|ih"] = bind.map_callback(function()
			actions.text_object()
		end):with_buffer(buf),
	}
	bind.nvim_load_mapping(map)
end

return mapping
