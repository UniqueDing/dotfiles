local global = require("core.global")

local function load_options()
	local global_local = {
		backupdir = global.cache_dir .. "backup/",
		directory = global.cache_dir .. "swap/",
		spellfile = global.cache_dir .. "spell/en.uft-8.add",
		viewdir = global.cache_dir .. "view/",

		-- popup transparent
		-- pumblend = 10,
		-- winblend = 10,

		autoindent = true,
		autoread = true,
		autowrite = true,
		backspace = "indent,eol,start",
		backup = false,
		backupskip = "/tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*,*/shm/*,/private/var/*,.vault.vim",
		breakat = [[\ \	;:,!?]],

		-- auto breakline
		wrap = true,
		breakindentopt = "shift:0,min:20", -- auto

		-- clipboard = "unnamedplus",
		cmdheight = 2, -- 0, 1, 2
		cmdwinheight = 5,
		complete = ".,w,b,k",
		completeopt = "menuone,noselect",
		concealcursor = "niv",
		conceallevel = 0,
		-- cursorcolumn = true,
		cursorline = true,
		diffopt = "filler,iwhite,internal,algorithm:patience",
		-- display = "lastline",
		encoding = "utf-8",
		equalalways = false,
		fileformats = "unix,mac,dos",
		foldenable = true,
		foldlevelstart = 99,
		formatoptions = "1jcroql",
		grepformat = "%f:%l:%c:%m",
		grepprg = "rg --hidden --vimgrep --smart-case --",
		helpheight = 12,
		hidden = true,
		history = 2000,
		ignorecase = true,
		inccommand = "nosplit",
		incsearch = true,
		infercase = true,
		jumpoptions = "stack",
		laststatus = 2,
		linebreak = true,
		list = true,
		listchars = "tab:»·,nbsp:+,trail:·,extends:→,precedes:←",
		magic = true,
		mouse = "",
		mousescroll = "ver:3,hor:6",
		number = true,
		relativenumber = true,
		signcolumn = "yes",
		previewheight = 12,
		pumheight = 15,
		redrawtime = 500,
		ruler = true,
		scrolloff = 3,
		sidescrolloff = 5,
		sessionoptions = "curdir,help,tabpages,winsize",
		shada = "!,'300,<50,@100,s10,h",
		shortmess = "aoOTIcF",
		showbreak = "↳  ",
		showcmd = false,
		showmode = false,
		showtabline = 2,
		smartcase = true,

		-- tab
		expandtab = true,
		smarttab = true,
		softtabstop = 4,
		tabstop = 4,
		shiftround = true,
		shiftwidth = 4,

		splitbelow = true,
		splitright = true,
		startofline = false,
		swapfile = false,
		switchbuf = "usetab,uselast",
		synmaxcol = 2500,
		termguicolors = true,
		timeout = true,
		-- You will feel delay when you input <Space> at lazygit interface if you set it a positive value like 300(ms).
		timeoutlen = 800,
		ttimeout = true,
		ttimeoutlen = 0,
		undodir = global.cache_dir .. "undo/",
		undofile = true,
		-- Please do NOT set `updatetime` to above 500, otherwise most plugins may not work correctly
		updatetime = 500,
		viewoptions = "folds,cursor,curdir,slash,unix",
		virtualedit = "block",
		visualbell = false,
		whichwrap = "<,>,[,],~",
		wildignore = ".git,.hg,.svn,*.pyc,*.o,*.out,*.jpg,*.jpeg,*.png,*.gif,*.zip,**/tmp/**,*.DS_Store,**/node_modules/**,**/bower_modules/**",
		wildignorecase = true,
		winminwidth = 10,
		winwidth = 30,
		wrapscan = true,
		writebackup = false,
	}

	for name, value in pairs(global_local) do
		vim.o[name] = value
	end
end

load_options()
