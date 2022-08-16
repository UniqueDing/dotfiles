{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    ( import (builtins.fetchTarball {
      url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
    }))
  ];

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
    tdesktop
    steam
    netease-cloud-music-gtk

    nur.repos.xddxdd.wechat-uos
    nur.repos.xddxdd.qq
    nur.repos.xddxdd.bilibili
    nur.repos.linyinfeng.wemeet
  ];
}
