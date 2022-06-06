local base = {}
local conf = require('modules.base.config')

base['LionC/nest.nvim'] = {
    config = conf.nest,
}

base['numToStr/Comment.nvim'] = {
    config = conf.comment,
}

return base
