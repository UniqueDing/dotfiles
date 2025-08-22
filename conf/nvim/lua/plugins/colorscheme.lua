return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    }
  },
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = {
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
      flavour = "mocha",
      transparent_background = true,
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.groups.integrations.bufferline").get()
          end
        end,
      },
    },
  },
  {
    "AlexvZyl/nordic.nvim",
    lazy = true,
    config = function()
      require('nordic').setup({
        transparent = {
            -- Enable transparent background.
            bg = true,
            -- Enable transparent background for floating windows.
            float = true,
        },
      })
    end
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {
      transparent = true,
    },
  },
  {
    "olimorris/onedarkpro.nvim",
    lazy = true,
    config = function()
      require("onedarkpro").setup({
        options = {
          transparency = true,
        },
      })
    end
  },
  {
    "Mofiqul/dracula.nvim",
    lazy = true,
    config = function()
      require("dracula").setup({
        transparent_bg = true,
      })
    end
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    config = function()
      require("gruvbox").setup({
        transparent_mode = true,
      })
    end
  }
}
