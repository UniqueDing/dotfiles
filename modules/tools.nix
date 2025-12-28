{ config, pkgs, lib, confPath, ... }:

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

  home.activation.toolsLink = lib.mkAfter ''
    ln -sfn ${confPath}/gitconfig $HOME/.gitconfig
    ln -sfn ${confPath}/lazygit   $HOME/.config/lazygit
    ln -sfn ${confPath}/bat       $HOME/.config/bat
    ln -sfn ${confPath}/tealdeer  $HOME/.config/tealdeer
    ln -sfn ${confPath}/eza       $HOME/.config/eza
  '';
}
