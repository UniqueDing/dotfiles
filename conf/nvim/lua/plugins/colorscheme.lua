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
      flavour = "mocha",
      transparent_background = true,
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
