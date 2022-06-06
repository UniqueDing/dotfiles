local dap = {}
local conf = require('modules.dap.config')

dap['mfussenegger/nvim-dap'] = {
    config = conf.nvim_dap,
    requires = 'ravenxrz/DAPInstall.nvim'
}

dap['ravenxrz/DAPInstall.nvim'] = {
    -- waiting for rewrite
    config = conf.dap_buddy,
}

dap["rcarriga/nvim-dap-ui"] = {
    config = conf.nvim_dap_ui,
    requires = 'mfussenegger/nvim-dap'
}
dap["theHamsta/nvim-dap-virtual-text"] = {
    config = conf.nvim_dap_virtual_text,
    requires = 'mfussenegger/nvim-dap'
}
return dap
