{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    zsh
    psmisc
    atool
    curl
    dos2unix
    man
    nettools
    tree
    zip
    unzip
    wget
    vim
    fd
    file
    lsd
    bat
    ranger
    lf
    ripgrep
    diff-so-fancy
    httpie
    htop
    glances
    lazygit
    lazydocker
    lsb-release
    zoxide
    tealdeer
    fzf
    gdu
    duf
    neo-cowsay
    lolcat
    neofetch
    asciiquarium
    cmatrix
    jq
    pciutils
  ];
}