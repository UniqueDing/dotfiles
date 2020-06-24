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

imap jj <ESC>
set nu
set relativenumber
set showcmd
set wildmenu
set hlsearch
set incsearch
set tabstop=4
set shiftwidth=4
set scrolloff=4
noremap <LEADER>h :nohlsearch<CR>
noremap <LEADER>o o<ESC>
noremap <LEADER>a a <ESC>
noremap <LEADER>l i <ESC>

noremap <A-n> 5j
noremap <A-e> 5k
noremap <A-h> 0
noremap <A-i> $

" Press twice to jump to the next '<++>' and edit it
noremap <LEADER><LEADER> <Esc>/<++><CR>:nohlsearch<CR>c4l

" plug
call plug#begin('~/.vim/plugged')
    Plug 'arcticicestudio/nord-vim'
    Plug 'nanotech/jellybeans.vim'
    Plug 'vim-airline/vim-airline'
    Plug 'scrooloose/nerdtree'
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
    Plug 'Yggdroot/indentLine'
    Plug 'scrooloose/syntastic'
    Plug 'vim-scripts/taglist.vim'

    "lua
    " Plug 'xolox/vim-misc'
    " Plug 'xolox/vim-lua-inspect'
    " Plug 'xolox/vim-lua-ftplugin'
call plug#end()

"color
"colorscheme nord
"colorscheme jellybeans

" nerdtree
map <A-t> :NERDTreeToggle<CR>


" python-mode
" let g:pymode_python = 'python3'
" let g:pymode_rope_completion = 1
" let g:pymode_rope_complete_on_dot = 1
" let g:pymode_rope_completion_bind = '<C-Tab>'


" markdown
" let g:vim_markdown_folding_disabled = 1
" let g:vim_markdown_folding_style_pythonic = 1
" let g:vim_markdown_toml_frontmatter = 1
" noremap <LEADER>t :Toc<CR>

noremap <LEADER>p :MarkdownPreview<CR>
" let g:mkdp_browser = '"Firefox" --args --new-window'

function! g:Open_browser(url)
    silent exec "!google-chrome-stable --new-window " . a:url
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

inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent><expr> <TAB>
      \ pumvisible() ? coc#_select_confirm() :
      \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

let g:coc_snippet_next = '<tab>'

nmap <silent> <C-c> <Plug>(coc-cursors-position)
nmap <silent> <C-d> <Plug>(coc-cursors-word)
xmap <silent> <C-d> <Plug>(coc-cursors-range)
" use normal command like `<leader>xi(`
nmap <leader>x  <Plug>(coc-cursors-operator)

" coc-explorer
:nmap <LEADER>e :CocCommand explorer<CR>

" coc-snippets

" coc-smartf
" " press <esc> to cancel.
" nmap f <Plug>(coc-smartf-forward)
" nmap F <Plug>(coc-smartf-backward)
" nmap , <Plug>(coc-smartf-repeat)
" nmap , <Plug>(coc-smartf-repeat-opposite)

augroup Smartf
  autocmd User SmartfEnter :hi Conceal ctermfg=220 guifg=#6638F0
  autocmd User SmartfLeave :hi Conceal ctermfg=239 guifg=#504945
augroup end


"coc-pairs

inoremap <silent><expr> <cr> "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"



