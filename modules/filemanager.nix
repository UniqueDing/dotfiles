{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    yazi
    bat
    # ranger
    # lf
    # joshuto
    fzf
    file
    jq
    poppler
    fd
    ripgrep
    zoxide
    lsd
    eza
    ouch
  ];

  home.file.".config/yazi" = { source = ../conf/yazi; };
}
