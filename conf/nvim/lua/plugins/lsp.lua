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
    opts = {
      servers = {
        ['*'] = {
          keys = {
            { "K", false},
            { "E", "<cmd>lua vim.lsp.buf.hover()<CR>", has = "hover"},
            { "<a-n>", false},
            { "<a-k>", function() Snacks.words.jump(vim.v.count1, true) end, has = "documentHighlight",
              desc = "Next Reference", enabled = function() return Snacks.words.is_enabled() end },
          },
        },
      },
    },
    -- opts = function()
    --   local keys = require("lazyvim.plugins.lsp.keymaps").get()
    --   keys[#keys + 1] = { "K", false }
    --   keys[#keys + 1] = { "K", "N" }
    --   keys[#keys + 1] = { "<M-n>", false }
    --   keys[#keys + 1] = { "<Tab>", false }
    --   keys[#keys + 1] = { "E", vim.lsp.buf.hover, desc = "Hover" }
    -- end,
    conf = function()
      vim.lsp.enable({
        "buf_ls"
      })
    end,
  }
}
