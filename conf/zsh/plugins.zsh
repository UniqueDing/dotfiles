# Give Zellij an OSC title; leave tmux and ordinary terminal title hooks alone.
zstyle ':zim:termtitle' hooks ${ZELLIJ:+precmd}
zstyle ':zim:termtitle' format '%1~'

ZIM_HOME=~/.local/zim
ZIM_CONFIG_FILE=~/.config/zsh/zimrc
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi

source ${ZIM_HOME}/init.zsh
