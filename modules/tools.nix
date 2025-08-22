{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    psmisc
    atool
    bc
    dos2unix
    tree
    vivid
    bat
    diff-so-fancy
    delta
    httpie
    htop
    glances
    git
    lazygit
    lazydocker
    lazysql
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
    bottom
    less
    # diskonaut
    gping
    termscp
    gitui
    todo-txt-cli
    proxychains-ng
    zip
    unzip
    nettools
    try
    pay-respects
    curl
    wget
    netcat
  ];

  home.file.".gitconfig" = { source = ../conf/gitconfig; };
  home.file.".config/lazygit" = { source = ../conf/lazygit; };
  home.file.".config/bat" = { source = ../conf/bat; };
  home.file.".config/tealdeer" = { source = ../conf/tealdeer; };
  home.file.".config/eza" = { source = ../conf/eza; };
}
