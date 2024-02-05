local lang = {}

-- lang["simrat39/rust-tools.nvim"] = {
-- 	lazy = true,
-- 	ft = "rust",
-- 	config = require("lang.rust-tools"),
-- 	dependencies = { "nvim-lua/plenary.nvim" },
-- }
-- lang["Saecki/crates.nvim"] = {
--     lazy = true,
--     event = "BufReadPost Cargo.toml",
--     config = require("lang.crates"),
--     dependencies = { "nvim-lua/plenary.nvim" },
-- }
lang["iamcco/markdown-preview.nvim"] = {
	lazy = true,
	ft = "markdown",
	build = ":call mkdp#util#install()",
	config = require("lang.markdownpreview"),
}
lang["chrisbra/csv.vim"] = {
    lazy = true,
    ft = "csv",
}
lang["p00f/clangd_extensions.nvim"] = {
    lazy = true,
    ft = "cpp",
}
return lang
