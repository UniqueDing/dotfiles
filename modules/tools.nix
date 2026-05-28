{ config, pkgs, confPath, ... }:

{
  home.packages = with pkgs; [
    psmisc
    atool
    bc
    bitwarden-cli
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
    fastfetch
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

  home.file.".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${confPath}/gitconfig";
  xdg.configFile.lazygit.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/lazygit";
  xdg.configFile.bat.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/bat";
  xdg.configFile.tealdeer.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/tealdeer";
  xdg.configFile.eza.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/eza";
}
