local config = {}

function config.dashboard()
    local home = os.getenv('HOME')
    vim.g.dashboard_footer_icon = '🐬 '
    vim.g.dashboard_preview_command = 'cat'
    -- vim.g.dashboard_preview_pipeline = 'lolcat -F 0.3'
    -- vim.g.dashboard_preview_file = home .. '/.config/nvim/static/neovim.cat'
    vim.g.dashboard_preview_file_height = 12
    vim.g.dashboard_preview_file_width = 80
    vim.g.dashboard_default_executive = 'telescope'
    vim.g.dashboard_custom_section = {
      last_session = {
        description = {'  Recently laset session                  SPC s l'},
        command =  'SessionLoad'},
      find_history = {
        description = {'  Recently opened files                   SPC f h'},
        command =  'DashboardFindHistory'},
      find_file  = {
        description = {'  Find  File                              SPC f f'},
        command = 'Telescope find_files find_command=rg,--hidden,--files'},
      new_file = {
       description = {'  File Browser                            SPC f b'},
       command =  'Telescope file_browser'},
      find_word = {
       description = {'  Find  word                              SPC f w'},
       command = 'DashboardFindWord'},
      find_dotfiles = {
       description = {'  Open Personal dotfiles                  SPC f d'},
       command = 'Telescope dotfiles path=' .. home ..'/github/dotfiles'},
      go_source = {
       description = {'  Find Go Source Code                     SPC f s'},
       command = 'Telescope gosource'},
    }
end

function config.galaxyline()
   -- require('modules.ui.eviline')
   require('modules.ui.aeroline')
end

function config.bufferline()
    require('bufferline').setup{
        options = {
            indicator_icon = '▎',
            buffer_close_icon = '',
            modified_icon = '●',
            close_icon = '',
            left_trunc_marker = '',
            right_trunc_marker = '',
            diagnostic = "nvim_lsp",
            -- numbers = function(opts)
                -- return string.format('%s·%s', opts.raise(opts.id), opts.lower(opts.original))
            -- end
        }
    }
end

function config.tree()
    require'nvim-tree'.setup {
        disable_netrw       = true,
        hijack_netrw        = true,
        open_on_setup       = false,
        ignore_ft_on_setup  = {},
        auto_close          = false,
        open_on_tab         = false,
        hijack_cursor       = false,
        update_cwd          = false,
        update_to_buf_dir   = {
          enable = true,
          auto_open = true,
        },
        diagnostics = {
          enable = false,
          icons = {
            hint = "",
            info = "",
            warning = "",
            error = "",
          }
        },
        update_focused_file = {
          enable      = false,
          update_cwd  = false,
          ignore_list = {}
        },
        system_open = {
          cmd  = nil,
          args = {}
        },
        filters = {
          dotfiles = false,
          custom = {}
        },
        git = {
          enable = true,
          ignore = true,
          timeout = 500,
        },
        view = {
          width = 30,
          height = 30,
          hide_root_folder = false,
          side = 'left',
          auto_resize = false,
          mappings = {
            custom_only = false,
            list = {}
          },
          number = false,
          relativenumber = false
        },
        trash = {
          cmd = "trash",
          require_confirm = true
        }
    }
end

function config.indent_blankline()
    vim.g.indentLine_fileTypeExclude = {'help', 'dashboard'}
    require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
    }
end

function config.specs()
    require('specs').setup{
    show_jumps  = true,
    min_jump = 30,
    popup = {
        delay_ms = 0, -- delay before popup displays
        inc_ms = 10, -- time increments used for fade/resize effects
        blend = 10, -- starting blend, between 0-100 (fully transparent), see :h winblend
        width = 10,
        winhl = "PMenu",
        fader = require('specs').linear_fader,
        resizer = require('specs').shrink_resizer
    },
    ignore_filetypes = {},
    ignore_buftypes = {
        nofile = true,
    },
}
end

function config.transparent()
    require("transparent").setup{
        enable = true, -- boolean: enable transparent
        extra_groups = { -- table/string: additional groups that should be clear
          -- In particular, when you set it to 'all', that means all avaliable groups
        },
        exclude = {
            "BufferLineTabClose",
            "BufferlineBufferSelected",
            "BufferLineFill",
            "BufferLineBackground",
            "BufferLineSeparator",
            "BufferLineIndicatorSelected",
        }, -- table: groups you don't want to clear
    }
end

function config.gitsigns()
    if not vim.g.pack_plenary_loaded then
        vim.cmd [[packadd plenary.nvim]]
        vim.g.pack_plenary_loaded = true
    end
    vim.cmd[[highlight GitSignsCurrentLineBlame guifg = #999999]]
    require('gitsigns').setup {
        signs = {
        add = {hl = 'GitSignsAdd', text = '▋', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn'},
        change = {hl = 'GitSignsChange', text = '▋', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
        delete = {hl = 'GitSignsDelete', text = '▋', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
        topdelete = {hl = 'GitSignsDelete', text = '‾', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
        changedelete = {hl = 'GitSignsChange', text = '▎', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
      },
      signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
      numhl      = true, -- Toggle with `:Gitsigns toggle_numhl`

      linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
      word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
      watch_gitdir = {
        interval = 1000,
        follow_files = true
      },
      keymaps = {},
      attach_to_untracked = true,
      current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
        delay = 1000,
        ignore_whitespace = false,
      },
      current_line_blame_formatter_opts = {
        relative_time = false
      },
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil, -- Use default
      max_file_length = 40000,
      preview_config = {
        -- Options passed to nvim_open_win
        border = 'single',
        style = 'minimal',
        relative = 'cursor',
        row = 0,
        col = 1
      },
      yadm = {
        enable = false
      },
  }
end

function config.cursorline()
end

function config.colorizer()
    require('colorizer').setup()
end

return config
