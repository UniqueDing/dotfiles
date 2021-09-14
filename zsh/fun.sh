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
function fzfc(){
    content=`rg -n -t $* . | fzf`
    file=`echo $content | awk -F: '{printf $1}'`
    col=`echo $content | awk -F: '{printf $2}'`
    nvim $file +$col
}

