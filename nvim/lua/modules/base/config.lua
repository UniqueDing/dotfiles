local config = {}

function config.nest()
    local nest = require('nest')

    vim.g.leader = ' '
    nest.applyKeymaps {
        { mode = 'nv', {
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
        } },
        { mode = 'n', {
            { 'gd', '<cmd>Lspsaga preview_definition<cr>', options = { silent = true } },
            { 'gD', '<cmd>lua vim.lsp.buf.implementation()<cr>', options = { silent = true } },
            { 'gr', '<cmd>Lspsaga rename<cr>', options = { silent = true } },
            { 'gh', '<cmd>Lspsaga lsp_finder<cr>', options = { silent = true } },
            { '<leader>ca', '<cmd>Lspsaga code_action<cr>', options = { silent = true } },
        } },

    }
end

return config
