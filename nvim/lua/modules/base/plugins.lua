local base = {}
local conf = require('modules.base.config')

base['LionC/nest.nvim'] = {
    config = conf.nest,
}

base['glepnir/indent-guides.nvim'] = {
    config = conf.indent_guides,
}

base['numToStr/Comment.nvim'] = {
    config = conf.comment,
}

base['yamatsum/nvim-cursorline'] = {
}

return base
