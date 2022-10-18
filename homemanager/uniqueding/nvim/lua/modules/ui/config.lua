local config = {}

function config.galaxyline()
   -- require('modules.ui.eviline')
   require('modules.ui.aeroline')
end

function config.bufferline()
    require('bufferline').setup{
        options = {
            indicator = {
                icon = '▎',
                style = 'icon',
            },
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
    }
end

function config.indent_blankline()
    vim.g.indentLine_fileTypeExclude = {'help', 'dashboard', 'alpha'}
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
      current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
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

function config.scrollbar()
    local colors = require("nord.colors")
    require("scrollbar").setup({
        handle = {
            color = colors.nord2_gui,
        },
        marks = {
            Search = { color = colors.nord12_gui },
            Error = { color = colors.nord11_gui },
            Warn = { color = colors.nord13_gui },
            Info = { color = colors.nord6_gui },
            Hint = { color = colors.nord9_gui },
            Misc = { color = colors.nord10_gui },
        }
    })
end

function config.notify()
    require("notify").setup({
        background_colour = "#000000",
    })
end

return config
