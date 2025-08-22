local bind = require("keymap.bind")
local map_cr = bind.map_cr
local map_cu = bind.map_cu
local map_cmd = bind.map_cmd

local core_map = {
	-- colemak
	["n|;"] = map_cmd(":"):with_noremap(),
	["n|n"] = map_cmd("j"):with_noremap(),
	["n|N"] = map_cmd("mzJ`z"):with_noremap():with_desc("editn: Join next line"),
	["n|e"] = map_cmd("k"):with_noremap(),
	["n|E"] = map_cmd("K"):with_noremap(),
	["n|i"] = map_cmd("l"):with_noremap(),
	["n|I"] = map_cmd("L"):with_noremap(),
	["n|j"] = map_cmd("e"):with_noremap(),
	["n|J"] = map_cmd("E"):with_noremap(),
	["n|l"] = map_cmd("i"):with_noremap(),
	["n|L"] = map_cmd("I"):with_noremap(),
	["n|k"] = map_cmd("nzzzv"):with_noremap():with_desc("editn: Next search result"),
	["n|K"] = map_cmd("Nzzzv"):with_noremap():with_desc("editn: Prev search result"),
	["v|;"] = map_cmd(":"):with_noremap(),
	["v|n"] = map_cmd("j"):with_noremap(),
	["v|N"] = map_cmd(":m '>+1<CR>gv=gv"):with_desc("editv: Move this line down"),
	["v|e"] = map_cmd("k"):with_noremap(),
	["v|E"] = map_cmd(":m '<-2<CR>gv=gv"):with_desc("editv: Move this line up"),
	["v|i"] = map_cmd("l"):with_noremap(),
	["v|I"] = map_cmd("L"):with_noremap(),
	["v|j"] = map_cmd("e"):with_noremap(),
	["v|J"] = map_cmd("E"):with_noremap(),
	["v|l"] = map_cmd("i"):with_noremap(),
	["v|L"] = map_cmd("I"):with_noremap(),
	["v|k"] = map_cmd("n"):with_noremap(),
	["v|K"] = map_cmd("N"):with_noremap(),
	["o|;"] = map_cmd(":"):with_noremap(),
	["o|n"] = map_cmd("j"):with_noremap(),
	["o|N"] = map_cmd("J"):with_noremap(),
	["o|e"] = map_cmd("k"):with_noremap(),
	["o|E"] = map_cmd("K"):with_noremap(),
	["o|i"] = map_cmd("l"):with_noremap(),
	["o|I"] = map_cmd("L"):with_noremap(),
	["o|j"] = map_cmd("e"):with_noremap(),
	["o|J"] = map_cmd("E"):with_noremap(),
	["o|l"] = map_cmd("i"):with_noremap(),
	["o|L"] = map_cmd("I"):with_noremap(),
	["o|k"] = map_cmd("n"):with_noremap(),
	["o|K"] = map_cmd("N"):with_noremap(),

	["n|<A-n>"] = map_cmd("5j"):with_noremap(),
	["v|<A-n>"] = map_cmd("5j"):with_noremap(),

	["n|<A-e>"] = map_cmd("5k"):with_noremap(),
	["v|<A-e>"] = map_cmd("5k"):with_noremap(),
	["n|<leader>h"] = map_cr("nohlsearch"):with_noremap():with_desc("no highlight search"),

	-- Suckless
	["n|<S-Tab>"] = map_cr("normal za"):with_noremap():with_silent():with_desc("editn: Toggle code fold"),
	["n|<C-s>"] = map_cu("write"):with_noremap():with_silent():with_desc("editn: Save file"),
	["n|<C-S-s>"] = map_cmd("execute 'silent! write !sudo tee % >/dev/null' <bar> edit!")
		:with_silent()
		:with_noremap()
		:with_desc("editn: Save file using sudo"),
	["n|Y"] = map_cmd("y$"):with_desc("editn: Yank text to EOL"),
	["n|D"] = map_cmd("d$"):with_desc("editn: Delete text to EOL"),
	["n|<leader>ve"] = map_cmd(":set nosplitbelow<cr>:split<cr>:set splitbelow<cr>")
		:with_silent()
		:with_desc("window: split up"),
	["n|<leader>vn"] = map_cmd(":set splitbelow<cr>:split<cr>"):with_silent():with_desc("windowI split down"),
	["n|<leader>vh"] = map_cmd(":set nosplitright<cr>:split<cr>:set splitright<cr>")
		:with_silent()
		:with_desc("window: split left"),
	["n|<leader>vi"] = map_cmd(":set splitright<cr>:vsplit<cr>"):with_silent():with_desc("window: split right"),
	["n|<leader>vk"] = map_cmd("<C-w>t<C-w>K"):with_silent():with_desc("window: place the two screens up and down"),
	["n|<leader>vs"] = map_cmd("<C-w>t<C-w>H"):with_silent():with_desc("window: place the two screens side by side"),
	["n|<leader>q"] = map_cmd("<C-w>j:q<cr>")
		:with_silent()
		:with_desc("window close the window below the current window"),
	["n|<A-S-n>"] = map_cr("resize -2"):with_silent():with_desc("window: Resize -2 horizontally"),
	["n|<A-S-e>"] = map_cr("resize +2"):with_silent():with_desc("window: Resize +2 horizontally"),
	["n|<A-S-h>"] = map_cr("vertical resize -5"):with_silent():with_desc("window: Resize -5 vertically"),
	["n|<A-S-i>"] = map_cr("vertical resize +5"):with_silent():with_desc("window: Resize +5 vertically"),
	["n|<leader>o"] = map_cr("setlocal spell! spelllang=en_us"):with_desc("editn: Toggle spell check"),
	-- Insert mode
	["i|<C-u>"] = map_cmd("<C-G>u<C-U>"):with_noremap():with_desc("editi: Delete previous block"),
	["i|<C-b>"] = map_cmd("<Left>"):with_noremap():with_desc("editi: Move cursor to left"),
	["i|<C-a>"] = map_cmd("<ESC>^i"):with_noremap():with_desc("editi: Move cursor to line start"),
	["i|<C-s>"] = map_cmd("<Esc>:w<CR>"):with_desc("editi: Save file"),
	["i|<C-q>"] = map_cmd("<Esc>:wq<CR>"):with_desc("editi: Save file and quit"),
	-- Command mode
	["c|<C-b>"] = map_cmd("<Left>"):with_noremap():with_desc("editc: Left"),
	["c|<C-f>"] = map_cmd("<Right>"):with_noremap():with_desc("editc: Right"),
	["c|<C-a>"] = map_cmd("<Home>"):with_noremap():with_desc("editc: Home"),
	["c|<C-e>"] = map_cmd("<End>"):with_noremap():with_desc("editc: End"),
	["c|<C-d>"] = map_cmd("<Del>"):with_noremap():with_desc("editc: Delete"),
	["c|<C-h>"] = map_cmd("<BS>"):with_noremap():with_desc("editc: Backspace"),
	["c|<C-t>"] = map_cmd([[<C-R>=expand("%:p:h") . "/" <CR>]])
		:with_noremap()
		:with_desc("editc: Complete path of current file"),
	-- Visual mode
	["v|<"] = map_cmd("<gv"):with_desc("editv: Decrease indent"),
	["v|>"] = map_cmd(">gv"):with_desc("editv: Increase indent"),

	["n|<leader>tt"] = map_cr("b #"):with_desc("buffer: toggle tab"),
	-- ["n|<Tab>q"] = map_cr("bdelete"):with_desc("close tab"),
}

bind.nvim_load_mapping(core_map)
