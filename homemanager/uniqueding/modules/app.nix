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
    v2raya
  ];

  home.file.".config/foot".source = ../foot;
}
