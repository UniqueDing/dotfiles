local config = {}


function config.nest()
    local nest = require('nest')
    local vim = vim

    vim.g.mapleader = ' '

    nest.applyKeymaps {
        { mode = 'nv', {
            -- colemak
            { ';', ':' , options = { silent = false } },
            { 'n', 'j' },
            { 'N', 'J' },
            { 'e', 'k' },
            { 'E', 'K' },
            { 'i', 'l' },
            { 'I', 'L' },
            { 'l', 'i' },
            { 'L', 'I' },
            { 'k', 'nzz' },
            { 'K', 'Nzz' },
            { 'j', 'e' },
            { 'J', 'E' },

            -- base
            { '<M-', {
                { 'n>', '5j'},
                { 'e>', '5k'},
                { 'h>', '0'},
                { 'i>', '$'},
            } },

            -- Lspsaga
            { 'ga', ':Lspsaga code_action<cr>', options = { silent = true } },
        } },

        { mode = 'n', {
            { 'gd', '<cmd>lua vim.lsp.buf.implementation()<cr>' },
            -- Lspsaga
            { 'gp', ':Lspsaga preview_definition<cr>' },
            { 'gr', ':Lspsaga rename<cr>' },
            { 'gh', ':Lspsaga lsp_finder<cr>' },
            { 'gk', ':Lspsaga hover_doc<cr>', options = { silent = true } },
            { 'gs', ':Lspsaga signature_help<cr>', options = { silent = true } },
        } },

        { '<leader>', {
            -- base
            { 'h', '<cmd>nohlsearch<cr>', options = { silent = true } },
        } },
    }
end

function config.indent_guides()
  vim.g.indent_blankline_char = "│"
  vim.g.indent_blankline_show_first_indent_level = true
  vim.g.indent_blankline_filetype_exclude = {
    "startify",
    "dashboard",
    "dotooagenda",
    "log",
    "fugitive",
    "gitcommit",
    "packer",
    "vimwiki",
    "markdown",
    "json",
    "txt",
    "vista",
    "help",
    "todoist",
    "NvimTree",
    "peekaboo",
    "git",
    "TelescopePrompt",
    "undotree",
    "flutterToolsOutline",
    "" -- for all buffers without a file type
  }
  vim.g.indent_blankline_buftype_exclude = {"terminal", "nofile"}
  vim.g.indent_blankline_show_trailing_blankline_indent = false
  vim.g.indent_blankline_show_current_context = true
  vim.g.indent_blankline_context_patterns = {
    "class",
    "function",
    "method",
    "block",
    "list_literal",
    "selector",
    "^if",
    "^table",
    "if_statement",
    "while",
    "for"
  }
  -- because lazy load indent-blankline so need readd this autocmd
  -- vim.cmd('autocmd CursorMoved * IndentBlanklineRefresh')
end

function config.comment()
end

return config
