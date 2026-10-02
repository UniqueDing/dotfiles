local completion = {}

completion["neovim/nvim-lspconfig"] = {
	lazy = true,
	event = { "CursorHold", "CursorHoldI" },
	config = require("completion.lsp"),
	dependencies = {
		{ "williamboman/mason.nvim" },
		{ "williamboman/mason-lspconfig.nvim" },
		{ "folke/neoconf.nvim" },
		{
			"Jint-lzxy/lsp_signature.nvim",
			config = require("completion.lsp-signature"),
		},
	},
}
completion["nvimdev/lspsaga.nvim"] = {
	lazy = true,
	event = "LspAttach",
	config = require("completion.lspsaga"),
	dependencies = { "nvim-tree/nvim-web-devicons" },
}
completion["stevearc/aerial.nvim"] = {
	lazy = true,
	event = "LspAttach",
	config = require("completion.aerial"),
}
completion["DNLHC/glance.nvim"] = {
	lazy = true,
	event = "LspAttach",
	config = require("completion.glance"),
}
completion["joechrisellis/lsp-format-modifications.nvim"] = {
	lazy = true,
	event = "LspAttach",
}
completion["nvimtools/none-ls.nvim"] = {
	lazy = true,
	event = { "CursorHold", "CursorHoldI" },
	config = require("completion.null-ls"),
	dependencies = {
		"nvim-lua/plenary.nvim",
		"jay-babu/mason-null-ls.nvim",
	},
}

completion["hrsh7th/nvim-cmp"] = {
	lazy = true,
	event = "InsertEnter",
	config = require("completion.cmp"),
	dependencies = {
		{
			"L3MON4D3/LuaSnip",
			dependencies = { "rafamadriz/friendly-snippets" },
			config = require("completion.luasnip"),
		},
		{ "onsails/lspkind.nvim" },
		{ "lukas-reineke/cmp-under-comparator" },
		{ "saadparwaiz1/cmp_luasnip" },
		{ "hrsh7th/cmp-nvim-lsp" },
		{ "hrsh7th/cmp-nvim-lua" },
		{ "andersevenrud/cmp-tmux" },
		{ "hrsh7th/cmp-path" },
		{ "f3fora/cmp-spell" },
		{ "hrsh7th/cmp-buffer" },
		{ "kdheepak/cmp-latex-symbols" },
		{ "ray-x/cmp-treesitter" },
		-- { "tzachar/cmp-tabnine", build = "./install.sh", config = require("completion.tabnine") },
		-- {
			-- "jcdickinson/codeium.nvim",
			-- dependencies = {
			-- 	"nvim-lua/plenary.nvim",
			-- 	"MunifTanjim/nui.nvim",
			-- },
			-- config = require("completion.codeium"),
		-- },
	},
}
return completion
