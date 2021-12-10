local lang = {}
local conf = require('modules.lang.config')

lang['iamcco/markdown-preview.nvim'] = {
    run = [[ sh -c 'cd app && npm install']],
    setup = function() vim.g.mkdp_filetypes = { "markdown" } end, 
    ft = { "markdown" },
    config = conf.markdown_preview,
}

return lang
