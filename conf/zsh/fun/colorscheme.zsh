#!/bin/zsh

local color_schemes=(
  "catppuccin_mocha"
  "tokyonight_moon"
  "nord"
  "onedark"
  "dracula"
  "gruvbox_dark"
)

function cs() {
  echo "now colorscheme:"
  cat ~/.config/colorscheme
  echo "choose color scheme: "
  select scheme in "${color_schemes[@]}"; do
    echo $scheme
    if [[ -n "$scheme" ]]; then
      echo "selected：$scheme"
      modify_scheme $scheme
      return 0
    else
      echo "unknown"
    fi
  done
}

local function modify_scheme() {
  set -x
  scheme=$1
  # file
  echo $scheme > $HOME/.config/colorscheme

  # starship
  starship_config="$HOME/.config/starship/starship.toml"
  sed -i "s/palette = '.*/palette = '$scheme'/" "$starship_config"

  # nvim
  nvim_config="$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  nvim_scheme=$scheme
  case "$scheme" in
    "catppuccin_mocha")
      nvim_scheme="catppuccin"
      ;;
    "tokyonight_moon")
      nvim_scheme="tokyonight"
      ;;
    "nord")
      nvim_scheme="nordic"
      ;;
    "gruvbox_dark")
      nvim_scheme="gruvbox"
      ;;
  esac
  sed -i "s/      colorscheme = \".*\",/      colorscheme = \"$nvim_scheme\",/g" "$nvim_config"

  # yazi
  yazi_config="$HOME/.config/yazi/theme.toml"
  yazi_scheme=$scheme
  case "$scheme" in
    "catppuccin_mocha")
      yazi_scheme="catppuccin-mocha"
      ;;
    "tokyonight_moon")
      yazi_scheme="tokyo-night"
      ;;
    "gruvbox_dark")
      yazi_scheme="gruvbox-dark"
      ;;
  esac
  sed -i "s/dark = \".*\"/dark = \"$yazi_scheme\"/g" "$yazi_config"

  # bat
  bat_config="$HOME/.config/bat/config"
  bat_scheme=$scheme
  sed -i "s/--theme=\".*\"/--theme=\"$bat_scheme\"/" "$bat_config"

  # eza
  eza_scheme=$scheme
  case "$scheme" in
    "catppuccin_mocha")
      eza_scheme="catppuccin"
      ;;
    "tokyonight_moon")
      eza_scheme="tokyonight"
      ;;
    "gruvbox_dark")
      eza_scheme="gruvbox-dark"
      ;;
  esac
  ln -sf $HOME/.config/eza/themes/$eza_scheme.yml $HOME/.config/eza/theme.yml

  # tmux
  tmux_config="$HOME/.config/tmux/tmux.conf"
  tmux_scheme=$scheme
  sed -i "s/source-file \$HOME\/.config\/tmux\/theme\/.*.conf/source-file \$HOME\/.config\/tmux\/theme\/$tmux_scheme.conf/" "$tmux_config"
  tmux source-file $tmux_config

  # lazygit
  lazygit_config="$HOME/.config/lazygit/config.yml"
  lazygit_scheme=$scheme
  sed -i '/^  theme:/,$d' "$lazygit_config"
  sed 's/^/  /' "$HOME/.config/lazygit/themes/$lazygit_scheme.yml" | tee -a $lazygit_config

  # delta
  delta_config="$HOME/.gitconfig"
  delta_scheme=$scheme
  sed -i "s/  syntax-theme = .*/  syntax-theme = $delta_scheme/" "$delta_config"

  set +x
}

