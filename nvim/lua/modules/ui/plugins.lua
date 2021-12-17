local ui = {}
local conf = require('modules.ui.config')

-- ui['glepnir/zephyr-nvim'] = {
--     -- config = [[vim.cmd('colorscheme zephyr')]]
-- }

ui['shaunsingh/nord.nvim'] = {
    config = [[vim.cmd('colorscheme nord')]]
}

-- ui['Mofiqul/dracula.nvim'] = {
--     -- config = [[vim.cmd('colorscheme dracula')]]
-- }
--
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

ui['edluffy/specs.nvim']  = {
    config = conf.specs,
}


ui['akinsho/nvim-bufferline.lua'] = {
    config = conf.bufferline,
    requires = {
        'kyazdani42/nvim-web-devicons',
    }
}

ui['kyazdani42/nvim-tree.lua'] = {
    config = conf.tree,
    requires = {
        'kyazdani42/nvim-web-devicons'
    }
}

ui['lukas-reineke/indent-blankline.nvim'] = {
    config = conf.indent_blankline,
}

ui['xiyaowong/nvim-transparent'] = {
    config = conf.transparent,
}

ui['lewis6991/gitsigns.nvim']  = {
    requires = {'nvim-lua/plenary.nvim'},
    config = conf.gitsigns,
}

ui['yamatsum/nvim-cursorline'] = {
    config = conf.cursorline,
}

ui['norcalli/nvim-colorizer.lua'] = {
    config = conf.colorizer,
}

return ui
