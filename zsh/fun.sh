#fun

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

# fzf
function fzfp(){
    FZF_DEFAULT_COMMAND='ps -ef' \
      fzf --bind 'ctrl-r:reload($FZF_DEFAULT_COMMAND)' \
          --header 'Press CTRL-R to reload' --header-lines=1 \
          --height=50% --layout=reverse
}

function fzfc(){
    if [ $* ]; then
        INITIAL_QUERY=""
        RG_PREFIX="rg --line-number --no-heading --color=always --smart-case -t $* "
        content=`FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
          fzf --bind "change:reload:$RG_PREFIX {q} || true" \
              --preview '~/.config/zsh/preview.sh {}' \
              --preview-window '+{3}-/2' \
              --tabstop 8 \
              --ansi --disabled --query "$INITIAL_QUERY"`
        if [ $content ]; then
            file=`echo $content | awk -F: '{printf $1}'`
            col=`echo $content | awk -F: '{printf $2}'`
            nvim $file +$col
        fi
    else;
        INITIAL_QUERY=""
        RG_PREFIX="rg --line-number --no-heading --color=always --smart-case "
        content=`FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
          fzf --bind "change:reload:$RG_PREFIX {q} || true" \
              --preview '~/.config/zsh/preview.sh {}' \
              --ansi --disabled --query "$INITIAL_QUERY"`
        if [ $content ]; then
            file=`echo $content | awk -F: '{printf $1}'`
            col=`echo $content | awk -F: '{printf $2}'`
            nvim $file +$col
        fi
    fi
}

