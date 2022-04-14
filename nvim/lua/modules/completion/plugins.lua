local completion = {}
local conf = require("modules.completion.config")

completion["neovim/nvim-lspconfig"] = {
    opt = true,
    event = "BufReadPre",
    config = conf.nvim_lsp
}
completion["williamboman/nvim-lsp-installer"] = {
    opt = true,
    after = "nvim-lspconfig"
}
completion["tami5/lspsaga.nvim"] = {opt = true, after = "nvim-lspconfig"}
completion["ray-x/lsp_signature.nvim"] = {opt = true, after = "nvim-lspconfig"}
completion["hrsh7th/nvim-cmp"] = {
    config = conf.cmp,
    -- event = "InsertEnter",
    requires = {
        {"saadparwaiz1/cmp_luasnip", after = "LuaSnip"},
        {"hrsh7th/cmp-buffer", after = "cmp_luasnip"},
        {"hrsh7th/cmp-nvim-lsp", after = "cmp-buffer"},
        {"hrsh7th/cmp-nvim-lua", after = "cmp-nvim-lsp"},
        {"hrsh7th/cmp-path", after = "cmp-nvim-lua"},
        {"f3fora/cmp-spell", after = "cmp-path"},
        {"onsails/lspkind-nvim", after = "cmp-spell"},
        {"hrsh7th/cmp-emoji", after = "lspkind-nvim"},
        {"octaltree/cmp-look", after = "cmp-emoji"},
        {"petertriho/cmp-git", after = "cmp-look", requires = "nvim-lua/plenary.nvim"},
        {
            'tzachar/cmp-tabnine',
            run = './install.sh',
            after = 'cmp-git',
            config = conf.tabnine
        }
    }
}
completion["ojroques/nvim-lspfuzzy"] = {
    requires = {
        {'junegunn/fzf'},
        {'junegunn/fzf.vim'},  -- to enable preview (optional)
      },
}
completion["L3MON4D3/LuaSnip"] = {
    before = "nvim-cmp",
    config = conf.luasnip,
    requires = "rafamadriz/friendly-snippets"
}
completion["windwp/nvim-autopairs"] = {
    after = "nvim-cmp",
    config = conf.autopairs
}
-- completion["github/copilot.vim"] = {opt = true, cmd = "Copilot"}

return completion
