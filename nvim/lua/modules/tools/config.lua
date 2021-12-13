local config = {}

function config.code_runner()
    require('code_runner').setup{
        filetype_path = "~/.config/nvim/lua/modules/tools/code_runner_filetype.json",
        project_path = "~/.config/nvim/lua/modules/tools/code_runner_project.json",
    }
end

function config.filetype()
    require('filetype').setup ({
        overrides = {
            extensions = {
                rkt = "racket",
            }
        }
    })
end

return config
