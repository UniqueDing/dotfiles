{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  # Packages that should be installed to the user profile.
  home.stateVersion = "22.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.file.".config/sway".source = ./sway;
  home.file.".config/waybar".source = ./waybar;
  home.file.".config/zsh".source = ./zsh;
  home.file.".zshrc".source = ./zshrc;
  home.file.".config/fcitx5".source = ./fcitx5;
  home.file.".vimrc".source = ./vimrc;
  home.file.".config/nvim".source = ./nvim;
  home.file.".config/mako".source = ./mako;
  home.file.".config/kitty".source = ./kitty;
  home.file.".config/lf".source = ./lf;
  home.file.".config/foot".source = ./foot;
  home.file.".config/.wlogout".source = ./wlogout;
  home.file.".local/share/.squeekboard".source = ./squeekboard;

 # home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
 # ''
 #   ln -sf /opt/dotfiles/homemanager/uniqueding/ranger $HOME/.config/ranger
 # '';
}
