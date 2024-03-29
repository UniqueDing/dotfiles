let mapleader=" "
" colemak
noremap n j
noremap N J
noremap e k
noremap E K
noremap i l
noremap I L
noremap l i
noremap L I
noremap k nzz
noremap K Nzz
noremap j e
noremap J E
noremap ; :

" imap jj <ESC>
set nu
set relativenumber
set showcmd
set wildmenu
set hlsearch
set incsearch
set expandtab
set smarttab
set tabstop=4
set shiftwidth=4
set scrolloff=4
set cmdheight=2
set hidden
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312
set fileformats=unix

autocmd BufNewFile,BufRead crontab.* set nobackup | set nowritebackup

set ignorecase
set smartcase

nnoremap <leader>ss :%s//gcI<left><left><left><left>
nnoremap <leader>si :%s//gci<left><left><left><left>
vnoremap <leader>ss :s//gcI<left><left><left><left>
vnoremap <leader>si :s//gci<left><left><left><left>

set list
set listchars=tab:>-,trail:-

" delete
noremap <leader>xh :%s/^\s*//g<cr>
noremap <leader>xi :%s/\s*$//g<cr>
noremap <leader>xn :g/^$/d<cr>



noremap <leader>h :nohlsearch<CR>
noremap <leader>o o<ESC>
noremap <leader>l i <ESC>

noremap <tab>h :<C-u>bp<cr>
noremap <tab>i :<C-u>bn<cr>

" set foldmethod=syntax
" set foldlevel=2
" set foldnestmax=3
noremap <tab>t za
noremap <tab>k zR
noremap <tab>m zM

if has('nvim')
	noremap <A-n> 5j
	noremap <A-e> 5k
	noremap <A-h> 0
	noremap <A-i> $

	" Resize splits with arrow keys
	noremap <A-up> :res -5<CR>
	noremap <A-down> :res +5<CR>
	noremap <A-left> :vertical resize-5<CR>
	noremap <A-right> :vertical resize+5<CR>
else
	noremap n 5j
	noremap e 5k
	noremap h 0
	noremap i $

	" Resize splits with arrow keys
	" noremap <Up> :res -5<CR>
	" noremap <Down> :res +5<CR>
	" noremap <Left> :vertical resize-5<CR>
	" noremap <Right> :vertical resize+5<CR>
endif


" Press twice to jump to the next '<++>' and edit it
noremap <leader><leader> <Esc>/<++><CR>:nohlsearch<CR>c4l

" copy
noremap <leader>yy "+y
noremap <leader>yp "+p


" split the screens to up (horizontal), down (horizontal), left (vertical), right (vertical)
noremap <leader>ve :set nosplitbelow<CR>:split<CR>:set splitbelow<CR>
noremap <leader>vn :set splitbelow<CR>:split<CR>
noremap <leader>vh :set nosplitright<CR>:vsplit<CR>:set splitright<CR>
noremap <leader>vi :set splitright<CR>:vsplit<CR>
" Place the two screens up and down
noremap <leader>vk <C-w>t<C-w>K
" Place the two screens side by side
noremap <leader>vs <C-w>t<C-w>H
" Press <SPACE> + q to close the window below the current window
noremap <leader>q <C-w>j:q<CR>

noremap <leader>ww <C-w>w
noremap <leader>we <C-w>k
noremap <leader>wn <C-w>j
noremap <leader>wh <C-w>h
noremap <leader>wi <C-w>l

if filereadable(expand('~/.vim/autoload/plug.vim'))
set rtp +=~/.fzf
set rtp +=~/.vim
" plug
call plug#begin('~/.vim/plugged')
"color"
Plug 'arcticicestudio/nord-vim'
Plug 'nanotech/jellybeans.vim'
Plug 'altercation/vim-colors-solarized'
Plug 'morhetz/gruvbox'
Plug 'dracula/vim'
Plug 'connorholyday/vim-snazzy'
Plug 'joshdick/onedark.vim'
Plug 'vim-scripts/peaksea'

Plug 'lambdalisue/suda.vim'

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'
" Plug 'itchyny/lightline.vim'

Plug 'vim-scripts/DoxygenToolkit.vim'
" Plug 'scrooloose/nerdtree'
Plug 'mhinz/vim-startify'
Plug 'tpope/vim-commentary'
Plug 'jackguo380/vim-lsp-cxx-highlight'
" Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
" Plug 'octol/vim-cpp-enhanced-highlight'
" Plug 'rip-rip/clang_complete'

"markdown
Plug 'godlygeek/tabular'
" Plug 'plasticboy/vim-markdown'
" Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug'] }
" Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install'  }
Plug 'cespare/vim-toml'

Plug 'neoclide/coc.nvim' , {'branch': 'release'}
Plug 'tpope/vim-surround'
Plug 'gcmt/wildfire.vim'
Plug 'Yggdroot/indentLine'
Plug 'scrooloose/syntastic'
" Plug 'vim-scripts/taglist.vim'
Plug 'junegunn/fzf.vim'
Plug 'liuchengxu/vista.vim'
Plug 'puremourning/vimspector'
Plug 'junegunn/vim-easy-align'

Plug 'puremourning/vimspector'
Plug 'brooth/far.vim', { 'on': ['F', 'Far', 'Fardo'] }

Plug 'Chiel92/vim-autoformat'

Plug 'mbbill/undotree'

Plug 'luochen1990/rainbow'
" Plug 'mg979/vim-xtabline'

Plug 'RRethy/vim-hexokinase', { 'do': 'make hexokinase' }
" Plug 'RRethy/vim-illuminate'

Plug 'pechorin/any-jump.vim'

Plug 'fruit-in/brainfuck-vim'

Plug 'mklabs/vim-cowsay'

Plug 'wakatime/vim-wakatime'

" fcitx
Plug 'lilydjwg/fcitx.vim'

Plug 'hsanson/vim-android'

Plug 'cdelledonne/vim-cmake'

call plug#end()

"coc-extensions
let g:coc_global_extensions = [
			\ 'coc-tsserver',
			\ 'coc-vimlsp',
			\ 'coc-snippets',
			\ 'coc-smartf',
			\ 'coc-pairs',
			\ 'coc-marketplace',
			\ 'coc-lists',
			\ 'coc-git',
			\ 'coc-explorer',
			\ 'coc-yaml',
			\ 'coc-pyright',
			\ 'coc-docker',
			\ 'coc-cmake',
			\ 'coc-java',
			\ 'coc-html',
			\ 'coc-css',
			\ 'coc-lua',
			\ 'coc-json',
			\ 'coc-clangd',
			\ 'coc-translator',
			\ 'coc-go',
			\ 'coc-rust-analyzer',
            \ 'coc-leetcode',
            \ 'coc-vetur'
			\ ]

"color
if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif

autocmd vimenter * hi Normal guibg=NONE ctermbg=NONE  " transparent bg
" colorscheme snazzy
" colorscheme onedark
colorscheme dracula
" colorscheme peaksea
" colorscheme nord
" colorscheme jellybeans
" colorscheme gruvbox
" let g:gruvbox_bold = '1'

" hi Normal ctermfg=252 ctermbg=none
set termguicolors

" highlight RedundantSpaces ctermbg=red guibg=red
" match RedundantSpaces /\s\+$/
" " tab | \+\ze\t\|\t/

" lightline
let g:lightline = {
			\ 'colorscheme': 'wombat',
			\ 'active': {
			\   'left': [ 
            \     [ 'mode', 'paste' ],
			\     [ 'readonly', 'filename', 'modified', 'method' ]
            \   ],
            \   'right':[
            \     [ 'filetype', 'fileencoding', 'lineinfo', 'percent' ],
            \     [ 'blame' ]
            \   ],
			\ },
			\ 'component_function': {
			\   'method': 'NearestMethodOrFunction',
            \   'blame': 'LightlineGitBlame',
			\ },
			\ }

" hexokinase
let g:Hexokinase_highlighters = [
\   'virtual',
\   'sign_column',
\   'background',
\   'backgroundfull',
\   'foreground',
\   'foregroundfull'
\ ]

" tab
nmap <leader>a= :Tabularize /=<CR>
vmap <leader>a= :Tabularize /=<CR>
nmap <leader>a; :Tabularize /:\zs<CR>
vmap <leader>a; :Tabularize /:\zs<CR>

" nerdtree
" map <A-t> :NERDTreeToggle<CR>


" markdown
" let g:vim_markdown_folding_disabled = 1
" let g:vim_markdown_folding_style_pythonic = 1
" let g:vim_markdown_toml_frontmatter = 1
" noremap <LEADER>t :Toc<CR>

" noremap <LEADER>p <Plug>MarkdownPreviewToggle
au BufNewFile,BufFilePre,BufRead *.md set filetype=markdown
autocmd FileType markdown nmap <leader>r <Plug>MarkdownPreviewToggle
" let g:mkdp_browser = '"Firefox" --args --new-window'
let g:mkdp_browser = 'firefox'

" function! g:Open_browser(url)
" 	if has("mac")
" 		silent exec '!open -na "Google Chrome" --args --new-window ' . a:url
" 	else
" 		silent exec "!chromium --new-window " . a:url
" 		" silent exec "!google-chrome-stable --new-window " . a:url
" 	endif
" endfunction
" let g:mkdp_browserfunc = 'g:Open_browser'

" indentLine
let g:indentLine_char_list = ['|', '¦', '┆', '┊']

" DoxygenToolKit
let g:doxyge_enhanced_color=1
" let g:DoxygenToolkit_briefTag_post = " <++>"
let g:DoxygenToolkit_paramTag_post = " <++>"
let g:DoxygenToolkit_returnTag = "@return <++>"
noremap <tab>dd :Dox<cr>
noremap <tab>da :DoxAuthor<cr>
noremap <tab>db :DoxBlock<cr>

" coc

" use <tab> for trigger completion and navigate to the next complete item
function! s:check_back_space() abort
	let col = col('.') - 1
	return !col || getline('.')[col - 1]  =~ '\s'
endfunction

inoremap <expr> <S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"
inoremap <silent><expr> <c-space> coc#refresh()

" inoremap <silent><expr> <CR> pumvisible() ? coc#_select_confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
inoremap <silent><expr> <TAB>
			\	pumvisible() ? "\<C-n>"  :
			\ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
			\ <SID>check_back_space() ? "\<TAB>" :
			\ coc#refresh()

function! s:check_back_space() abort
	let col = col('.') - 1
	return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" " Formatting selected code.
" xmap <leader>f  <Plug>(coc-format-selected)
" nmap <leader>f  <Plug>(coc-format-selected)

let g:coc_snippet_next = '<tab>'

nmap <silent> <A-c> <Plug>(coc-cursors-position)
nmap <silent> <A-d> <Plug>(coc-cursors-word)
xmap <silent> <A-d> <Plug>(coc-cursors-range)
" use normal command like `<leader>xi(`
" nmap <leader>x  <Plug>(coc-cursors-operator)
" nnoremap <silent><nowait> <leader>dl :CocList diagnostics<cr>
" nmap <silent> <leader>de <Plug>(coc-diagnostic-prev)
" nmap <silent> <leader>dn <Plug>(coc-diagnostic-next)
" nmap <silent> <leader>dd <Plug>(coc-definition)
" nmap <silent> <leader>dc <Plug>(coc-declaration)
" nmap <silent> <leader>dt <Plug>(coc-type-definition)
" nmap <silent> <leader>df <Plug>(coc-references)
" nmap <silent> <leader>du <Plug>(coc-references-used)
" nmap <silent> <leader>dr <Plug>(coc-rename)

" nmap <leader>dj :CocList --input= -I symbols<left><left><left><left><left><left><left><left><left><left><left>
"
" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <tab>r <Plug>(coc-rename)
nmap <tab>u <Plug>(coc-refactor)

" Apply AutoFix to problem on the current line.
nmap <silent><nowait> <tab>f  <Plug>(coc-fix-current)

" Mappings for CoCList
" Show all diagnostics.
nnoremap <silent><nowait> <tab>a  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent><nowait> <tab>x  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent><nowait> <tab>c  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent><nowait> <tab>o  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent><nowait> <tab>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent><nowait> <tab>ln  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent><nowait> <tab>le  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent><nowait> <tab>p  :<C-u>CocListResume<CR>


" coc-explorer
nmap <leader>e :CocCommand explorer<CR>

" coc-snippets

" coc-smartf
" " press <esc> to cancel.
" nmap f <Plug>(coc-smartf-forward)
" nmap F <Plug>(coc-smartf-backward)
" nmap , <Plug>(coc-smartf-repeat)
" nmap , <Plug>(coc-smartf-repeat-opposite)

" augroup Smartf
" 	autocmd User SmartfEnter :hi Conceal ctermfg=220 guifg=#6638F0
" 	autocmd User SmartfLeave :hi Conceal ctermfg=239 guifg=#504945
" augroup end

" coc-python
" map <LEADER>r :CocCommand python.execInTerminal<CR>
"
" coc-clangd
autocmd FileType c,cpp map <leader>ms :CocCommand clangd.switchSourceHeader<CR>

" coc-go
" Add missing imports on save
autocmd BufWritePre *.go :silent call CocAction('runCommand', 'editor.action.organizeImport')
autocmd FileType go nmap gtj :CocCommand go.tags.add json<cr>
autocmd FileType go nmap gty :CocCommand go.tags.add yaml<cr>
autocmd FileType go nmap gtx :CocCommand go.tags.clear<cr>


" C Compiler:
autocmd FileType c nnoremap <leader>r :!gcc % && ./a.out <CR>
" C++ Compiler
autocmd FileType cpp nnoremap <leader>r :!g++ -std=c++2a -pthread % && ./a.out <CR>
" Go Interpreter
autocmd FileType go nnoremap <leader>r :!go run % <CR>
" Python Interpreter
autocmd FileType python nnoremap <leader>r :!python3 % <CR>
" Racket Interpreter
au BufNewFile,BufFilePre,BufRead *.rkt set filetype=racket
autocmd FileType racket nnoremap <leader>r :!racket % <CR>
" Rust Interpreter
autocmd FileType rust nnoremap <leader>r :!rustc -o a.out % && ./a.out <CR>
" Java Interpreter
autocmd FileType java nnoremap <leader>r :!javac % && java % r <CR>
" Bash script
autocmd FileType sh nnoremap <leader>r :!bash % <CR>

"fzf
" nnoremap <c-p> :Leaderf file<CR>
noremap <silent> <leader>fp :Files<CR>
noremap <silent> <leader>ff :Rg<CR>
noremap <silent> <leader>fh :History<CR>
"noremap <C-t> :BTags<CR>
noremap <silent> <leader>fl :Lines<CR>
noremap <silent> <leader>fw :Buffers<CR>

let g:fzf_preview_window = 'right:60%'
let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'

function! s:list_buffers()
	redir => list
	silent ls
	redir END
	return split(list, "\n")
endfunction

function! s:delete_buffers(lines)
	execute 'bwipeout' join(map(a:lines, {_, line -> split(line)[0]}))
endfunction

command! BD call fzf#run(fzf#wrap({
			\ 'source': s:list_buffers(),
			\ 'sink*': { lines -> s:delete_buffers(lines) },
			\ 'options': '--multi --reverse --bind ctrl-a:select-all+accept'
			\ }))

noremap <leader>fd :BD<CR>

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.8 } }

"coc-translator
" popup
nmap <leader>tt <Plug>(coc-translator-p)
vmap <leader>tt <Plug>(coc-translator-pv)
" echo
nmap <leader>te <Plug>(coc-translator-e)
vmap <leader>te <Plug>(coc-translator-ev)
" replace
nmap <leader>tr <Plug>(coc-translator-r)
vmap <leader>tr <Plug>(coc-translator-rv)

" vim-easy-align
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" coc-git

" wildfire
" This selects the next closest text object.
" map <Leader>k <Plug>(wildfire-fuel)

" This selects the previous closest text object.
" vmap <C-k> <Plug>(wildfire-water)

" vista

let g:vista_icon_indent = ["╰─▸ ", "├─▸ "]
let g:vista_default_executive = 'coc'
let g:vista_fzf_preview = ['right:50%']
let g:vista#renderer#enable_icon = 1
" let g:vista#renderer#icons = {
" 			\   "function": "\uf794",
" 			\   "variable": "\uf71b",
" 			\  }
nmap <leader>vv :Vista!!<cr>

" suda
cnoreabbrev sudowrite w suda://%
cnoreabbrev sw w suda://%

" far
noremap <leader>f :F  **/*<left><left><left><left><left>
let g:far#mapping = {
			\ "replace_undo" : ["l"],
			\ }

" hexokinase
let g:Hexokinase_highlighters = ['sign_column']

" rainbow
let g:rainbow_active = 1

" vim-illuminate
" let g:Illuminate_delay = 500
" hi illuminatedWord cterm=undercurl gui=undercurl

" autoformat
" ---
" key: L-mf
" note: Anto Format
" code: :Autofomat<cr>
" pic: 
" ---
noremap <leader>mf :Autoformat<CR>

" undotree
" noremap <leader>u :UndotreeToggle<CR>
" function g:Undotree_CustomMap()
" 	nmap <buffer> n <plug>UndotreeNextState
" 	nmap <buffer> e <plug>UndotreePreviousState
" 	nmap <buffer> N 5<plug>UndotreeNextState
" 	nmap <buffer> E 5<plug>UndotreePreviousState
" endfunc

" anyjump
" ---
" key: L-jj
" note: AnyJump
" code: :AnyJump
" pic: 
" ---
" Normal mode: Jump to definition under cursore
nnoremap <leader>jj :AnyJump<CR>

" ---
" key: L-jj
" note: AnyJumpVisual
" code: :AnyJumpVisual
" pic: 
" ---
" Visual mode: jump to selected text in visual mode
xnoremap <leader>jj :AnyJumpVisual<CR>

" ---
" key: L-jb
" note: AnyJumpBack
" code: :AnyJumpBack
" pic: 
" ---
" Normal mode: open previous opened file (after jump)
nnoremap <leader>jb :AnyJumpBack<CR>

" ---
" key: L-jl
" note: AnyJumpLastResults
" code: :AnyJumpLastResults
" pic: 
" ---
" Normal mode: open last closed search window again
nnoremap <leader>jl :AnyJumpLastResults<CR>

let g:any_jump_list_numbers = 1

" vim-android
let g:android_sdk_path = '$HOME/Android/Sdk'
let g:gradle_path = '/opt/gradle-7.2'

" vim-cmake
let g:cmake_default_config = 'build'
nnoremap <leader>cg :CMakeGenerate
nnoremap <leader>cc :CMakeBuild -j16<CR>
nnoremap <leader>cb :CMakeBuild -j16
nnoremap <leader>cl :CMakeClean<CR>
nnoremap <leader>ci :CMakeInstall<CR>
nnoremap <leader>co :CMakeOpen<CR>
nnoremap <leader>cq :CMakeClose<CR>


" airline
set noshowmode
let g:airline#extensions#tabline#enabled = 1
" let g:airline_theme="bubblegum"
let g:airline_theme="tomorrow"
" let g:airline_powerline_fonts = 1
"



function! s:update_git_status()
  let g:airline_section_b = "%{get(g:,'coc_git_status','')}"
endfunction

let g:airline_section_b = "%{get(g:,'coc_git_status','')}"

autocmd User CocGitStatusChange call s:update_git_status()


" By default vista.vim never run if you don't call it explicitly.
"
" If you want to show the nearest function in your statusline automatically,
" you can add the following line to your vimrc
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" powerline symbols
let g:airline_symbols.linenr = ' '
let g:airline_symbols.maxlinenr = ''


endif
