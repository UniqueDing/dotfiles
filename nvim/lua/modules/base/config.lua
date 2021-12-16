local config = {}


function config.nest()
    local nest = require('nest')
    local vim = vim

    vim.g.mapleader = ' '

    nest.applyKeymaps {
        { mode = 'nvx', {
            -- colemak
            { ';', ':' , options = { silent = false, noremap = true } },
            { 'n', 'j' },
            { 'N', 'J' },
            { 'e', 'k' },
            { 'E', 'K' },
            { 'i', 'l' },
            { 'I', 'L' },
            { 'l', 'i' },
            { 'L', 'I' },
            { 'j', 'e' },
            { 'J', 'E' },
            { 'cl', 'ci' }, -- don't know reason
            { 'k', 'nzz' },
            { 'K', 'Nzz' },

            -- base
            { '<M-', {
                { 'n>', '5j'},
                { 'e>', '5k'},
                { 'h>', '0'},
                { 'i>', '$'},

                -- buffer
                { '1>', ':BufferLineGoToBuffer 1<cr>' },
                { '2>', ':BufferLineGoToBuffer 2<cr>' },
                { '3>', ':BufferLineGoToBuffer 3<cr>' },
                { '4>', ':BufferLineGoToBuffer 4<cr>' },
                { '5>', ':BufferLineGoToBuffer 5<cr>' },
                { '6>', ':BufferLineGoToBuffer 6<cr>' },
                { '7>', ':BufferLineGoToBuffer 7<cr>' },
                { '8>', ':BufferLineGoToBuffer 8<cr>' },
                { '9>', ':BufferLineGoToBuffer 9<cr>' },
            } },
            { '<tab>', {
                -- buffer
                { 'n', ':BufferLineCycleNext<cr>' },
                { 'e', ':BufferLineCyclePrev<cr>' },
                { 'h', ':BufferLineMoveNext<cr>' },
                { 'i', ':BufferLineMovePrev<cr>' },
                { 'qq', ':bdelete<cr>' },
                { 'qh', ':BufferLineCloseLeft<cr>' },
                { 'qi', ':BufferLineCloseLeft<cr>' },

                -- nvim-tree
                { '<tab>', ':NvimTreeToggle<cr>' },
            } },

            -- Lspsaga
            { 'ga', ':Lspsaga code_action<cr>', options = { silent = true } },

            { '<leader>', {
                -- base
                { 'h', ':nohlsearch<cr>', options = { silent = true } },
            } },
        } },

        { mode = 'n', {
            { 'gd', '<cmd>lua vim.lsp.buf.implementation()<cr>' },

            -- Lspsaga
            { 'gp', ':Lspsaga preview_definition<cr>' },
            { 'gr', ':Lspsaga rename<cr>' },
            { 'gh', ':Lspsaga lsp_finder<cr>' },
            { 'gk', ':Lspsaga hover_doc<cr>', options = { silent = true } },
            { 'gs', ':Lspsaga signature_help<cr>', options = { silent = true } },

            { '<leader>', {
                { 'ms', ':ClangdSwitchSourceHeader<cr>' },

                -- Lspsaga
                { 'ml', 'Lspsaga show_line_diagnostics<cr>' },
                { 'mc', 'Lspsaga show_cursor_diagnostics<cr>' },

                -- code_runner
                { 'rr', ':RunCode<cr>', options = { silent = false } },
                { 'rf', ':RunFile<cr>', options = { silent = false } },
                { 'rp', ':RunProject<cr>', options = { silent = false } },
                { 'rcf', ':CRFiletype<cr>', options = { silent = false } },
                { 'rcp', ':CRProjects<cr>', options = { silent = false } },

                -- telescope
                { 'ff', ':Telescope find_files<cr>' },
                { 'fl', ':Telescope live_grep<cr>' },
                { 'fb', ':Telescope buffers<cr>' },
                { 'fs', ':Telescope grep_string<cr>' },
                { 'fh', ':Telescope help_tags<cr>' },
                { 'fg', ':Telescope git_status<cr>' },
            } },
        } },


        -- { mode = 'v', {
            --{ '<leader>', {
            --} },
        -- } },
    }
end

function config.comment()
    require('Comment').setup({
        ---Add a space b/w comment and the line
        ---@type boolean
        padding = true,

        ---Whether the cursor should stay at its position
        ---NOTE: This only affects NORMAL mode mappings and doesn't work with dot-repeat
        ---@type boolean
        sticky = true,

        ---Lines to be ignored while comment/uncomment.
        ---Could be a regex string or a function that returns a regex string.
        ---Example: Use '^$' to ignore empty lines
        ---@type string|function
        ignore = nil,

        ---LHS of toggle mappings in NORMAL + VISUAL mode
        ---@type table
        toggler = {
            ---line-comment keymap
            line = 'gcc',
            ---block-comment keymap
            block = 'gbc',
        },

        ---LHS of operator-pending mappings in NORMAL + VISUAL mode
        ---@type table
        opleader = {
            ---line-comment keymap
            line = 'gc',
            ---block-comment keymap
            block = 'gb',
        },

        ---Create basic (operator-pending) and extended mappings for NORMAL + VISUAL mode
        ---@type table
        mappings = {
            ---operator-pending mapping
            ---Includes `gcc`, `gcb`, `gc[count]{motion}` and `gb[count]{motion}`
            ---NOTE: These mappings can be changed individually by `opleader` and `toggler` config
            basic = true,
            ---extra mapping
            ---Includes `gco`, `gcO`, `gcA`
            extra = true,
            ---extended mapping
            ---Includes `g>`, `g<`, `g>[count]{motion}` and `g<[count]{motion}`
            extended = false,
        },

        ---Pre-hook, called before commenting the line
        ---@type fun(ctx: Ctx):string
        pre_hook = nil,

        ---Post-hook, called after commenting is done
        ---@type fun(ctx: Ctx)
        post_hook = nil,
    })
end

return config
