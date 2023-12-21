{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    chromium
    syncthing
    imv
    emacs
    alacritty
    v2raya
    wezterm
  ];
}
