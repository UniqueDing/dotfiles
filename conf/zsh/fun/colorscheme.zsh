#!/bin/zsh

typeset -ga color_schemes=(
  "catppuccin_mocha"
  "tokyonight_moon"
  "nord"
  "onedark"
  "dracula"
  "gruvbox_dark"
)

# Interactively select and apply one of the supported color profiles.
function cs() {
  print -- "now colorscheme:"
  if [[ -r "$HOME/.config/colorscheme" ]]; then
    cat -- "$HOME/.config/colorscheme"
  else
    print -- "(not set)"
  fi
  print -- "choose color scheme: "
  select scheme in "${color_schemes[@]}"; do
    if [[ -n "$scheme" ]]; then
      print -- "$scheme"
      print -- "selected: $scheme"
      modify_scheme "$scheme"
      return $?
    fi
    print -- "unknown"
  done
}

# Apply a selected profile to each configured application in order.
function modify_scheme() {
  local scheme="${1:-}"
  local config_dir="$HOME/.config"

  if [[ -z "$scheme" ]]; then
    print -u2 -- "colorscheme: no color scheme selected"
    return 1
  fi
  if (( ! ${color_schemes[(I)$scheme]} )); then
    print -u2 -- "colorscheme: unknown color scheme: $scheme"
    return 1
  fi

  _cs_apply_starship "$config_dir" "$scheme" || return 1
  _cs_apply_nvim "$config_dir" "$scheme" || return 1
  _cs_apply_yazi "$config_dir" "$scheme" || return 1
  _cs_apply_bat "$config_dir" "$scheme" || return 1
  _cs_apply_eza "$config_dir" "$scheme" || return 1
  _cs_apply_tmux "$config_dir" "$scheme" || return 1
  _cs_apply_lazygit "$config_dir" "$scheme" || return 1
  _cs_apply_delta "$HOME" "$scheme" || return 1
  _cs_apply_opencode "$config_dir" "$scheme" || return 1

  print -- "$scheme" > "$config_dir/colorscheme" || {
    print -u2 -- "colorscheme: could not update $config_dir/colorscheme"
    return 1
  }
  if ! tmux source-file "$config_dir/tmux/tmux.conf"; then
    print -u2 -- "Theme configuration updated, but tmux could not be reloaded."
  else
    print -- "Tmux configuration reloaded successfully."
  fi
  print -- "Theme set to $scheme. Restart OpenCode and other applications to apply it."
}

# Run an in-place extended sed expression on GNU or BSD systems.
function portable_sed_i() {
  local expression="$1"
  local target="$2"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' -E "$expression" "$target"
  else
    sed -i -E "$expression" "$target"
  fi
}

# Require a regular configuration file before changing it.
function _cs_require_config() {
  if [[ ! -f "$1" ]]; then
    print -u2 -- "colorscheme: required config is not a regular file: $1"
    return 1
  fi
}

# Apply Starship's canonical profile palette.
function _cs_apply_starship() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/starship/starship.toml"
  _cs_require_config "$target" || return 1
  portable_sed_i "s|^palette = '.*'$|palette = '$scheme'|" "$target"
}

# Apply Neovim's profile-specific colorscheme alias.
function _cs_apply_nvim() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/nvim/lua/plugins/colorscheme.lua"
  local nvim_scheme="$scheme"
  local -A aliases=(
    [catppuccin_mocha]=catppuccin-nvim
    [tokyonight_moon]=tokyonight
    [nord]=nordic
    [gruvbox_dark]=gruvbox
  )
  _cs_require_config "$target" || return 1
  nvim_scheme="${aliases[$scheme]:-$nvim_scheme}"
  portable_sed_i "s|^      colorscheme = \".*\",$|      colorscheme = \"$nvim_scheme\",|" "$target"
}

# Apply Yazi's profile-specific dark flavor.
function _cs_apply_yazi() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/yazi/theme.toml"
  local yazi_scheme="$scheme"
  local -A aliases=(
    [catppuccin_mocha]=catppuccin-mocha
    [tokyonight_moon]=tokyo-night
    [gruvbox_dark]=gruvbox-dark
  )
  _cs_require_config "$target" || return 1
  yazi_scheme="${aliases[$scheme]:-$yazi_scheme}"
  portable_sed_i "s|^dark = \".*\"$|dark = \"$yazi_scheme\"|" "$target"
}

# Apply bat's canonical profile theme.
function _cs_apply_bat() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/bat/config"
  _cs_require_config "$target" || return 1
  portable_sed_i "s|^--theme=\".*\"$|--theme=\"$scheme\"|" "$target"
}

# Apply eza's profile-specific theme link after checking its asset.
function _cs_apply_eza() {
  local config_dir="$1"
  local scheme="$2"
  local eza_scheme="$scheme"
  local asset
  local -A aliases=(
    [catppuccin_mocha]=catppuccin
    [tokyonight_moon]=tokyonight
    [onedark]=one_dark
    [gruvbox_dark]=gruvbox-dark
  )
  eza_scheme="${aliases[$scheme]:-$eza_scheme}"
  asset="$config_dir/eza/themes/$eza_scheme.yml"
  if [[ ! -f "$asset" ]]; then
    print -u2 -- "colorscheme: required theme asset is not a regular file: $asset"
    return 1
  fi
  ln -sf "$asset" "$config_dir/eza/theme.yml"
}

# Apply tmux's profile theme source after checking its asset.
function _cs_apply_tmux() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/tmux/tmux.conf"
  local asset="$config_dir/tmux/theme/$scheme.conf"
  _cs_require_config "$target" || return 1
  if [[ ! -f "$asset" ]]; then
    print -u2 -- "colorscheme: required theme asset is not a regular file: $asset"
    return 1
  fi
  portable_sed_i 's|^source-file \$HOME/.config/tmux/theme/.*\.conf$|source-file \$HOME/.config/tmux/theme/'"$scheme"'.conf|' "$target"
}

# Apply Lazygit's selected theme block after checking its asset.
function _cs_apply_lazygit() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/lazygit/config.yml"
  local asset="$config_dir/lazygit/themes/$scheme.yml"
  _cs_require_config "$target" || return 1
  if [[ ! -f "$asset" ]]; then
    print -u2 -- "colorscheme: required theme asset is not a regular file: $asset"
    return 1
  fi
  portable_sed_i '/^  theme:$/,$d' "$target" || return 1
  sed 's/^/  /' "$asset" >> "$target"
}

# Apply Delta's canonical profile syntax theme.
function _cs_apply_delta() {
  local home_dir="$1"
  local scheme="$2"
  local target="$home_dir/.gitconfig"
  _cs_require_config "$target" || return 1
  portable_sed_i "s|^  syntax-theme = .*$|  syntax-theme = $scheme|" "$target"
}

# Apply OpenCode's official TUI alias without touching opencode.jsonc.
function _cs_apply_opencode() {
  local config_dir="$1"
  local scheme="$2"
  local target="$config_dir/opencode/tui.json"
  local opencode_scheme="$scheme"
  local -A aliases=(
    [catppuccin_mocha]=catppuccin
    [tokyonight_moon]=tokyonight
    [nord]=nord
    [onedark]=one-dark
    [dracula]=dracula
    [gruvbox_dark]=gruvbox
  )
  _cs_require_config "$target" || return 1
  opencode_scheme="${aliases[$scheme]:-$opencode_scheme}"
  portable_sed_i "s|^  \"theme\": \".*\",$|  \"theme\": \"$opencode_scheme\",|" "$target"
}
