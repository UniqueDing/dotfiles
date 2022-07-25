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
}
