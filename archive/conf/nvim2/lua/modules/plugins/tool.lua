local tool = {}

tool["tpope/vim-fugitive"] = {
	lazy = true,
	cmd = { "Git", "G" },
}
-- Please don't remove which-key.nvim otherwise you need to set timeoutlen=300 at `lua/core/options.lua`
tool["folke/which-key.nvim"] = {
	lazy = true,
	event = "VeryLazy",
	config = require("tool.which-key"),
}
-- only for fcitx5 user who uses non-English language during coding
tool["pysan3/fcitx5.nvim"] = {
	lazy = true,
	event = "BufReadPost",
	cond = vim.fn.executable("fcitx5-remote") == 1,
	config = require("tool.fcitx5"),
}
-- tool["welandx/fcitx5-switch.nvim"] = {
-- 	lazy = true,
-- 	event = "BufRead",
-- 	ft = "markdown",
-- 	config = function()
-- 		require("fcitx5-switch").Leave_enter_cmd()
-- 	end,
-- }

tool["wakatime/vim-wakatime"] = {
	lazy = false,
}

tool["lambdalisue/suda.vim"] = {
	lazy = true,
	event = "VeryLazy",
	cmd = { "SudaRead", "SudaWrite" },
}

tool["chipsenkbeil/distant.nvim"] = {
	branch = "v0.3",
	config = function()
		require("distant"):setup()
	end,
}

tool["mikavilpas/yazi.nvim"] = {
	lazy = true,
	event = "VeryLazy",
	config = require("tool.yazi"),
}

tool["nvim-tree/nvim-tree.lua"] = {
	lazy = true,
	cmd = {
		"NvimTreeToggle",
		"NvimTreeOpen",
		"NvimTreeFindFile",
		"NvimTreeFindFileToggle",
		"NvimTreeRefresh",
	},
	config = require("tool.nvim-tree"),
}
tool["michaelb/sniprun"] = {
	lazy = true,
	-- You need to cd to `~/.local/share/nvim/site/lazy/sniprun/` and execute `bash ./install.sh`,
	-- if you encountered error about no executable sniprun found.
	build = "bash ./install.sh",
	cmd = { "SnipRun" },
	config = require("tool.sniprun"),
}
tool["akinsho/toggleterm.nvim"] = {
	lazy = true,
	cmd = {
		"ToggleTerm",
		"ToggleTermSetName",
		"ToggleTermToggleAll",
		"ToggleTermSendVisualLines",
		"ToggleTermSendCurrentLine",
		"ToggleTermSendVisualSelection",
	},
	config = require("tool.toggleterm"),
}
tool["sindrets/diffview.nvim"] = {
	lazy = true,
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
}
tool["folke/trouble.nvim"] = {
	lazy = true,
	cmd = { "Trouble", "TroubleToggle", "TroubleRefresh" },
	config = require("tool.trouble"),
}
-- wildmenu
tool["gelguy/wilder.nvim"] = {
	lazy = true,
	event = "CmdlineEnter",
	config = require("tool.wilder"),
	dependencies = { "romgrk/fzy-lua-native" },
}
-- gpt
tool["jackMort/ChatGPT.nvim"] = {
	event = "VeryLazy",
	config = require("tool.chatgpt"),
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"folke/trouble.nvim",
		"nvim-telescope/telescope.nvim",
	},
}

----------------------------------------------------------------------
--                        Telescope Plugins                         --
----------------------------------------------------------------------
tool["nvim-telescope/telescope.nvim"] = {
	lazy = true,
	cmd = "Telescope",
	config = require("tool.telescope"),
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{ "nvim-tree/nvim-web-devicons" },
		{ "jvgrootveld/telescope-zoxide" },
		{ "debugloop/telescope-undo.nvim" },
		{ "nvim-telescope/telescope-frecency.nvim" },
		{ "nvim-telescope/telescope-live-grep-args.nvim" },
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{
			"FabianWirth/search.nvim",
			config = require("tool.search"),
		},
		{
			"ahmedkhalf/project.nvim",
			event = { "CursorHold", "CursorHoldI" },
			config = require("tool.project"),
		},
		{
			"aaronhallaert/advanced-git-search.nvim",
			cmd = { "AdvancedGitSearch" },
			dependencies = {
				"tpope/vim-rhubarb",
				"tpope/vim-fugitive",
				"sindrets/diffview.nvim",
			},
		},
	},
}

----------------------------------------------------------------------
--                           DAP Plugins                            --
----------------------------------------------------------------------
tool["mfussenegger/nvim-dap"] = {
	lazy = true,
	cmd = {
		"DapSetLogLevel",
		"DapShowLog",
		"DapContinue",
		"DapToggleBreakpoint",
		"DapToggleRepl",
		"DapStepOver",
		"DapStepInto",
		"DapStepOut",
		"DapTerminate",
	},
	config = require("tool.dap"),
	dependencies = {
		{
			"rcarriga/nvim-dap-ui",
			config = require("tool.dap.dapui"),
		},
	},
}

return tool
