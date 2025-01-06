--          Mode  | Norm | Ins | Cmd | Vis | Sel | Opr | Term | Lang |
-- Command        +------+-----+-----+-----+-----+-----+------+------+
-- [nore]map      | yes  |  -  |  -  | yes | yes | yes |  -   |  -   |
-- n[nore]map     | yes  |  -  |  -  |  -  |  -  |  -  |  -   |  -   |
-- [nore]map!     |  -   | yes | yes |  -  |  -  |  -  |  -   |  -   |
-- i[nore]map     |  -   | yes |  -  |  -  |  -  |  -  |  -   |  -   |
-- c[nore]map     |  -   |  -  | yes |  -  |  -  |  -  |  -   |  -   |
-- v[nore]map     |  -   |  -  |  -  | yes | yes |  -  |  -   |  -   |
-- x[nore]map     |  -   |  -  |  -  | yes |  -  |  -  |  -   |  -   |
-- s[nore]map     |  -   |  -  |  -  |  -  | yes |  -  |  -   |  -   |
-- o[nore]map     |  -   |  -  |  -  |  -  |  -  | yes |  -   |  -   |
-- t[nore]map     |  -   |  -  |  -  |  -  |  -  |  -  | yes  |  -   |
-- l[nore]map     |  -   | yes | yes |  -  |  -  |  -  |  -   | yes  |

local map = LazyVim.safe_keymap_set

-- del
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
vim.keymap.del("n", "s")
vim.keymap.del("n", "S")

-- colemak
map({ "n", "v" }, "n", "j", { noremap = true, silent = true })
map({ "n", "v" }, "N", "J", { noremap = true, silent = true })
map({ "n", "v" }, "e", "k", { noremap = true, silent = true })
map({ "n", "v" }, "E", "K", { noremap = true, silent = true })
map({ "n", "v" }, "i", "l", { noremap = true, silent = true })
map({ "n", "v" }, "I", "L", { noremap = true, silent = true })
map({ "n", "v" }, "j", "e", { noremap = true, silent = true })
map({ "n", "v" }, "J", "E", { noremap = true, silent = true })
map({ "n", "v" }, "l", "i", { noremap = true, silent = true })
map({ "n", "v" }, "L", "I", { noremap = true, silent = true })
map({ "n", "v" }, "k", "n", { noremap = true, silent = true })
map({ "n", "v" }, "K", "N", { noremap = true, silent = true })
map({ "n", "v" }, ";", ":", { noremap = true, silent = true })
map({ "n", "v" }, "<A-n>", "5j", { noremap = true, silent = true })
map({ "n", "v" }, "<A-e>", "5k", { noremap = true, silent = true })
