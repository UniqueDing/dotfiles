local ui = {}
local conf = require('modules.ui.config')

ui['dracula/vim'] = {
    config = [[vim.cmd('colorscheme dracula')]]
}
ui['glepnir/dashboard-nvim'] = {
    config = conf.dashboard,
}
ui['glepnir/galaxyline.nvim'] = {
    config = conf.galaxyline,
    requires = {
        'kyazdani42/nvim-web-devicons',
        opt = true
    }
}
ui['akinsho/nvim-bufferline.lua'] = {
    config = conf.bufferline,
    requires = {
        'kyazdani42/nvim-web-devicons',
    }
}
ui['kyazdani42/nvim-tree.lua'] = {
    cmd = {'NvimTreeToggle','NvimTreeOpen'},
    config = conf.tree,
    requires = {
        'kyazdani42/nvim-web-devicons'
    }
}

return ui
