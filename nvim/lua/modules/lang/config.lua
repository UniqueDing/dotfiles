local config = {}

function config.markdown_preview()
    vim.g.mkdp_browser = 'chromium'
end

function config.treesitter()
    require'nvim-treesitter.configs'.setup {
        highlight = {
            enable = true,
        },
        ensure_installed = {
            "c",
            "bash",
            "lua",
            "cpp",
            "toml",
            "json",
            "java",
            "python",
            "javascript",
            "vue",
            "html",
            "yaml",
            "markdown",
            "cmake",
        }
    }
end

return config
