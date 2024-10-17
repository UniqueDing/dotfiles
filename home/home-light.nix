{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  imports = [
    ./modules/editor.nix
    ./modules/tools.nix
    ./modules/app.nix
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
    ln -sfn $HOME/dotfiles/home/yazi $HOME/.config/yazi
  '';
}
