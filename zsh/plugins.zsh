### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

local ZI=(zinit ice lucid wait)
local ZIG=(${ZI} from='gh-r')
local ZIDP=(${ZI} depth='1' as'program')
local ZIGP=(${ZIG} as'program')
local ZIGC=(${ZIG} as'command')
local ZL=(zinit light)

zinit light romkatv/powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.config/zsh/fun/p10k.zsh ]] || source ~/.config/zsh/fun/p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet


zinit wait lucid for \
	atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay" \
	zdharma-continuum/fast-syntax-highlighting \
	blockf \
	zsh-users/zsh-completions \
	atload"!_zsh_autosuggest_start" \
	zsh-users/zsh-autosuggestions


zinit wait lucid light-mode for \
	wfxr/forgit \
	hlissner/zsh-autopair \
    marzocchi/zsh-notify \
    Aloxaf/fzf-tab \
    laggardkernel/zsh-thefuck

zinit atinit'Z_A_USECOMP=1' light-mode for NICHOLAS85/z-a-eval

# zsh notify
# install xdotool and wmctrl
zstyle ':notify:*' error-title "Command failed (in #{time_elapsed} seconds)"
zstyle ':notify:*' success-title "Command finished (in #{time_elapsed} seconds)"


# oh-my-zsh
zinit wait lucid for \
	OMZ::lib/git.zsh \
	OMZ::plugins/sudo/sudo.plugin.zsh

# fzf
$ZI pack for fzf
$ZL junegunn/fzf

$ZIGP mv"fd* -> fd" \
      pick"fd/fd" \
      nocompletions
$ZL sharkdp/fd

$ZIGP pick"bin/exa"
$ZL ogham/exa

$ZIGP mv"bat* -> bat" pick"bat/bat"
$ZL sharkdp/bat

$ZIDP pick"ranger.py" atload"alias ranger=ranger.py"
$ZL ranger/ranger

$ZIDP atclone"python3 setup.py install --user" \
    atpull"%atclone" \
$ZL nvbn/thefuck

$ZIGP mv"ripgrep* -> rg" \
        pick"rg/rg" \
        nocompletions
$ZL BurntSushi/ripgrep

$ZIGP pick"diff-so-fancy"
$ZL so-fancy/diff-so-fancy

$ZIDP atclone"python3 setup.py install --user" atpull"%atclone"
$ZL httpie/httpie

$ZIGP mv"htop* -> htop" \
    atclone"cd htop && ./autogen.sh && ./configure && make" \
    atpull'%atclone' \
    pick"htop/htop"
$ZL htop-dev/htop

$ZIDP atclone"python3 setup.py install --user" atpull"%atclone"
$ZL nicolargo/glances

$ZIGP bpick"*Linux_x86_64*" \
    pick"lazygit"
$ZL jesseduffield/lazygit

$ZIGP bpick"*Linux_x86_64*" \
    pick"lazydocker"
$ZL jesseduffield/lazydocker

$ZIGP ver"nightly" \
    mv"nvim-* -> nvim" \
    bpick"*linux*" \
    pick"nvim/bin/nvim"
$ZL neovim/neovim

if [ $(uname -m) = "x86_64" ]; then
    $ZIGC bpick"*x86_64*linux*" \
        pick"zoxide" \
        eval"./zoxide init zsh"
    $ZL ajeetdsouza/zoxide
elif [ $(uname -m) = "aarch64" ]; then
    $ZIGC bpick"*aarch64*linux" \
        pick"zoxide" \
        eval"./zoxide init zsh"
    $ZL ajeetdsouza/zoxide
fi

if [ $(uname -m) = "x86_64" ]; then
    $ZIGC bpick"*linux*x86_64*" \
        mv"tldr* -> tldr" \
        pick"tldr" \
        atload"nohup tldr --update -1 > /dev/null 2>&1"
    $ZL dbrgn/tealdeer
elif [ $(uname -m) = "aarch64" ]; then
    $ZIGP bpick"*linux*arm*"
        mv"tldr* -> tldr" \
        pick"tldr" \
        atload"nohup tldr --update -1 > /dev/null 2>&1"
    $ZL dbrgn/tealdeer
fi
