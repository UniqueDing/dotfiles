#fun
FUNPATH=$(dirname "$0")
source $FUNPATH/packagemanager.zsh
source $FUNPATH/myfzf.zsh
source $FUNPATH/fzf-key-bindings.zsh

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

function adbS() {
    while :
    do
        adb shell "echo 'lxc-attach -P /opt/compatible/android/lxc -n androidcompat' > /bin/lxa && chmod +x /bin/lxa" && adb shell
        if [[ $? -eq 0 ]]; then
            break
        fi
        sleep 1
    done
}

# $1 ssh connect
function copyvim() {
    ssh $1 << EOF
        mv ~/.vimrc ~/.vimrc_bak
EOF
    scp ~/.vimrc $1:~/.vimrc
}
