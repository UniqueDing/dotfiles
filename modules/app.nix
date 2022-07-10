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
    n2n
    msr-tools
  ];
}
