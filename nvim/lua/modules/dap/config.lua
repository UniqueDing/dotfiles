local config = {}

function config.dap_buddy()
    local dap_install = require("dap-install")
    dap_install.setup {
        installation_path = vim.fn.stdpath "data" .. "/dapinstall/",
    }

end

function config.nvim_dap_ui()
    require("dapui").setup()
    local dap, dapui = require("dap"), require("dapui")
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
end

function config.nvim_dap_virtual_text()

end

function config.nvim_dap()
    require('modules.dap.dap-cpp')
    require('modules.dap.dap-python')
end

return config
