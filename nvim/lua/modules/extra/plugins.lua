local extra = {}
local conf = require('modules.extra.config')

extra['lambdalisue/suda.vim']  = {
}

extra['edluffy/specs.nvim']  = {
}

extra['wakatime/vim-wakatime']  = {
}

extra['lilydjwg/fcitx.vim']  = {
}

extra['lewis6991/gitsigns.nvim']  = {
    requires = {'nvim-lua/plenary.nvim'},
    config = conf.gitsigns
}

return extra
