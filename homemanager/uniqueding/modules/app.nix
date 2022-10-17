{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    foot
    firefox
    chromium
    syncthing
    imv
    emacs
    alacritty
  ];

  home.file.".config/foot".source = ../foot;
}
