return function()
	local colors = require("onenord.colors").load()
	require("onenord").setup({
		borders = false, -- Split window borders
		fade_nc = false, -- Fade non-current windows, making them more distinguishable
		disable = {
			background = true, -- Disable setting the background color
			cursorline = false, -- Disable the cursorline
			eob_lines = true, -- Hide the end-of-buffer lines
		},
		custom_highlights = {
			NormalFloat = { bg = colors.none },
			FloatBorder = { bg = colors.none },
			Pmenu = { bg = colors.none },
			PmenuSbar = { bg = colors.none },
			PmenuThumb = { bg = colors.none },
			SagaNormal = { bg = colors.none },
			SagaBorder = { bg = colors.none },
			TelescopeNormal = { bg = colors.none },
			WhichKeyFloat = { bg = colors.none },

			-- For native lsp configs.
			DiagnosticVirtualTextError = { bg = colors.none },
			DiagnosticVirtualTextWarn = { bg = colors.none },
			DiagnosticVirtualTextInfo = { bg = colors.none },
			DiagnosticVirtualTextHint = { bg = colors.none },
		}, -- Overwrite default highlight groups
	})
end
