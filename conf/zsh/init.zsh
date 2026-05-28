CONFIG_PATH="$(dirname "$(realpath "${(%):-%N}")")"

source $CONFIG_PATH/plugins.zsh
source $CONFIG_PATH/env.zsh
source $CONFIG_PATH/settings.zsh
source $CONFIG_PATH/alias.sh
source $CONFIG_PATH/fun/fun.sh
