#fun
FUNPATH=$(dirname "$0")
source $FUNPATH/*.zsh

function mkcd(){
	mkdir $1
	cd $1
}

# function adbS() {
#     while :
#     do
#         adb shell "echo 'lxc-attach -P /opt/compatible/android/lxc -n androidcompat' > /bin/lxa && chmod +x /bin/lxa" && adb shell
#         if [[ $? -eq 0 ]]; then
#             break
#         fi
#         sleep 1
#     done
# }
#
# # $1 ssh connect
# function copyvim() {
#     ssh $1 << EOF
#         mv ~/.vimrc ~/.vimrc_bak
# EOF
#     scp ~/.vimrc $1:~/.vimrc
# }
