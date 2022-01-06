local config = {}

function config.code_runner()
    require('code_runner').setup{
        filetype_path = "/home/uniqueding/.config/nvim/lua/modules/tools/code_runner.json",
        -- project_path = "~/.config/nvim/lua/modules/tools/projects.json",
    }
end

function config.rnvimr()
    vim.g.rnvimr_enable_ex = 1
    vim.g.rnvimr_enable_picker = 1
    vim.g.rnvimr_enable_bw = 1
    vim.g.rnvimr_hide_gitignore = 0
    vim.g.rnvimr_ranger_cmd = 'ranger.py --cmd="set draw_borders both"'
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
