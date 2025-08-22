local opt = vim.opt

-- tab
opt.expandtab = true
opt.smarttab = true
opt.softtabstop = 2
opt.tabstop = 2
opt.shiftround = true
opt.shiftwidth = 2

-- auto breakline
opt.wrap = true
opt.breakindentopt = "shift:0,min:20"

vim.g.autoformat = false -- globally
vim.b.autoformat = false -- buffer-local

