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
    ln -sfn $HOME/dotfiles/home/ranger $HOME/.config/ranger
    ln -sfn $HOME/dotfiles/home/bat $HOME/.config/bat
    ln -sfn $HOME/dotfiles/home/zsh $HOME/.config/zsh
    ln -sfn $HOME/dotfiles/home/zshrc $HOME/.zshrc
    ln -sfn $HOME/dotfiles/home/vimrc $HOME/.vimrc
    ln -sfn $HOME/dotfiles/home/nvim $HOME/.config/nvim
    ln -sfn $HOME/dotfiles/home/starship $HOME/.config/starship
    ln -sfn $HOME/dotfiles/home/tmux $HOME/.config/tmux
    ln -sfn $HOME/dotfiles/home/fcitx5/config $HOME/.config/fcitx5
    ln -sfn $HOME/dotfiles/home/fcitx5/share $HOME/.local/share/fcitx5
    ln -sfn $HOME/dotfiles/home/hypr $HOME/.config/hypr
    ln -sfn $HOME/dotfiles/home/foot $HOME/.config/foot
    ln -sfn $HOME/dotfiles/home/eww $HOME/.config/eww
    ln -sfn $HOME/dotfiles/home/squeekboard $HOME/.local/share/squeekboard
    ln -sfn $HOME/dotfiles/home/mako $HOME/.config/mako
    ln -sfn $HOME/dotfiles/home/sway $HOME/.config/sway
    ln -sfn $HOME/dotfiles/home/waybar $HOME/.config/waybar
    ln -sfn $HOME/dotfiles/home/wlogout $HOME/.config/wlogout
  '';
}
