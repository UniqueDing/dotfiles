{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gimp
    krita
    nwg-launchers
    openshot-qt
    obs-studio
    vlc
    wshowkeys
    xournalpp
    zathura
    wpsoffice
    lisgd
  ];
}
