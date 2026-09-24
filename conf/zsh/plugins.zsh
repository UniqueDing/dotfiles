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

# 某些全局配置已包装 compinit；在 Zim 再次初始化补全前移除其提示。
functions[compinit]="${functions[compinit]#*$'\n'}"

source ${ZIM_HOME}/init.zsh
