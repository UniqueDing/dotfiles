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
  ];

  home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  ''
    ln -sfn /opt/dotfiles/homemanager/uniqueding/ranger $HOME/.config/ranger
    ln -sfn /opt/dotfiles/homemanager/uniqueding/zsh $HOME/.config/zsh
    ln -sfn /opt/dotfiles/homemanager/uniqueding/zshrc $HOME/.zshrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/vimrc $HOME/.vimrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/nvim $HOME/.config/nvim
    ln -sfn /opt/dotfiles/homemanager/uniqueding/starship.toml $HOME/.config/starship.toml
    ln -sfn /opt/dotfiles/homemanager/uniqueding/tmux $HOME/.config/tmux
  '';
}
