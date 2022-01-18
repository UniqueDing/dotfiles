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
