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
set tabstop=4
set shiftwidth=4
set scrolloff=4
set cmdheight=2
set hidden
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312

noremap <LEADER>h :nohlsearch<CR>
noremap <LEADER>o o<ESC>
noremap <LEADER>a a <ESC>
noremap <LEADER>l i <ESC>

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
noremap <LEADER><LEADER> <Esc>/<++><CR>:nohlsearch<CR>c4l


" split the screens to up (horizontal), down (horizontal), left (vertical), right (vertical)
noremap <LEADER>ve :set nosplitbelow<CR>:split<CR>:set splitbelow<CR>
noremap <LEADER>vn :set splitbelow<CR>:split<CR>
noremap <LEADER>vh :set nosplitright<CR>:vsplit<CR>:set splitright<CR>
noremap <LEADER>vi :set splitright<CR>:vsplit<CR>
" Place the two screens up and down
noremap <LEADER>vk <C-w>t<C-w>K
" Place the two screens side by side
noremap <LEADER>vv <C-w>t<C-w>H
" Press <SPACE> + q to close the window below the current window
noremap <LEADER>q <C-w>j:q<CR>

noremap <LEADER>ww <C-w>w
noremap <LEADER>we <C-w>k
noremap <LEADER>wn <C-w>j
noremap <LEADER>wh <C-w>h
noremap <LEADER>wi <C-w>l

if filereadable(expand('~/.vim/autoload/plug.vim'))
" plug
call plug#begin('~/.vim/plugged')
"color"
Plug 'arcticicestudio/nord-vim'
Plug 'nanotech/jellybeans.vim'
Plug 'altercation/vim-colors-solarized'
Plug 'morhetz/gruvbox'

Plug 'lambdalisue/suda.vim'

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Plug 'scrooloose/nerdtree'
Plug 'mhinz/vim-startify'
Plug 'tpope/vim-commentary'
" Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
" Plug 'octol/vim-cpp-enhanced-highlight'
" Plug 'rip-rip/clang_complete'

"markdown
Plug 'godlygeek/tabular'
" Plug 'plasticboy/vim-markdown'
" Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() } }
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
Plug 'RRethy/vim-illuminate'

Plug 'pechorin/any-jump.vim'

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
			\ 'coc-python',
			\ 'coc-docker',
			\ 'coc-cmake',
			\ 'coc-java',
			\ 'coc-html',
			\ 'coc-css',
			\ 'coc-lua',
			\ 'coc-json',
			\ 'coc-clangd',
			\ 'coc-translator'
			\ ]

"color
"colorscheme nord
"colorscheme jellybeans
colorscheme gruvbox
let g:gruvbox_bold = '1'

hi Normal ctermfg=252 ctermbg=none

" airline
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme="bubblegum"
let g:airline_powerline_fonts = 1

" nerdtree
" map <A-t> :NERDTreeToggle<CR>


" markdown
" let g:vim_markdown_folding_disabled = 1
" let g:vim_markdown_folding_style_pythonic = 1
" let g:vim_markdown_toml_frontmatter = 1
" noremap <LEADER>t :Toc<CR>

" noremap <LEADER>p <Plug>MarkdownPreviewToggle
nmap <LEADER>p <Plug>MarkdownPreviewToggle
" let g:mkdp_browser = '"Firefox" --args --new-window'

function! g:Open_browser(url)
	if has("mac")
		silent exec '!open -na "Google Chrome" --args --new-window ' . a:url
	else
		silent exec "!google-chrome-stable --new-window " . a:url
	endif
endfunction
let g:mkdp_browserfunc = 'g:Open_browser'

" indentLine
let g:indentLine_char_list = ['|', '¦', '┆', '┊']


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

nmap <silent> <C-c> <Plug>(coc-cursors-position)
nmap <silent> <C-d> <Plug>(coc-cursors-word)
xmap <silent> <C-d> <Plug>(coc-cursors-range)
" use normal command like `<leader>xi(`
" nmap <leader>x  <Plug>(coc-cursors-operator)
nnoremap <silent><nowait> <LEADER>dd :CocList diagnostics<cr>
nmap <silent> <LEADER>de <Plug>(coc-diagnostic-prev)
nmap <silent> <LEADER>dn <Plug>(coc-diagnostic-next)
nmap <Leader>dj :CocList --input= -I symbols<left><left><left><left><left><left><left><left><left><left><left>

" coc-explorer
:nmap <LEADER>e :CocCommand explorer<CR>

" coc-snippets

" coc-smartf
" " press <esc> to cancel.
nmap f <Plug>(coc-smartf-forward)
nmap F <Plug>(coc-smartf-backward)
nmap , <Plug>(coc-smartf-repeat)
nmap , <Plug>(coc-smartf-repeat-opposite)

augroup Smartf
	autocmd User SmartfEnter :hi Conceal ctermfg=220 guifg=#6638F0
	autocmd User SmartfLeave :hi Conceal ctermfg=239 guifg=#504945
augroup end

" coc-python
" map <LEADER>r :CocCommand python.execInTerminal<CR>
"
" coc-clangd
map <Leader>ms :CocCommand clangd.switchSourceHeader<CR>

" C Compiler:
autocmd FileType c nnoremap <LEADER>r :!gcc % && ./a.out <CR>

" C++ Compiler
autocmd FileType cpp nnoremap <LEADER>r :!g++ -pthread % && ./a.out <CR>

" Python Interpreter
autocmd FileType python nnoremap <LEADER>r :CocCommand python.execInTerminal <CR>

" Bash script
autocmd FileType sh nnoremap <LEADER>r :!sh % <CR>

"fzf
" nnoremap <c-p> :Leaderf file<CR>
noremap <silent> <Leader>fp :Files<CR>
noremap <silent> <Leader>ff :Rg<CR>
noremap <silent> <Leader>fh :History<CR>
"noremap <C-t> :BTags<CR>
noremap <silent> <Leader>fl :Lines<CR>
noremap <silent> <Leader>fw :Buffers<CR>

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

noremap <Leader>fd :BD<CR>

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.8 } }

"coc-translator
" popup
nmap <Leader>tt <Plug>(coc-translator-p)
vmap <Leader>tt <Plug>(coc-translator-pv)
" echo
nmap <Leader>te <Plug>(coc-translator-e)
vmap <Leader>te <Plug>(coc-translator-ev)
" replace
nmap <Leader>tr <Plug>(coc-translator-r)
vmap <Leader>tr <Plug>(coc-translator-rv)

" vim-easy-align
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" wildfire
" This selects the next closest text object.
" map <Leader>k <Plug>(wildfire-fuel)

" This selects the previous closest text object.
" vmap <C-k> <Plug>(wildfire-water)

" vista
function! NearestMethodOrFunction() abort
	return get(b:, 'vista_nearest_method_or_function', '')
endfunction

set statusline+=%{NearestMethodOrFunction()}

" By default vista.vim never run if you don't call it explicitly.
"
" If you want to show the nearest function in your statusline automatically,
" you can add the following line to your vimrc
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()
let g:lightline = {
			\ 'colorscheme': 'wombat',
			\ 'active': {
			\   'left': [ [ 'mode', 'paste' ],
			\             [ 'readonly', 'filename', 'modified', 'method' ] ]
			\ },
			\ 'component_function': {
			\   'method': 'NearestMethodOrFunction'
			\ },
			\ }
let g:vista_icon_indent = ["╰─▸ ", "├─▸ "]
let g:vista_default_executive = 'coc'
let g:vista_fzf_preview = ['right:50%']
let g:vista#renderer#enable_icon = 1
let g:vista#renderer#icons = {
			\   "function": "\uf794",
			\   "variable": "\uf71b",
			\  }
nmap <Leader>v :Vista!!<cr>

" suda
cnoreabbrev sudowrite w suda://%
cnoreabbrev sw w suda://%

" far
noremap <Leader>f :F  **/*<left><left><left><left><left>
let g:far#mapping = {
			\ "replace_undo" : ["l"],
			\ }

" hexokinase
let g:Hexokinase_highlighters = ['sign_column']

" rainbow
let g:rainbow_active = 1

" vim-illuminate
let g:Illuminate_delay = 500
hi illuminatedWord cterm=undercurl gui=undercurl

" autoformat
noremap <Leader>mf :Autoformat<CR>

" undotree
noremap <Leader>u :UndotreeToggle<CR>
function g:Undotree_CustomMap()
	nmap <buffer> n <plug>UndotreeNextState
	nmap <buffer> e <plug>UndotreePreviousState
	nmap <buffer> N 5<plug>UndotreeNextState
	nmap <buffer> E 5<plug>UndotreePreviousState
endfunc

" anyjump
" Normal mode: Jump to definition under cursore
nnoremap <leader>j :AnyJump<CR>

" Visual mode: jump to selected text in visual mode
xnoremap <leader>j :AnyJumpVisual<CR>

" Normal mode: open previous opened file (after jump)
nnoremap <leader>jb :AnyJumpBack<CR>

" Normal mode: open last closed search window again
nnoremap <leader>jl :AnyJumpLastResults<CR>

endif
