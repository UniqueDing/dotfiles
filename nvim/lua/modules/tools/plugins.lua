local tools = {}
local conf = require('modules.tools.config')

tools['CRAG666/code_runner.nvim'] = {
    requires = 'nvim-lua/plenary.nvim',
    after = 'filetype.nvim',
    config = conf.code_runner,
}

tools['nathom/filetype.nvim'] = {
    config = conf.filetype,
}

tools['kevinhwang91/rnvimr'] = {
    config = conf.rnvimr,
}

tools['nvim-telescope/telescope.nvim'] = {
    requires = 'nvim-lua/plenary.nvim',
    config = conf.telescope,
}

return tools
