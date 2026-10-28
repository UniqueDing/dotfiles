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

-- del
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
vim.keymap.del("n", "s")
vim.keymap.del("n", "S")
vim.keymap.del({ "o", "v" }, "ii")
vim.keymap.del({ "o", "v" }, "ai")

-- colemak
vim.keymap.set({ "n", "v", "x", "s", "o" }, "n", "j", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "N", "J", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "e", "k", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "E", "K", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "l", "i", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "L", "I", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "i", "l", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "I", "L", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "j", "e", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "J", "E", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "k", "n", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "K", "N", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, ";", ":", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "<A-n>", "5j", { noremap = true, silent = true })
vim.keymap.set({ "n", "v", "x", "s", "o" }, "<A-e>", "5k", { noremap = true, silent = true })

-- Colemak window navigation in Normal mode; keep terminal-input Tab completion.
for _, key in ipairs({ "<C-j>", "<C-k>", "<C-l>" }) do
  pcall(vim.keymap.del, "n", key)
end
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true, desc = "Go to Left Window" })
vim.keymap.set("n", "<C-i>", "<C-w>l", { noremap = true, silent = true, desc = "Go to Right Window" })
vim.keymap.set("n", "<C-n>", "<C-w>j", { noremap = true, silent = true, desc = "Go to Lower Window" })
vim.keymap.set("n", "<C-e>", "<C-w>k", { noremap = true, silent = true, desc = "Go to Upper Window" })
