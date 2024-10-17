{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    psmisc
    atool
    dos2unix
    tree
    fd
    lsd
    eza
    vivid
    bat
    ranger
    yazi
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
    joshuto
    bottom
    diskonaut
    gping
    termscp
    gitui
    todo-txt-cli
    proxychains-ng
    file
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
      ExecStart = "${pkgs.glances}/bin/glances -w --disable-webui";
      Restart = "always";
      RestartSec = "10";
    };
  };
}
