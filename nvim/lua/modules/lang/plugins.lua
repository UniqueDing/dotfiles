local lang = {}
local conf = require('modules.lang.config')

lang['iamcco/markdown-preview.nvim'] = {
    run = [[ sh -c 'cd app && npm install']],
    setup = function() vim.g.mkdp_filetypes = { "markdown" } end,
    ft = { "markdown" },
    config = conf.markdown_preview,
}

lang['nvim-treesitter/nvim-treesitter'] = {
    run = ':TSUpdate',
    config = conf.treesitter,
}

lang['liuchengxu/vista.vim'] = {
    config = conf.vista,
}

return lang
