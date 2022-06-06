{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    cron
    vim
    foot
    firefox
    chromium
    syncthing
    imv
    emacs
    alacritty
    neovim
  ];
}
