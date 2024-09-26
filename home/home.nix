{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  imports = [
    ./modules/tools.nix
    ./modules/font.nix
  ];

  home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  ''
    ln -sfn /opt/dotfiles/home/ranger $HOME/.config/ranger
    ln -sfn /opt/dotfiles/home/zsh $HOME/.config/zsh
    ln -sfn /opt/dotfiles/home/zshrc $HOME/.zshrc
    ln -sfn /opt/dotfiles/home/vimrc $HOME/.vimrc
    ln -sfn /opt/dotfiles/home/starship.toml $HOME/.config/starship.toml
    ln -sfn /opt/dotfiles/home/tmux $HOME/.config/tmux
    ln -sfn /opt/dotfiles/home/yazi $HOME/.config/yazi
  '';
}
