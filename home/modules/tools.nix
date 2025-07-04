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
    joshuto
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
    starship
    tmux
    tmux-mem-cpu-load
    try
    zsh
    nushell
    fish
    pay-respects
    curl
    wget
    netcat
  ];

  systemd.user.services.glances_server = {
    Unit = {
        Description = "Glance server";
    };
    Install = {
        WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.glances}/bin/glances -w --disable-webui --disable-plugins all --enable-plugins cpu,gpu,network,sensors,mem,network,fs";
      Restart = "always";
      RestartSec = "10";
    };
  };
}
