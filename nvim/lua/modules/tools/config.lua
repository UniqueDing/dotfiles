local config = {}

function config.code_runner()
    require('code_runner').setup{
        term = {
            position = "belowright",
            tab = false,
            mode = ""
        },
        filetype = {
            java = "cd $dir && javac $fileName && java $fileNameWithoutExt",
            python = "python",
            racket = "racket",
            typescript = "deno run",
            rust = "cd $dir && rustc $fileName && $dir/$fileNameWithoutExt",
            cpp = "cd $dir && g++ -pthread $fileName && $dir/a.out",
            c = "cd $dir && gcc $fileName && $dir/a.out",
            sh = "cd $dir && bash $fileName",
            zsh = "cd $dir && zsh $fileName"
        }
    }
end

function config.rnvimr()
    vim.g.rnvimr_enable_ex = 1
    vim.g.rnvimr_enable_picker = 1
    vim.g.rnvimr_enable_bw = 1
    vim.g.rnvimr_hide_gitignore = 0
    vim.g.rnvimr_ranger_cmd = 'ranger.py'
    vim.g.rnvimr_edit_cmd = 'drop'
    -- vim.g.rnvimr_ranger_cmd = 'ranger.py --cmd="set draw_borders both"'
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
