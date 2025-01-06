return {
  "neovim/nvim-lspconfig",
  init = function()
    local keys = require("lazyvim.plugins.lsp.keymaps").get()
    keys[#keys + 1] = { "K", false }
    keys[#keys + 1] = { "K", "N" }
    keys[#keys + 1] = { "<M-n>", false }
    keys[#keys + 1] = { "<Tab>", false }
    keys[#keys + 1] = { "E", vim.lsp.buf.hover, desc = "Hover" }
  end,
}
