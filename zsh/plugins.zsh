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

GETOP()
{
case $(uname -s) in
Linux)
    case $(uname -m) in
    x86_64)
        echo $1
        ;;
    aarch64)
        echo $2
        ;;
    esac
    ;;
Darwin)
    case $(uname -m) in
    x86_64)
        echo $3
        ;;
    aarch64)
        echo $4
        ;;
    esac
    ;;
FreeBSD)
    case $(uname -m) in
    x86_64)
        echo $5
        ;;
    aarch64)
        echo $6
        ;;
    esac
    ;;
esac
}

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


    # atload" zstyle ':notify:*' error-title 'Command failed (in #{time_elapsed} seconds)' \
    #     zstyle ':notify:*' success-title 'Command finished (in #{time_elapsed} seconds)' \
    #     zstyle ':notify:*' error-log /dev/null" \
    # marzocchi/zsh-notify \
zinit wait lucid light-mode for \
	wfxr/forgit \
	hlissner/zsh-autopair \
    Aloxaf/fzf-tab \
    laggardkernel/zsh-thefuck

zinit atinit'Z_A_USECOMP=1' light-mode for NICHOLAS85/z-a-eval

# zsh notify
# install xdotool and wmctrl


# oh-my-zsh
zinit wait lucid for \
	OMZ::lib/git.zsh \
	OMZ::plugins/sudo/sudo.plugin.zsh

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
    atclone"cd htop && ./autogen.sh && ./configure && make -j12" \
    atpull'%atclone' \
    pick"htop/htop"
$ZL htop-dev/htop

$ZIDP atclone"python3 setup.py install --user" atpull"%atclone"
$ZL nicolargo/glances

BP=$(GETOP "*linux64*tar.gz" "*linux*" "*macos*" "*macos*" "" "")
$ZIGP bpick$BP \
    ver"nightly" \
    mv"nvim-* -> nvim" \
    pick"nvim/bin/nvim"
$ZL neovim/neovim

BP=$(GETOP "*Linux*x86_64*" "*Linux*arm64*" "*Darwin*x86_64*" "" "" "")
$ZIGP bpick$BP \
    pick"lazygit"
$ZL jesseduffield/lazygit

BP=$(GETOP "*Linux*x86_64*" "*Linux*arm64*" "*Darwin*x86_64*" "" "" "")
$ZIGP bpick$BP \
    pick"lazydocker"
$ZL jesseduffield/lazydocker

BP=$(GETOP "*x86_64*linux*" "*aarch64*linux*" "*x86_64*darwin*" "*aarch64*darwin*" "" "")
$ZIGP bpick$BP \
    pick"zoxide" \
    eval"./zoxide init zsh"
$ZL ajeetdsouza/zoxide

BP=$(GETOP "*linux*x86_64*" "*linux*arm64*" "*macos*x86_64*" "" "" "")
$ZIGP bpick$BP \
    mv"tealdeer* -> tldr" \
    pick"tldr" \
    atload"nohup tldr --update -1 > /dev/null 2>&1"
$ZL dbrgn/tealdeer

BP=$(GETOP "*linux*amd64*" "*linux*arm64*" "*darwin*amd64*" "*darwin*arm64*" "*freebsd*amd64*" "")
$ZIGP bpick$BP \
    pick"fzf"
$ZL junegunn/fzf

BP=$(GETOP "*linux*amd64*" "*linux*arm64*" "*darwin*amd64*" "" "*freebsd*amd64*" "*freebsd*arm*")
$ZIGP bpick$BP \
    mv"gdu* -> gdu" \
    pick"gdu"
$ZL dundee/gdu

BP=$(GETOP "*linux*x86_64*tar.gz" "*linux*arm64*tar.gz" "*Darwin*x84_64*tar.gz" "*Darwin*arm64*tar.gz" "*freebsd*x86_64*.tar.gz" "*freebsd*arm64*.tar.gz")
$ZIGP bpick$BP \
    mv"duf* -> duf" \
    pick"duf"
$ZL muesli/duf

BP=$(GETOP "*Linux*x86_64*" "*Linux*x86_64*" "*macOS*x84_64*" "*macOS*arm64*" "" "")
$ZIGP bpick$BP \
    pick"cowsay" \
    pick"cowthick"
$ZL Code-Hex/Neo-cowsay

$ZIDP atclone"make -j12" atpull"%atclone" \
    pick"lolcat"
$ZL jaseg/lolcat

$ZIDP atclone"make -j12" atpull"%atclone" \
    pick"neofetch"
$ZL dylanaraps/neofetch

$ZIDP pick"asciiquarium"
$ZL cmatsuoka/asciiquarium

$ZIDP atclone"autoreconf -i&&./configure&&make -j12" atpull"%atclone" \
    pick"cmatrix$"
$ZL abishekvashok/cmatrix

BP=$(GETOP "*linux64*" "" "*osx-amd64*" "" "" "")
$ZIGP bpick$BP \
    mv"jq* -> jq"\
    pick"jq"
$ZL stedolan/jq
