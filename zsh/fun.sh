#fun

function mkcd(){
	mkdir $1
	cd $1
}

# proxy
function Pon(){
	export https_proxy=http://127.0.0.1:20171 http_proxy=http://127.0.0.1:20171 all_proxy=socks5://127.0.0.1:20170
}

function Pdown(){
	unset http_proxy
	unset https_proxy
	unset all_proxy
}

# update
function update(){
    yes | pSyyu
    yes | aU
    yes | bU
    yes | sU
    zi update
}

# ---
# key: fzfl
# note: show file list useby fzf
# code: 
# pic: 
# ---
function fzfl(){
    INITIAL_QUERY=$1
    RG_PREFIX="rg --no-heading --color=always --smart-case --hidden --files"
    FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
      fzf --bind "change:reload:$RG_PREFIX || true" \
          --preview '~/.config/zsh/preview.sh {}' \
          --ansi
}

# ---
# key: fzflh
# note: show home file list useby fzf
# code: fzfl $HOME
# pic: 
# ---
function fzflh(){
    fzfl $HOME
}

# ---
# key: fzflr
# note: show / file list useby fzf
# code: fzfl /
# pic: 
# ---
function fzflr(){
    fzfl /
}

# ---
# key: fzfp
# note: show ps -ef list useby fzf
# code: 
# pic: 
# ---
function fzfp(){
    FZF_DEFAULT_COMMAND='ps -ef'
    FZF_DEFAULT_COMMAND='ps -ef' \
        fzf --bind "ctrl-r:reload($FZF_DEFAULT_COMMAND)" \
          --header 'Press CTRL-R to reload' --header-lines=1 \
          --height=50% --layout=reverse
}

# ---
# key: fzfc [filetype:optional]
# note: show current directory file lines use by fzf and jump to nvim
# code: 
# pic: 
# ---
function fzfc(){
    INITIAL_QUERY='.'
    if [ $* ]; then
        RG_PREFIX="rg --line-number --no-heading --color=always --smart-case -t $* --hidden"
    else
        RG_PREFIX="rg --line-number --no-heading --color=always --smart-case --hidden"
    fi
    content=`FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
      fzf --bind "change:reload:$RG_PREFIX {q} || true" \
          --preview '~/.config/zsh/preview.sh {}' \
          --delimiter : --preview-window '+{2}-20' --ansi `
    if [ -n "$content" ]; then
        file=`echo $content | awk -F: '{printf $1}'`
        col=`echo $content | awk -F: '{printf $2}'`
        nvim $file +$col
    fi
}

