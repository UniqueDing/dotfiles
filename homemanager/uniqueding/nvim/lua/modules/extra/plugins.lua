local extra = {}
local conf = require('modules.extra.config')

extra['lambdalisue/suda.vim']  = {
}

extra['wakatime/vim-wakatime']  = {
}

extra['h-hg/fcitx.nvim']  = {
}

extra['glacambre/firenvim'] = {
    run = function() vim.fn['firenvim#install'](0) end
}
return extra
