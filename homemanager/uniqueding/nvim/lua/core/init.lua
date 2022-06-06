require("settings")
--require("plugins")

function load_core()
    local pack = require("core.pack")
    pack.ensure_plugins()
    pack.load_compile()
end

load_core()

