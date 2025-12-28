{ config, pkgs, lib, confPath, ... }:

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

  home.activation.filemanagerLink = lib.mkAfter ''
    ln -sfn ${confPath}/yazi $HOME/.config/yazi
  '';
}
