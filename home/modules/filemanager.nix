{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    ranger
    yazi
    lf
    fzf
    file
    jq
    poppler
    fd
    ripgrep
    zoxide
    lsd
    eza
  ];
}
