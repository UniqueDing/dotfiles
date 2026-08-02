{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    emacs
    alacritty
    wezterm
    chromium
    imv
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

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
  nixpkgs.config.allowUnfree = true;
}
