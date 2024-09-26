{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  imports = [
    ./modules/editor.nix
    ./modules/tools.nix
    ./modules/app.nix
    ./modules/ime.nix
    ./modules/font.nix
    ./modules/gapp.nix
    ./modules/sway.nix
    ./modules/hyprland.nix
    ./modules/lang.nix
  ];

  home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  ''
    ln -sfn /opt/dotfiles/home/ranger $HOME/.config/ranger
    ln -sfn /opt/dotfiles/home/zsh $HOME/.config/zsh
    ln -sfn /opt/dotfiles/home/zshrc $HOME/.zshrc
    ln -sfn /opt/dotfiles/home/vimrc $HOME/.vimrc
    ln -sfn /opt/dotfiles/home/nvim $HOME/.config/nvim
    ln -sfn /opt/dotfiles/home/starship.toml $HOME/.config/starship.toml
    ln -sfn /opt/dotfiles/home/tmux $HOME/.config/tmux
    ln -sfn /opt/dotfiles/home/fcitx5/config $HOME/.config/fcitx5
    ln -sfn /opt/dotfiles/home/fcitx5/share $HOME/.local/share/fcitx5
    ln -sfn /opt/dotfiles/home/hypr $HOME/.config/hypr
    ln -sfn /opt/dotfiles/home/foot $HOME/.config/foot
    ln -sfn /opt/dotfiles/home/eww $HOME/.config/eww
    ln -sfn /opt/dotfiles/home/squeekboard $HOME/.local/share/squeekboard
    ln -sfn /opt/dotfiles/home/mako $HOME/.config/mako
    ln -sfn /opt/dotfiles/home/sway $HOME/.config/sway
    ln -sfn /opt/dotfiles/home/waybar $HOME/.config/waybar
    ln -sfn /opt/dotfiles/home/wlogout $HOME/.config/wlogout
  '';
}
