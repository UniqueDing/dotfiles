
# ---
# key: fzfl [path:optional]
# note: show file list useby fzf, default .
# code: 
# pic: 
# ---
function fzfl(){
    if [ $1 ];then
        INITIAL_QUERY=$1
    else
        INITIAL_QUERY='.'
    fi

    RG_PREFIX="rg --no-heading --color=always --smart-case --hidden --files"
    FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
      fzf --bind "change:reload:$RG_PREFIX '$INITIAL_QUERY' || true" \
          --preview '~/.config/zsh/fzfpreview.sh {}' \
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
          --preview ${FUNPATH}'/fzfpreview.sh {}' \
          --delimiter : --preview-window '+{2}-20' --ansi `
    if [ -n "$content" ]; then
        file=`echo $content | awk -F: '{printf $1}'`
        col=`echo $content | awk -F: '{printf $2}'`
        nvim $file +$col
    fi
}
