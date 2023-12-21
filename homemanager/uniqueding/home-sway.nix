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
    ln -sfn /opt/dotfiles/homemanager/uniqueding/ranger $HOME/.config/ranger
    ln -sfn /opt/dotfiles/homemanager/uniqueding/zsh $HOME/.config/zsh
    ln -sfn /opt/dotfiles/homemanager/uniqueding/zshrc $HOME/.zshrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/vimrc $HOME/.vimrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/nvim $HOME/.config/nvim
    ln -sfn /opt/dotfiles/homemanager/uniqueding/starship.toml $HOME/.config/starship.toml
    ln -sfn /opt/dotfiles/homemanager/uniqueding/tmux $HOME/.config/tmux
    ln -sfn /opt/dotfiles/homemanager/uniqueding/fcitx5/config $HOME/.config/fcitx5
    ln -sfn /opt/dotfiles/homemanager/uniqueding/fcitx5/share $HOME/.local/share/fcitx5
    ln -sfn /opt/dotfiles/homemanager/uniqueding/hypr $HOME/.config/hypr
    ln -sfn /opt/dotfiles/homemanager/uniqueding/foot $HOME/.config/foot
    ln -sfn /opt/dotfiles/homemanager/uniqueding/eww $HOME/.config/eww
    ln -sfn /opt/dotfiles/homemanager/uniqueding/squeekboard $HOME/.local/share/squeekboard
    ln -sfn /opt/dotfiles/homemanager/uniqueding/mako $HOME/.config/mako
    ln -sfn /opt/dotfiles/homemanager/uniqueding/sway $HOME/.config/sway
    ln -sfn /opt/dotfiles/homemanager/uniqueding/waybar $HOME/.config/waybar
    ln -sfn /opt/dotfiles/homemanager/uniqueding/wlogout $HOME/.config/wlogout
  '';
}
