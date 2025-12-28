return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- lua
        "stylua",
        -- bash
        "shfmt",
        -- c/cpp
        "clangd",
        -- protobuf
        "buf",
        -- json
        "json-lsp",
        -- nix
        "nil",
        -- markdown
        "markdownlint-cli2",
        "markdown-toc",
        -- docker
        "hadolint",
        -- python
        "ruff",
        -- yaml
        "yaml-language-server",
        -- vue
        "vue-language-server",
        -- go
        "gopls",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "K", false }
      keys[#keys + 1] = { "K", "N" }
      keys[#keys + 1] = { "<M-n>", false }
      keys[#keys + 1] = { "<Tab>", false }
      keys[#keys + 1] = { "E", vim.lsp.buf.hover, desc = "Hover" }
    end,
    conf = function()
      vim.lsp.enable({
        "buf_ls"
      })
    end,
  }
}
