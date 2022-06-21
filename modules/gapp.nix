{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
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
