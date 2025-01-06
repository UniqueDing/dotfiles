local opt = vim.opt

-- tab
opt.expandtab = true
opt.smarttab = true
opt.softtabstop = 4
opt.tabstop = 4
opt.shiftround = true
opt.shiftwidth = 4

-- auto breakline
opt.wrap = true
opt.breakindentopt = "shift:0,min:20"

vim.g.autoformat = false -- globally
vim.b.autoformat = false -- buffer-local
