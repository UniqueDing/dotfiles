local ui = {}

-- colorscheme
ui["catppuccin/nvim"] = {
	lazy = false,
	name = "catppuccin",
	config = require("ui.catppuccin"),
}
-- ui["sainnhe/edge"] = {
-- 	lazy = true,
-- 	config = require("ui.edge"),
-- }

ui["rmehri01/onenord.nvim"] = {
	lazy = false,
	config = require("ui.onenord"),
}

-- greeter
ui["nvimdev/dashboard-nvim"] = {
	lazy = true,
	event = "BufWinEnter",
    config = require("ui.dashboard"),
    dependencies = { {'nvim-tree/nvim-web-devicons'}}
}

ui["nvim-lualine/lualine.nvim"] = {
	lazy = true,
	event = { "BufReadPost", "BufAdd", "BufNewFile" },
	config = require("ui.lualine"),
}

ui["akinsho/bufferline.nvim"] = {
	lazy = true,
	event = { "BufReadPost", "BufAdd", "BufNewFile" },
	config = require("ui.bufferline"),
}

-- Standalone UI for nvimlsp progress
ui["j-hui/fidget.nvim"] = {
	lazy = true,
	event = "BufReadPost",
    branch = "legacy",
	config = require("ui.fidget"),
}

ui["lewis6991/gitsigns.nvim"] = {
	lazy = true,
	event = { "CursorHold", "CursorHoldI" },
	config = require("ui.gitsigns"),
}

ui["lukas-reineke/indent-blankline.nvim"] = {
	lazy = true,
	event = "BufReadPost",
	config = require("ui.indent-blankline"),
}

-- Neovim plugin for dimming the highlights of unused functions, variables, parameters, and more
ui["zbirenbaum/neodim"] = {
	lazy = true,
	event = "LspAttach",
	config = require("ui.neodim"),
}

-- smooth scroll
ui["karb94/neoscroll.nvim"] = {
	lazy = true,
	event = "BufReadPost",
	config = require("ui.neoscroll"),
}

ui["rcarriga/nvim-notify"] = {
	lazy = true,
	event = "VeryLazy",
	config = require("ui.notify"),
}

ui["folke/paint.nvim"] = {
	lazy = true,
	event = { "CursorHold", "CursorHoldI" },
	config = require("ui.paint"),
}

ui["dstein64/nvim-scrollview"] = {
	lazy = true,
	event = "BufReadPost",
	config = require("ui.scrollview"),
}

-- Show where your cursor moves when jumping large distances
-- ui["edluffy/specs.nvim"] = {
-- 	lazy = true,
-- 	event = "CursorMoved",
-- 	config = require("ui.specs"),
-- }

return ui
