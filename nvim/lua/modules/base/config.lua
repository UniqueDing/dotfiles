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
end

function config.comment()
end

return config
