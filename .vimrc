call plug#begin('~/.vim/plugged')
    Plug 'arcticicestudio/nord-vim'
    Plug 'nanotech/jellybeans.vim'
    Plug 'vim-airline/vim-airline'
    Plug 'scrooloose/nerdtree'
    Plug 'mhinz/vim-startify'
    Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
    Plug 'octol/vim-cpp-enhanced-highlight'
    Plug 'rip-rip/clang_complete'
    Plug 'godlygeek/tabular'
    Plug 'plasticboy/vim-markdown'
    Plug 'neoclide/coc.nvim' , {'branch': 'release'}
    Plug 'tpope/vim-surround'
    Plug 'Yggdroot/indentLine'
    Plug 'scrooloose/syntastic'

call plug#end()
"colemak
noremap n j
noremap N J
noremap e k
noremap E K
noremap i l
noremap I L
noremap l i
noremap L I
noremap k n
noremap K N
noremap j e
noremap J E

imap jj <ESC>
"color
"colorscheme nord
"colorscheme jellybeans

let mapleader=";"
" nerdtree
if has("nvim")
map <A-n> :NERDTreeToggle<CR>
else
map n :NERDTreeToggle<CR>
endif

" python-mode
" let g:pymode_python = 'python3'
" let g:pymode_rope_completion = 1
" let g:pymode_rope_complete_on_dot = 1
" let g:pymode_rope_completion_bind = '<C-Tab>'




set nu
set ts=4
set tw=4
set softtabstop=4
set expandtab
set autoindent
set ruler

